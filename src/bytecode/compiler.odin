package main

import "core:strconv"

Compiler :: struct{
    scanner     : ^Scanner,
    parser      : ^Parser,
    chunk       : ^Chunk,
    locals      : [256]Local, // @u8max + 1
    local_count : int,
    scope_depth : int,
}

Local :: struct{
    name  : Token,
    depth : int,
}

compiler_init :: proc(compiler: ^Compiler) {
    compiler.scanner     = nil
    compiler.parser      = nil
    compiler.chunk       = nil
    compiler.local_count = 0
    compiler.scope_depth = 0
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

    for !parser_match(compiler.parser, .Eof) {
        compiler_compile_declaration(&compiler)
    }

    compiler_end(&compiler)

    return !compiler.parser.had_error
}

compiler_make_constant :: proc(compiler: ^Compiler, value: Value) -> u8 {
    constant :=  chunk_add_constant(compiler.chunk, value)
    
    if constant > 255 {     // @u8max
        parser_error(compiler.parser, "Too many constants in one chunk.")

        return 0
    }

    return u8(constant)
}

compiler_make_local :: proc(compiler: ^Compiler, name: Token) {
    if compiler.local_count == 255 { // @u8size
        parser_error(compiler.parser, "Too many local variables in function.")

        return
    }

    local := Local{
        name  = name,
        depth = -1,     // "uninitialized"
    }

    compiler.locals[compiler.local_count] = local
    compiler.local_count += 1
}

compiler_compile_identifier_constant :: proc(compiler: ^Compiler, name: Token) -> u8 {
    // TODO(daniel): if a constant already exists for the name, reuse it!
    return compiler_make_constant(compiler, value_new_string(name.text)) 
}

compiler_compile_resolve_local :: proc(compiler: ^Compiler, name: Token) -> int {
    for i := compiler.local_count - 1; i >= 0; i -= 1 {
        local := compiler.locals[i]

        if name.text == local.name.text {
            if local.depth == -1 {
                parser_error(compiler.parser, "Can't read local variable in its own initializer.")
            }

            return i
        }
    }

    return -1
}

compiler_declare_variable :: proc(compiler: ^Compiler) {
    if compiler.scope_depth == 0 {
        // NOTE(daniel): global variables are "late-bound", so the compiler doesn't
        // need to keep track of them.
        return
    }

    name := compiler.parser.previous

    for i := compiler.local_count - 1; i >= 0; i -= 1 {
        local := compiler.locals[i];
        if local.depth != -1 && local.depth < compiler.scope_depth {
            break
        }

        if name.text == local.name.text {
            parser_error(compiler.parser, "Already a variable with this name in this scope.")
        }
    }

    compiler_make_local(compiler, name)
}

compiler_parser_variable :: proc(compiler: ^Compiler, message: string) -> u8 {
    parser_consume(compiler.parser, .Identifier, message);

    compiler_declare_variable(compiler)
    if compiler.scope_depth > 0 {
        // NOTE(daniel): local variables aren't looked up by name, so there's no need
        // to create a constant for them.
        return 0
    }

    return compiler_compile_identifier_constant(compiler, compiler.parser.previous)
}

compiler_mark_variable_initialized :: proc(compiler: ^Compiler) {
    compiler.locals[compiler.local_count - 1].depth = compiler.scope_depth
}

compiler_define_variable :: proc(compiler: ^Compiler, global: u8) {
    if compiler.scope_depth > 0 {
        compiler_mark_variable_initialized(compiler)
        // NOTE(daniel): local variables are stored on the stack... where the value
        // already sits. So we don't need to do anything here.
        return
    }

    compiler_emit_opcode(compiler, .DefineGlobal)
    compiler_emit_byte(compiler, global)
}

compiler_end :: proc(compiler: ^Compiler) {
    compiler_emit_return(compiler)

    when DebugPrintCode {
        if !compiler.parser.had_error {
            chunk_disassemble(compiler.chunk, "code")
        }
    }
}

compiler_synchronize :: proc(compiler: ^Compiler) {
    compiler.parser.panic_mode = false

    for !parser_is_at_end(compiler.parser) {
        if compiler.parser.previous.type == .Semicolon {
            return
        }

        #partial switch compiler.parser.current.type {
        case .Class, .Fun, .Var, .For, .If, .While, .Print, .Return:
            return
        case:
            parser_advance(compiler.parser)
        }
    }
}

// ----- scopes ---------------------------------------------------------------
 
compiler_scope_begin :: proc(compiler: ^Compiler) {
    // TODO(daniel): bounds check
    compiler.scope_depth += 1
}

compiler_scope_end :: proc(compiler: ^Compiler) {
    // TODO(daniel): bounds check
    compiler.scope_depth -= 1

    // TODO(daniel): "POPN" to pop all local variables at once?
    for compiler.local_count > 0 && 
        compiler.locals[compiler.local_count - 1].depth > compiler.scope_depth 
    {
        compiler_emit_opcode(compiler, .Pop)
        compiler.local_count -= 1
    }
}

// ----- emit bytecode --------------------------------------------------------
 
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

compiler_emit_jump :: proc(compiler: ^Compiler, opcode: OpCode) -> int {
    compiler_emit_byte(compiler, u8(opcode))
    compiler_emit_byte(compiler, 0xff)
    compiler_emit_byte(compiler, 0xff)

    return len(compiler.chunk.code) - 2
}

compiler_patch_jump :: proc(compiler: ^Compiler, offset: int) {
    // `-2` to adjust for the bytecode for the jump offset itself
    jump := len(compiler.chunk.code) - offset - 2
    if jump > 65535 { // @u16max
        parser_error(compiler.parser, "Too much code to jump over.")
    }

    compiler.chunk.code[offset + 0] = u8((jump >> 8) & 0xff)
    compiler.chunk.code[offset + 1] = u8( jump       & 0xff)
}

compiler_emit_loop :: proc(compiler: ^Compiler, loop_start: int) {
    compiler_emit_opcode(compiler, .Loop)

    // `+2` to adjust for the bytecode for the jump offset itself
    offset := len(compiler.chunk.code) - loop_start + 2
    if offset > 65535 { // @u16max
        parser_error(compiler.parser, "Loop body too large.")
    }

    compiler_emit_byte(compiler, u8((offset >> 8) & 0xff))
    compiler_emit_byte(compiler, u8( offset       & 0xff))
}

// ----- expressions ----------------------------------------------------------
 
compiler_compile_grouping :: proc(compiler: ^Compiler, can_assign: bool) {
    compiler_compile_expression(compiler)
    parser_consume(compiler.parser, .RightParen, "Expect ')' after expression.")
}

compiler_compile_number :: proc(compiler: ^Compiler, can_assign: bool) {
    // NOTE(daniel): during scanning we've already determined this is a valid float.
    value, _ := strconv.parse_f64(compiler.parser.previous.text)

    compiler_emit_constant(compiler, value_new_number(value))
}

compiler_compile_string :: proc(compiler: ^Compiler, can_assign: bool) {
    compiler_emit_constant(compiler, 
        value_new_string(compiler.parser.previous.text))
}

compiler_compile_named_variable :: proc(compiler: ^Compiler, name: Token, can_assign: bool) {
    arg    := compiler_compile_resolve_local(compiler, name)
    get_op := OpCode.GetLocal
    set_op := OpCode.SetLocal

    if arg < 0 {
        arg    = int(compiler_compile_identifier_constant(compiler, name))
        get_op = .GetGlobal
        set_op = .SetGlobal
    }

    if can_assign && parser_match(compiler.parser, .Equal) {
        compiler_compile_expression(compiler)
        compiler_emit_opcode(compiler, set_op)
    } else {
        compiler_emit_opcode(compiler, get_op)
    }

    compiler_emit_byte(compiler, u8(arg))
}

compiler_compile_variable :: proc(compiler: ^Compiler, can_assign: bool) {
    compiler_compile_named_variable(compiler, compiler.parser.previous, can_assign)
}

compiler_compile_literal :: proc(compiler: ^Compiler, can_assign: bool) {
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

compiler_compile_unary :: proc(compiler: ^Compiler, can_assign: bool) {
    operator := compiler.parser.previous

    // Compile the operand.
    compiler_compile_precedence(compiler, .Unary)

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

compiler_compile_binary :: proc(compiler: ^Compiler, can_assign: bool) {
    operator := compiler.parser.previous

    rule := parse_rules[operator.type]
    compiler_compile_precedence(compiler, Precedence(u8(rule.precedence) + 1))

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

compiler_compile_and :: proc(compiler: ^Compiler, can_assign: bool) {
    end_jump := compiler_emit_jump(compiler, .JumpIfFalse)

    compiler_emit_opcode(compiler, .Pop)

    compiler_compile_precedence(compiler, .And)
    compiler_patch_jump(compiler, end_jump)
}

compiler_compile_or :: proc(compiler: ^Compiler, can_assign: bool) {
    // TODO(daniel): this is kind of dumb, but doesn't require additional instruction types.
    else_jump := compiler_emit_jump(compiler, .JumpIfFalse)
    end_jump  := compiler_emit_jump(compiler, .Jump)

    compiler_patch_jump(compiler, else_jump)
    compiler_emit_opcode(compiler, .Pop)

    compiler_compile_precedence(compiler, .Or)
    compiler_patch_jump(compiler, end_jump)
}

compiler_compile_precedence :: proc(compiler: ^Compiler, precedence: Precedence) {
    parser_advance(compiler.parser)

    prefix_rule := parse_rules[compiler.parser.previous.type].prefix
    if prefix_rule == nil {
        parser_error(compiler.parser, "Expect expression.")
        return
    }

    can_assign := precedence <= .Assignment

    prefix_rule(compiler, can_assign)

    for precedence <= parse_rules[compiler.parser.current.type].precedence {
        parser_advance(compiler.parser)

        infix_rule := parse_rules[compiler.parser.previous.type].infix
        infix_rule(compiler, can_assign)
    }

    if can_assign && parser_match(compiler.parser, .Equal) {
        parser_error(compiler.parser, "Invalid assignment target.")
    }
}

compiler_compile_expression :: proc(compiler: ^Compiler) {
    compiler_compile_precedence(compiler, .Assignment)
}

// ----- statements------------------------------------------------------------
 
compiler_compile_expression_statement :: proc(compiler: ^Compiler) {
    compiler_compile_expression(compiler)
    parser_consume(compiler.parser, .Semicolon, "Expect ';' after value.")
    compiler_emit_opcode(compiler, .Pop)
}

compiler_compile_print_statement :: proc(compiler: ^Compiler) {
    compiler_compile_expression(compiler)
    parser_consume(compiler.parser, .Semicolon, "Expect ';' after value.")
    compiler_emit_opcode(compiler, .Print)
}

compiler_compile_if_statement :: proc(compiler: ^Compiler) {
    parser_consume(compiler.parser, .LeftParen, "Expect '(' after 'if'.")
    compiler_compile_expression(compiler)
    parser_consume(compiler.parser, .RightParen, "Expect ')' after 'if' condition.")

    then_jump := compiler_emit_jump(compiler, .JumpIfFalse)
    compiler_emit_opcode(compiler, .Pop)

    compiler_compile_statement(compiler)
    else_jump := compiler_emit_jump(compiler, .Jump)

    compiler_patch_jump(compiler, then_jump)
    compiler_emit_opcode(compiler, .Pop)

    if parser_match(compiler.parser, .Else) {
        compiler_compile_statement(compiler)
    }

    compiler_patch_jump(compiler, else_jump)
}

compiler_compile_while_statement :: proc(compiler: ^Compiler) {
    loop_start := len(compiler.chunk.code)

    parser_consume(compiler.parser, .LeftParen, "Expect '(' after 'if'.")
    compiler_compile_expression(compiler)
    parser_consume(compiler.parser, .RightParen, "Expect ')' after 'if' condition.")

    exit_jump := compiler_emit_jump(compiler, .JumpIfFalse)
    compiler_emit_opcode(compiler, .Pop)
    
    compiler_compile_statement(compiler)
    compiler_emit_loop(compiler, loop_start)

    compiler_patch_jump(compiler, exit_jump)
    compiler_emit_opcode(compiler, .Pop)
}

compiler_compile_block_statement :: proc(compiler: ^Compiler) {
    for !parser_check(compiler.parser, .RightBrace) && !parser_check(compiler.parser, .Eof) {
        compiler_compile_declaration(compiler)
    }

    parser_consume(compiler.parser, .RightBrace, "Expect '}' after block.")
}

compiler_compile_statement :: proc(compiler: ^Compiler) {
    switch {
    case parser_match(compiler.parser, .Print):
        compiler_compile_print_statement(compiler)
    case parser_match(compiler.parser, .If):
        compiler_compile_if_statement(compiler)
    case parser_match(compiler.parser, .While):
        compiler_compile_while_statement(compiler)
    case parser_match(compiler.parser, .LeftBrace):
        compiler_scope_begin(compiler)
        compiler_compile_block_statement(compiler)
        compiler_scope_end(compiler)
    case:
        compiler_compile_expression_statement(compiler)
    }
}

// ----- declarations ---------------------------------------------------------

compiler_compile_var_declaration :: proc(compiler: ^Compiler) {
    global := compiler_parser_variable(compiler, "Expect variable name.")

    if parser_match(compiler.parser, .Equal) {
        compiler_compile_expression(compiler)
    } else {
        compiler_emit_opcode(compiler, .Nil)
    }

    parser_consume(compiler.parser, .Semicolon, "Expect ';' after variable declaration.")

    compiler_define_variable(compiler, global)
}

compiler_compile_declaration :: proc(compiler: ^Compiler) {
    if parser_match(compiler.parser, .Var) {
        compiler_compile_var_declaration(compiler)
    } else {
       compiler_compile_statement(compiler);
    }

    if compiler.parser.panic_mode {
        compiler_synchronize(compiler)
    }
}
