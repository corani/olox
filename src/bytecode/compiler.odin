package main

import "core:strconv"

Compiler :: struct{
    scanner : ^Scanner,
    parser  : ^Parser,
    chunk   : ^Chunk,
}

compiler_init :: proc(compiler: ^Compiler) {
    // nothing, for now.
}

compile :: proc(chunk: ^Chunk, source: string) -> bool{
    scanner : Scanner
    parser  : Parser
    compiler: Compiler

    scanner_init(&scanner, source)
    parser_init(&parser, &scanner)

    compiler_init(&compiler)
    compiler.scanner = &scanner
    compiler.parser  = &parser
    compiler.chunk   = chunk

    compiler_compile_expression(&compiler);

    // "assert" we're at the end of the source
    parser_consume(compiler.parser, .Eof, "Expect end of expression.")

    compiler_end(&compiler)

    return !compiler.parser.had_error
}

compiler_make_constant :: proc(compiler: ^Compiler, value: Value) -> u8 {
    constant :=  chunk_add_constant(compiler.chunk, value)
    
    if constant > 255 {
        parser_error(compiler.parser, "Too many constants in one chunk.")

        return 0
    }

    return u8(constant)
}

compiler_emit_byte :: proc(compiler: ^Compiler, byte: u8) {
    chunk_append_u8(compiler.chunk, byte, compiler.parser.previous.line)
}

compiler_emit_bytes :: proc(compiler: ^Compiler, byte1, byte2: u8) {
    compiler_emit_byte(compiler, byte1)
    compiler_emit_byte(compiler, byte2)
}

compiler_emit_opcode :: proc(compiler: ^Compiler, opcode: OpCode) {
    compiler_emit_byte(compiler, u8(opcode))
}

compiler_emit_return :: proc(compiler: ^Compiler) {
    compiler_emit_opcode(compiler, .Return)
}

compiler_emit_constant :: proc(compiler: ^Compiler, value: Value) {
    constant :=  compiler_make_constant(compiler, value)
    compiler_emit_opcode(compiler, .Constant)
    compiler_emit_byte(compiler, constant)
}

compiler_end :: proc(compiler: ^Compiler) {
    compiler_emit_return(compiler)

    when DebugPrintCode {
        if !compiler.parser.had_error {
            chunk_disassemble(compiler.chunk, "code")
        }
    }
}

compiler_compile_grouping :: proc(compiler: ^Compiler) {
    compiler_compile_expression(compiler)
    parser_consume(compiler.parser, .RightParen, "Expect ')' after expression.")
}

compiler_compile_number :: proc(compiler: ^Compiler) {
    // NOTE(daniel): during scanning we've already determined this is a valid float.
    value, _ := strconv.parse_f64(compiler.parser.previous.text)

    compiler_emit_constant(compiler, Value(value))
}

compiler_compile_literal :: proc(compiler: ^Compiler) {
    #partial switch compiler.parser.previous.type {
    case .False:
        compiler_emit_opcode(compiler, .False)
    case .True:
        compiler_emit_opcode(compiler, .True)
    case .Nil:
        compiler_emit_opcode(compiler, .Nil)
    case:
        panic("unreachable")
    }
}

compiler_compile_unary :: proc(compiler: ^Compiler) {
    operator := compiler.parser.previous

    // Compile the operand.
    compiler_compile_precendence(compiler, .Unary)

    // Emit the operator instruction.
    #partial switch operator.type {
    case .Bang:
        compiler_emit_opcode(compiler, .Not)
    case .Minus:
        compiler_emit_opcode(compiler, .Negate)
    case:
        panic("unreachable")
    }
}

compiler_compile_binary :: proc(compiler: ^Compiler) {
    operator := compiler.parser.previous

    rule := parse_rules[operator.type]
    compiler_compile_precendence(compiler, Precedence(u8(rule.precedence) + 1))

    #partial switch operator.type {
    case .BangEqual:
        compiler_emit_opcode(compiler, .Equal)
        compiler_emit_opcode(compiler, .Not)
    case .EqualEqual:
        compiler_emit_opcode(compiler, .Equal)
    case .Greater:
        compiler_emit_opcode(compiler, .Greater)
    case .GreaterEqual:
        compiler_emit_opcode(compiler, .Less)
        compiler_emit_opcode(compiler, .Not)
    case .Less:
        compiler_emit_opcode(compiler, .Less)
    case .LessEqual:
        compiler_emit_opcode(compiler, .Greater)
        compiler_emit_opcode(compiler, .Not)
    case .Plus:
        compiler_emit_opcode(compiler, .Add)
    case .Minus:
        compiler_emit_opcode(compiler, .Subtract)
    case .Star:
        compiler_emit_opcode(compiler, .Multiply)
    case .Slash:
        compiler_emit_opcode(compiler, .Divide)
    case:
        panic("unreachable")
    }
}

compiler_compile_expression :: proc(compiler: ^Compiler) {
    compiler_compile_precendence(compiler, .Assignment)
}

compiler_compile_precendence :: proc(compiler: ^Compiler, precedence: Precedence) {
    parser_advance(compiler.parser)

    prefix_rule := parse_rules[compiler.parser.previous.type].prefix
    if prefix_rule == nil {
        parser_error(compiler.parser, "Expect expression.")
        return
    }

    prefix_rule(compiler)

    for precedence <= parse_rules[compiler.parser.current.type].precedence {
        parser_advance(compiler.parser)

        infix_rule := parse_rules[compiler.parser.previous.type].infix
        infix_rule(compiler)
    }
}
