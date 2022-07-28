package main

import "core:fmt"

Scanner :: struct{
    source  : string,
    start   : int,
    current : int,
    line    : int,
}

scanner_init :: proc(scanner: ^Scanner, source: string) {
    scanner.source  = source
    scanner.current = 0
    scanner.line    = 1
}

scanner_dump :: proc(scanner: ^Scanner) {
    line := -1
    
    for {
        token := scanner_scan_token(scanner)
        if token.line != line {
            fmt.printf("%04d ", token.line)
            line = token.line
        } else {
            fmt.print("   | ")
        }
        fmt.printf("%-12s '%s'\n", token.type, token.text)

        if token.type == .Eof {
            break
        }
    }
}

scanner_scan_token :: proc(scanner: ^Scanner) -> Token {
    scanner_skip_whitespace(scanner)
    scanner.start = scanner.current

    if scanner_is_at_end(scanner) {
        return scanner_token_eof(scanner)
    }

    switch c := scanner_advance(scanner); c {
    case '(': 
        return scanner_token_new(scanner, .LeftParen)
    case ')': 
        return scanner_token_new(scanner, .RightParen)
    case '{': 
        return scanner_token_new(scanner, .LeftBrace)
    case '}': 
        return scanner_token_new(scanner, .RightBrace)
    case ';': 
        return scanner_token_new(scanner, .Semicolon)
    case ',': 
        return scanner_token_new(scanner, .Comma)
    case '.': 
        return scanner_token_new(scanner, .Dot)
    case '-': 
        return scanner_token_new(scanner, .Minus)
    case '+': 
        return scanner_token_new(scanner, .Plus)
    case '/': 
        return scanner_token_new(scanner, .Slash)
    case '*': 
        return scanner_token_new(scanner, .Star)
    case '!': 
        if scanner_match(scanner, '=') {
            return scanner_token_new(scanner, .BangEqual)
        } else {
            return scanner_token_new(scanner, .Bang)
        }    
    case '=':
        if scanner_match(scanner, '=') {
            return scanner_token_new(scanner, .EqualEqual)
        } else {
            return scanner_token_new(scanner, .Equal)
        }    
    case '<':
        if scanner_match(scanner, '=') {
            return scanner_token_new(scanner, .LessEqual)
        } else {
            return scanner_token_new(scanner, .Less)
        }    
    case '>':
        if scanner_match(scanner, '=') {
            return scanner_token_new(scanner, .GreaterEqual)
        } else {
            return scanner_token_new(scanner, .Greater)
        }
    case '"':
        return scanner_scan_string(scanner)
    case:
        switch {
        case is_digit(c):
            return scanner_scan_number(scanner)
        case is_alpha(c):
            return scanner_scan_identifier(scanner)
        }
    }

    return scanner_token_error(scanner, "Unexpected character.")
}

scanner_is_at_end :: proc(scanner: ^Scanner) -> bool {
    return scanner.current >= len(scanner.source)
}

scanner_advance :: proc(scanner: ^Scanner) -> u8 {
    defer scanner.current += 1
    return scanner.source[scanner.current]
}

scanner_peek :: proc(scanner: ^Scanner) -> u8 {
    if scanner_is_at_end(scanner) {
        return 0
    }

    return scanner.source[scanner.current]
}

scanner_peek_next :: proc(scanner: ^Scanner) -> u8 {
    if scanner_is_at_end(scanner) {
        return 0
    }

    return scanner.source[scanner.current+1]
}

scanner_match :: proc(scanner: ^Scanner, expected: u8) -> bool {
    if scanner_is_at_end(scanner) {
        return false
    }
    if scanner.source[scanner.current] != expected {
        return false
    }
    scanner.current += 1
    return true
}

scanner_token_eof :: proc(scanner: ^Scanner) -> Token {
    return Token{
        type = .Eof,
        text = "<eof>",
        line = scanner.line,
    }
}

scanner_token_new :: proc(scanner: ^Scanner, type: TokenType) -> Token {
    return Token{
        type = type,
        text = scanner.source[scanner.start:scanner.current],
        line = scanner.line,
    }
}

scanner_token_error :: proc(scanner: ^Scanner, text: string) -> Token {
    return Token{
        type = .Error,
        text = text,
        line = scanner.line,
    }
}

scanner_skip_whitespace :: proc(scanner: ^Scanner) {
    for {
        switch scanner_peek(scanner) {
        case '\n':
            scanner.line += 1
            fallthrough
        case ' ', '\r', '\t':
            _ = scanner_advance(scanner)
        case '/':
            if scanner_peek_next(scanner) == '/' {
                for scanner_peek(scanner) != '\n' && !scanner_is_at_end(scanner) {
                    scanner_advance(scanner)
                }
            } else {
                return
            }
        case:
            return
        }
    }
}

scanner_scan_string :: proc(scanner: ^Scanner) -> Token {
    for scanner_peek(scanner) != '"' && !scanner_is_at_end(scanner) {
        if scanner_peek(scanner) == '\n' {
            scanner.line += 1
        }
        scanner_advance(scanner)
    }

    if scanner_is_at_end(scanner) {
        return scanner_token_error(scanner, "Unterminated string.")
    }

    // the closing quote.
    _ = scanner_advance(scanner)

    token := scanner_token_new(scanner, .String)
    token.text = token.text[1:len(token.text)-1]

    return token
}

is_digit :: proc(c: u8) -> bool {
    return c >= '0' && c <= '9'
}

is_alpha :: proc(c: u8) -> bool {
    switch c {
    case 'a'..='z':
        return true
    case 'A'..='Z':
        return true
    case '_':
        return true
    case:
        return false
    }
}

scanner_scan_number :: proc(scanner: ^Scanner) -> Token {
    for is_digit(scanner_peek(scanner)) {
        scanner_advance(scanner)
    }

    if scanner_peek(scanner) == '.' && is_digit(scanner_peek_next(scanner)) {
        // consume '.'
        _ = scanner_advance(scanner)

        for is_digit(scanner_peek(scanner)) {
            scanner_advance(scanner)
        }
    }

    return scanner_token_new(scanner, .Number)
}

scanner_scan_identifier :: proc(scanner: ^Scanner) -> Token {
    for {
        c := scanner_peek(scanner)

        if !is_alpha(scanner_peek(scanner)) && !is_digit(scanner_peek(scanner)) {
            break
        }

        scanner_advance(scanner)
    }

    return scanner_token_new(scanner, scanner_identifier_type(scanner))
}

scanner_identifier_type :: proc(scanner: ^Scanner) -> TokenType {
    switch scanner.source[scanner.start:scanner.current] {
    case "and"    : return .And
    case "class"  : return .Class
    case "else"   : return .Else
    case "false"  : return .False
    case "for"    : return .For
    case "fun"    : return .Fun
    case "if"     : return .If
    case "nil"    : return .Nil
    case "or"     : return .Or
    case "print"  : return .Print
    case "return" : return .Return
    case "super"  : return .Super
    case "this"   : return .This
    case "true"   : return .True
    case "var"    : return .Var
    case "while"  : return .While
    }

    return .Identifier
}
