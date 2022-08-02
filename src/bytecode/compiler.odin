package main

import "core:fmt"
import "core:strconv"

Compiler :: struct{
    enclosing   : ^Compiler,
    scanner     : ^Scanner,
    parser      : ^Parser,
    function    : ^ObjFunction,
    type        : FunctionType,
    locals      : [256]Local, // @u8max + 1
    local_count : int,
    scope_depth : int,
}

Local :: struct{
    name  : Token,
    depth : int,
}

// TODO(daniel): move this to `object.odin` and add the type to `ObjFunction`?
FunctionType :: enum {
    Function,
    Script,
}

compiler_init :: proc(compiler: ^Compiler, type: FunctionType, enclosing: ^Compiler = nil) {
    compiler.enclosing   = enclosing
    compiler.local_count = 0
    compiler.scope_depth = 0
    compiler.type        = type

    if enclosing == nil {
        compiler.scanner  = nil
        compiler.parser   = nil
        compiler.function = value_new_function("<script>")

        compiler_make_local(compiler, Token{text="<script>"})
    } else {
        compiler.scanner  = enclosing.scanner
        compiler.parser   = enclosing.parser
        compiler.function = value_new_function(compiler.parser.previous.text)

        compiler_make_local(compiler, compiler.parser.previous)
    }
}

compile :: proc(source: string) -> (^ObjFunction, bool) {
    scanner : Scanner
    parser  : Parser
    compiler: Compiler

    scanner_init(&scanner, source)
    parser_init(&parser, &scanner)

    compiler_init(&compiler, .Script)
    compiler.scanner = &scanner
    compiler.parser  = &parser

    for !parser_match(compiler.parser, .Eof) {
        compiler_compile_declaration(&compiler)
    }

    function := compiler_end(&compiler)

    if compiler.parser.had_error {
        return nil, false
    }

    return function, true
}

compiler_current_chunk :: proc(compiler: ^Compiler) -> ^Chunk {
    return compiler.function.chunk
}

compiler_make_constant :: proc(compiler: ^Compiler, value: Value) -> u8 {
    chunk := compiler_current_chunk(compiler)
    constant :=  chunk_add_constant(chunk, value)
    
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

compiler_parse_variable :: proc(compiler: ^Compiler, message: string) -> u8 {
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
    // NOTE(daniel): we're at the global scope, so there is no local variable to mark
    // as `initialized`.
    if compiler.scope_depth == 0 {
        return
    }

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

compiler_end :: proc(compiler: ^Compiler) -> ^ObjFunction {
    chunk := compiler_current_chunk(compiler)

    compiler_emit_return(compiler)

    when DebugPrintCode {
        if !compiler.parser.had_error {
            chunk_disassemble(chunk, compiler.function.name)
        }
    }

    return compiler.function
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
    chunk := compiler_current_chunk(compiler)

    chunk_append_u8(chunk, byte, compiler.parser.previous.line)
}

compiler_emit_bytes :: proc(compiler: ^Compiler, byte1, byte2: u8) {
    compiler_emit_byte(compiler, byte1)
    compiler_emit_byte(compiler, byte2)
}

compiler_emit_opcode :: proc(compiler: ^Compiler, opcode: OpCode) {
    compiler_emit_byte(compiler, u8(opcode))
}

compiler_emit_return :: proc(compiler: ^Compiler) {
    compiler_emit_opcode(compiler, .Nil)
    compiler_emit_opcode(compiler, .Return)
}

compiler_emit_constant :: proc(compiler: ^Compiler, value: Value) {
    constant :=  compiler_make_constant(compiler, value)
    compiler_emit_opcode(compiler, .Constant)
    compiler_emit_byte(compiler, constant)
}

compiler_emit_jump :: proc(compiler: ^Compiler, opcode: OpCode) -> int {
    chunk := compiler_current_chunk(compiler)

    compiler_emit_byte(compiler, u8(opcode))
    compiler_emit_byte(compiler, 0xff)
    compiler_emit_byte(compiler, 0xff)

    return chunk_size(chunk) - 2
}

compiler_patch_jump :: proc(compiler: ^Compiler, offset: int) {
    chunk := compiler_current_chunk(compiler)

    // `-2` to adjust for the bytecode for the jump offset itself
    jump := chunk_size(chunk) - offset - 2
    if jump > 65535 { // @u16max
        parser_error(compiler.parser, "Too much code to jump over.")
    }

    chunk.code[offset + 0] = u8((jump >> 8) & 0xff)
    chunk.code[offset + 1] = u8( jump       & 0xff)
}

compiler_emit_loop :: proc(compiler: ^Compiler, loop_start: int) {
    chunk := compiler_current_chunk(compiler)

    compiler_emit_opcode(compiler, .Loop)

    // `+2` to adjust for the bytecode for the jump offset itself
    offset := chunk_size(chunk) - loop_start + 2
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

compiler_compile_argument_list :: proc(compiler: ^Compiler) -> u8 {
    arg_count: u8

    if !parser_check(compiler.parser, .RightParen) {
        for {
            compiler_compile_expression(compiler)

            if arg_count == 255 {
                parser_error(compiler.parser, "Can't have more than 255 arguments.")
            }
            arg_count += 1

            if !parser_match(compiler.parser, .Comma) {
                break
            }
        }
    }

    parser_consume(compiler.parser, .RightParen, "Expect ')' after arguments.")

    return arg_count
}

compiler_compile_call :: proc(compiler: ^Compiler, can_assign: bool) {
    arg_count := compiler_compile_argument_list(compiler)

    compiler_emit_opcode(compiler, .Call)
    compiler_emit_byte(compiler, arg_count)
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

compiler_compile_return_statement :: proc(compiler: ^Compiler) {
    if compiler.type == .Script {
        parser_error(compiler.parser, "Can't return from top-level code.")
    }

    if parser_match(compiler.parser, .Semicolon) {
        compiler_emit_return(compiler)
    } else {
        compiler_compile_expression(compiler)
        parser_consume(compiler.parser, .Semicolon, "Expect ';' after return value.")
        compiler_emit_opcode(compiler, .Return)
    }
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
    chunk := compiler_current_chunk(compiler)

    loop_start := chunk_size(chunk)

    parser_consume(compiler.parser, .LeftParen, "Expect '(' after 'while'.")
    compiler_compile_expression(compiler)
    parser_consume(compiler.parser, .RightParen, "Expect ')' after 'while' condition.")

    exit_jump := compiler_emit_jump(compiler, .JumpIfFalse)
    compiler_emit_opcode(compiler, .Pop)
    
    compiler_compile_statement(compiler)
    compiler_emit_loop(compiler, loop_start)

    compiler_patch_jump(compiler, exit_jump)
    compiler_emit_opcode(compiler, .Pop)
}

compiler_compile_for_statement :: proc(compiler: ^Compiler) {
    chunk := compiler_current_chunk(compiler)

    compiler_scope_begin(compiler)
    parser_consume(compiler.parser, .LeftParen, "Expect '(' after 'for'.")

    switch {
    case parser_match(compiler.parser, .Semicolon):
        // no initializer.
    case parser_match(compiler.parser, .Var):
        compiler_compile_var_declaration(compiler)
    case:
        compiler_compile_expression_statement(compiler)
    }

    loop_start := chunk_size(chunk)
    exit_jump  := -1

    if !parser_match(compiler.parser, .Semicolon) {
        compiler_compile_expression(compiler)
        parser_consume(compiler.parser, .Semicolon, "Expect ';' after loop condition.")

        // Jump out of the loop if the condition is false
        exit_jump = compiler_emit_jump(compiler, .JumpIfFalse)
        compiler_emit_opcode(compiler, .Pop) // condition
    }

    if !parser_match(compiler.parser, .RightParen) {
        body_jump  := compiler_emit_jump(compiler, .Jump)
        incr_start := chunk_size(chunk)

        compiler_compile_expression(compiler)
        compiler_emit_opcode(compiler, .Pop)
        parser_consume(compiler.parser, .RightParen, "Expect ')' after for clauses.")

        compiler_emit_loop(compiler, loop_start)
        loop_start = incr_start;
        compiler_patch_jump(compiler, body_jump)
    }

    compiler_compile_statement(compiler)
    compiler_emit_loop(compiler, loop_start)

    if exit_jump != -1 {
        compiler_patch_jump(compiler, exit_jump)
        compiler_emit_opcode(compiler, .Pop) // condition
    }

    compiler_scope_end(compiler)
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
    case parser_match(compiler.parser, .Return):
        compiler_compile_return_statement(compiler)
    case parser_match(compiler.parser, .If):
        compiler_compile_if_statement(compiler)
    case parser_match(compiler.parser, .While):
        compiler_compile_while_statement(compiler)
    case parser_match(compiler.parser, .For):
        compiler_compile_for_statement(compiler)
    case parser_match(compiler.parser, .LeftBrace):
        compiler_scope_begin(compiler)
        compiler_compile_block_statement(compiler)
        compiler_scope_end(compiler)
    case:
        compiler_compile_expression_statement(compiler)
    }
}

// ----- functions ------------------------------------------------------------

compiler_compile_function :: proc(base_compiler: ^Compiler, type: FunctionType) {
    compiler: Compiler
    compiler_init(&compiler, type, base_compiler)
    compiler_scope_begin(&compiler)

    parser_consume(compiler.parser, .LeftParen, "Expect '(' after function name.")
    if !parser_check(compiler.parser, .RightParen) {
        for {
            compiler.function.arity += 1
            if compiler.function.arity > 255 {
                parser_error_at_current(compiler.parser, "Can't have more than 255 parameters.")
            }

            constant := compiler_parse_variable(&compiler, "Expect parameter name.")
            compiler_define_variable(&compiler, constant)

            if !parser_match(compiler.parser, .Comma) {
                break
            }
        }
    }

    parser_consume(compiler.parser, .RightParen, "Expect ')' after parameters.")
    parser_consume(compiler.parser, .LeftBrace, "Expect '{' before function body.")

    compiler_compile_block_statement(&compiler)

    function := compiler_end(&compiler)

    compiler_scope_end(&compiler)

    compiler_emit_constant(base_compiler, cast(^Obj) function)
}

// ----- declarations ---------------------------------------------------------

compiler_compile_fun_declaration :: proc(compiler: ^Compiler) {
    global := compiler_parse_variable(compiler, "Expect function name.")

    compiler_mark_variable_initialized(compiler)
    compiler_compile_function(compiler, .Function)

    compiler_define_variable(compiler, global)
}

compiler_compile_var_declaration :: proc(compiler: ^Compiler) {
    global := compiler_parse_variable(compiler, "Expect variable name.")

    if parser_match(compiler.parser, .Equal) {
        compiler_compile_expression(compiler)
    } else {
        compiler_emit_opcode(compiler, .Nil)
    }

    parser_consume(compiler.parser, .Semicolon, "Expect ';' after variable declaration.")

    compiler_define_variable(compiler, global)
}

compiler_compile_declaration :: proc(compiler: ^Compiler) {
    switch {
    case parser_match(compiler.parser, .Fun):
        compiler_compile_fun_declaration(compiler)
    case parser_match(compiler.parser, .Var):
        compiler_compile_var_declaration(compiler)
    case:
       compiler_compile_statement(compiler);
    }

    if compiler.parser.panic_mode {
        compiler_synchronize(compiler)
    }
}
