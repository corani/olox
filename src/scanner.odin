package main 

import "core:strconv"

keywords := map[string]TokenType{
    "and"    = .And,
    "class"  = .Class,
    "else"   = .Else,
    "false"  = .False,
    "for"    = .For,
    "fun"    = .Fun,
    "if"     = .If,
    "nil"    = .Nil,
    "or"     = .Or,
    "print"  = .Print,
    "return" = .Return,
    "super"  = .Super,
    "this"   = .This,
    "true"   = .True,
    "var"    = .Var,
    "while"  = .While,
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
        type = TokenType.EOF,
        text = "<eof>",
        line = scanner.line,
    })

    return scanner.tokens[:]
}

scanner_token :: proc(scanner: ^Scanner) {
    switch c := scanner_advance(scanner); c {
    case '(': scanner_add_token(scanner, .LeftParen)
    case ')': scanner_add_token(scanner, .RightParen)
    case '{': scanner_add_token(scanner, .LeftBrace)
    case '}': scanner_add_token(scanner, .RightBrace)
    case '.': scanner_add_token(scanner, .Dot)
    case ',': scanner_add_token(scanner, .Comma)
    case '-': scanner_add_token(scanner, .Minus)
    case '+': scanner_add_token(scanner, .Plus)
    case ';': scanner_add_token(scanner, .Semicolon)
    case '*': scanner_add_token(scanner, .Star)
    case '!': 
        if scanner_match(scanner, '=') {
            scanner_add_token(scanner, .BangEqual)
        } else {
            scanner_add_token(scanner, .Bang)
        }
    case '=': 
        if scanner_match(scanner, '=') {
            scanner_add_token(scanner, .EqualEqual)
        } else {
            scanner_add_token(scanner, .Equal)
        }
    case '<': 
        if scanner_match(scanner, '=') {
            scanner_add_token(scanner, .LessEqual)
        } else {
            scanner_add_token(scanner, .Less)
        }
    case '>': 
        if scanner_match(scanner, '=') {
            scanner_add_token(scanner, .GreaterEqual)
        } else {
            scanner_add_token(scanner, .Greater)
        }
    case '/':
        if scanner_match(scanner, '/') {
            for scanner_peek(scanner) != '\n' && !scanner_is_at_end(scanner) {
                scanner_advance(scanner)
            }
        } else {
            scanner_add_token(scanner, .Slash)
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

    scanner_add_token(scanner, .String, scanner.source[scanner.start+1:scanner.current-1])
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

    scanner_add_token(scanner, .Number)
}

scanner_identifier :: proc(scanner: ^Scanner) {
    for is_alpha_numeric(scanner_peek(scanner)) {
        scanner_advance(scanner)
    }

    text := scanner.source[scanner.start:scanner.current]

    if type, ok := keywords[text]; ok {
        scanner_add_token(scanner, type)
    } else {
       scanner_add_token(scanner, .Identifier)
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
    case .String:
        _value = _text
    case .Number:
        _value, _ = strconv.parse_f64(_text)
    case .True:
        _value = true
    case .False:
        _value = false
    case .Nil:
        _value = Nil{}
    }

    append(&scanner.tokens, Token{
        type  = type,
        text  = _text,
        value = _value,
        line  = scanner.line,
    })
}

is_digit :: proc(c: u8) -> bool {
    switch c {
    case '0'..='9':
        return true
    }

    return false
}

is_alpha :: proc(c: u8) -> bool {
    switch c {
    case 'a'..='z':
        return true
    case 'A'..='Z':
        return true
    case '_':
        return true
    }

    return false
}

is_alpha_numeric :: proc(c: u8) -> bool {
    return is_alpha(c) || is_digit(c)
}

