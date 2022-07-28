package main

import "core:fmt"

Parser :: struct {
    scanner    : ^Scanner,
    current    : Token,
    previous   : Token,
    had_error  : bool,
    panic_mode : bool,
}

Precedence :: enum u8 {
    None,
    Assignment,     // =
    Or,             // or
    And,            // and
    Equality,       // == !=
    Comparison,     // < > <= >=
    Term,           // + -
    Factor,         // * / 
    Unary,          // ! -
    Call,           // . ()
    Primary,
}

ParseRule :: struct {
    prefix     : ParseFn,
    infix      : ParseFn,
    precedence : Precedence,
}

ParseFn :: proc(^Compiler)

parse_rules := map[TokenType]ParseRule{
    .LeftParen      = { compiler_compile_grouping,  nil,                        .None },
    .RightParen     = { nil,                        nil,                        .None },
    .LeftBrace      = { nil,                        nil,                        .None },
    .RightBrace     = { nil,                        nil,                        .None },
    .Comma          = { nil,                        nil,                        .None },
    .Dot            = { nil,                        nil,                        .None },
    .Minus          = { compiler_compile_unary,     compiler_compile_binary,    .Term },
    .Plus           = { nil,                        compiler_compile_binary,    .Term },
    .Semicolon      = { nil,                        nil,                        .None },
    .Slash          = { nil,                        compiler_compile_binary,    .Factor },
    .Star           = { nil,                        compiler_compile_binary,    .Factor },
    .Bang           = { compiler_compile_unary,     nil,                        .None },
    .BangEqual      = { nil,                        compiler_compile_binary,    .Equality },
    .Equal          = { nil,                        nil,                        .None },
    .EqualEqual     = { nil,                        compiler_compile_binary,    .Equality },
    .Greater        = { nil,                        compiler_compile_binary,    .Comparison },
    .GreaterEqual   = { nil,                        compiler_compile_binary,    .Comparison },
    .Less           = { nil,                        compiler_compile_binary,    .Comparison },
    .LessEqual      = { nil,                        compiler_compile_binary,    .Comparison },
    .Identifier     = { nil,                        nil,                        .None },
    .String         = { compiler_compile_string,    nil,                        .None },
    .Number         = { compiler_compile_number,    nil,                        .None },
    .And            = { nil,                        nil,                        .None },
    .Class          = { nil,                        nil,                        .None },
    .Else           = { nil,                        nil,                        .None },
    .False          = { compiler_compile_literal,   nil,                        .None },
    .For            = { nil,                        nil,                        .None },
    .Fun            = { nil,                        nil,                        .None },
    .If             = { nil,                        nil,                        .None },
    .Nil            = { compiler_compile_literal,   nil,                        .None },
    .Or             = { nil,                        nil,                        .None },
    .Print          = { nil,                        nil,                        .None },
    .Return         = { nil,                        nil,                        .None },
    .Super          = { nil,                        nil,                        .None },
    .This           = { nil,                        nil,                        .None },
    .True           = { compiler_compile_literal,   nil,                        .None },
    .Var            = { nil,                        nil,                        .None },
    .While          = { nil,                        nil,                        .None },
    .Error          = { nil,                        nil,                        .None },
    .Eof            = { nil,                        nil,                        .None },
}

parser_init :: proc(parser: ^Parser, scanner: ^Scanner) {
    parser.scanner    = scanner
    parser.had_error  = false
    parser.panic_mode = false

    parser_advance(parser)
}

parser_free :: proc(parser: ^Parser) {
    // nothing, for now.
}

parser_error_at :: proc(parser: ^Parser, token: Token, message: string) {
    if parser.panic_mode {
        return
    }

    parser.panic_mode = true
    parser.had_error  = true

    fmt.eprintf("ERROR: %d:", token.line)

    #partial switch token.type {
    case .Eof:
        fmt.eprintf(" at end")
    case .Error:
        // nothing
    case:
        fmt.eprintf(" at '%s'", token.text)
    }

    fmt.eprintf(": %s\n", message)
}

parser_error :: proc(parser: ^Parser, message: string) {
    parser_error_at(parser, parser.previous, message)
}

parser_error_at_current :: proc(parser: ^Parser, message: string) {
    parser_error_at(parser, parser.current, message)
}

parser_advance :: proc(parser: ^Parser) {
    parser.previous = parser.current

    for {
        parser.current = scanner_scan_token(parser.scanner)

        if parser.current.type != .Error {
            break
        }

        parser_error_at_current(parser, parser.current.text)
    }
}

parser_consume :: proc(parser: ^Parser, type: TokenType, message: string) {
    if parser.current.type == type {
        parser_advance(parser)

        return
    }

    parser_error_at_current(parser, message)
}
