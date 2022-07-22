package main 

import "core:strconv"

keywords := map[string]TokenType{
    "and"    = TokenType.And,
    "class"  = TokenType.Class,
    "else"   = TokenType.Else,
    "false"  = TokenType.False,
    "for"    = TokenType.For,
    "fun"    = TokenType.Fun,
    "if"     = TokenType.If,
    "nil"    = TokenType.Nil,
    "or"     = TokenType.Or,
    "print"  = TokenType.Print,
    "return" = TokenType.Return,
    "super"  = TokenType.Super,
    "this"   = TokenType.This,
    "true"   = TokenType.True,
    "var"    = TokenType.Var,
    "while"  = TokenType.While,
}

Scanner :: struct{
    source: string,
    tokens: [dynamic]Token,
    start, current: int,
    line: int,
}

new_scanner :: proc(source: string) -> ^Scanner {
    result := new(Scanner)
    result.source = source
    result.line = 1

    return result
}

scanner_tokens :: proc(scanner: ^Scanner) -> []Token {
    for !scanner_is_at_end(scanner) {
        scanner.start = scanner.current;
        scanner_token(scanner)
    }

    append(&scanner.tokens, Token{
        type=TokenType.EOF,
        line=scanner.line,
    })

    return scanner.tokens[:]
}

scanner_token :: proc(scanner: ^Scanner) {
    switch c := scanner_advance(scanner); c {
    case '(': scanner_add_token(scanner, TokenType.LeftParen)
    case ')': scanner_add_token(scanner, TokenType.RightParen)
    case '{': scanner_add_token(scanner, TokenType.LeftBrace)
    case '}': scanner_add_token(scanner, TokenType.RightBrace)
    case '.': scanner_add_token(scanner, TokenType.Dot)
    case ',': scanner_add_token(scanner, TokenType.Comma)
    case '-': scanner_add_token(scanner, TokenType.Minus)
    case '+': scanner_add_token(scanner, TokenType.Plus)
    case ';': scanner_add_token(scanner, TokenType.Semicolon)
    case '*': scanner_add_token(scanner, TokenType.Star)
    case '!': 
        if scanner_match(scanner, '=') {
            scanner_add_token(scanner, TokenType.BangEqual)
        } else {
            scanner_add_token(scanner, TokenType.Bang)
        }
    case '=': 
        if scanner_match(scanner, '=') {
            scanner_add_token(scanner, TokenType.EqualEqual)
        } else {
            scanner_add_token(scanner, TokenType.Equal)
        }
    case '<': 
        if scanner_match(scanner, '=') {
            scanner_add_token(scanner, TokenType.LessEqual)
        } else {
            scanner_add_token(scanner, TokenType.Less)
        }
    case '>': 
        if scanner_match(scanner, '=') {
            scanner_add_token(scanner, TokenType.GreaterEqual)
        } else {
            scanner_add_token(scanner, TokenType.Greater)
        }
    case '/':
        if scanner_match(scanner, '/') {
            for scanner_peek(scanner) != '\n' && !scanner_is_at_end(scanner) {
                scanner_advance(scanner)
            }
        } else {
            scanner_add_token(scanner, TokenType.Slash)
        }
    case ' ', '\r', '\t':
        // ignore whitespace
    case '\n':
        scanner.line += 1
    case '"':
        scanner_string(scanner)
    case    : 
        if is_digit(c) {
            scanner_number(scanner)
        } else if is_alpha(c) {
            scanner_identifier(scanner)
        } else {
           report(line=scanner.line, text="Unexpected character")
        }
    }
}

scanner_string :: proc(scanner: ^Scanner) {
    for scanner_peek(scanner) != '"' && !scanner_is_at_end(scanner) {
        if scanner_peek(scanner) == '\n' {
            scanner.line += 1
        }

        scanner_advance(scanner)
    }

    if scanner_is_at_end(scanner) {
        report(line=scanner.line, text="Unterminated string.")

        return
    }

    scanner_advance(scanner) // closing "

    scanner_add_token(scanner, TokenType.String, scanner.source[scanner.start+1:scanner.current-1])
}

scanner_number :: proc(scanner: ^Scanner) {
    for is_digit(scanner_peek(scanner)) {
        scanner_advance(scanner)
    }

    // fractional part
    if scanner_peek(scanner) == '.' && is_digit(scanner_peek(scanner, 1)) {
        scanner_advance(scanner) // consume '.'

        for is_digit(scanner_peek(scanner)) {
            scanner_advance(scanner)
        }
    }

    scanner_add_token(scanner, TokenType.Number)
}

scanner_identifier :: proc(scanner: ^Scanner) {
    for is_alpha_numeric(scanner_peek(scanner)) {
        scanner_advance(scanner)
    }

    text := scanner.source[scanner.start:scanner.current]

    if type, ok := keywords[text]; ok {
        scanner_add_token(scanner, type)
    } else {
       scanner_add_token(scanner, TokenType.Identifier)
    }
}

scanner_match :: proc(scanner: ^Scanner, expected: u8) -> bool {
    if scanner_is_at_end(scanner) { 
        return false 
    }
    if scanner.source[scanner.current] != expected { 
        return false 
    }

    scanner_advance(scanner)

    return true
}

scanner_peek :: proc(scanner: ^Scanner, offset := 0) -> u8 {
    if scanner.current + offset >= len(scanner.source) {
        return 0
    }

    return scanner.source[scanner.current+offset]
}

scanner_is_at_end :: proc(scanner: ^Scanner) -> bool {
    return scanner.current >= len(scanner.source)
}

scanner_advance :: proc(scanner: ^Scanner) -> u8 {
    v := scanner.source[scanner.current]
    scanner.current += 1

    return v
}

scanner_add_token :: proc(scanner: ^Scanner, type: TokenType, text := "") {
    _text := text
    _value: Value

    if text == "" {
        _text = scanner.source[scanner.start:scanner.current]
    }

    #partial switch type {
    case TokenType.String:
        _value = _text
    case TokenType.Number:
        _value, _ = strconv.parse_f64(_text)
    case TokenType.True:
        _value = true
    case TokenType.False:
        _value = false
    case TokenType.Nil:
        _value = Nil{}
    }

    append(&scanner.tokens, Token{
        type   = type,
        text   = _text,
        value  = _value,
        line   = scanner.line,
    })
}

is_digit :: proc(c: u8) -> bool {
    return c >= '0' && c <= '9';
}

is_alpha :: proc(c: u8) -> bool {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'
}

is_alpha_numeric :: proc(c: u8) -> bool {
    return is_alpha(c) || is_digit(c)
}

