package main

import "core:os"

Parser :: struct{
    tokens : []Token,
    current: int,
}

new_parser :: proc(tokens: []Token) -> ^Parser {
    parser := new(Parser)
    parser.tokens  = tokens
    parser.current = 0

    return parser
}

parser_parse :: proc(parser: ^Parser) -> ^Expr {
    expr, ok := parser_expression(parser)
    if !ok {
        return nil
    }

    return expr
}

parser_expression :: proc(parser: ^Parser) -> (^Expr, bool) {
    return parser_equality(parser)
}

parser_equality :: proc(parser: ^Parser) -> (^Expr, bool) {
    using TokenType

    expr, ok := parser_comparison(parser)
    if !ok {
        return nil, false
    }

    for parser_match(parser, []TokenType{BangEqual, EqualEqual}) {
        operator := parser_previous(parser)

        right, ok := parser_comparison(parser)
        if !ok {
            return nil, false
        }
        
        expr = new_binary(expr, operator, right)
    }

    return expr, true
}

parser_comparison :: proc(parser: ^Parser) -> (^Expr, bool) {
    using TokenType

    expr, ok := parser_term(parser)
    if !ok {
        return nil, false
    }

    for parser_match(parser, []TokenType{Greater, GreaterEqual, Less, LessEqual}) {
        operator := parser_previous(parser)

        right, ok := parser_term(parser)
        if !ok {
            return nil, false
        }

        expr = new_binary(expr, operator, right)
    }

    return expr, true
}

parser_term :: proc(parser: ^Parser) -> (^Expr, bool) {
    using TokenType

    expr, ok := parser_factor(parser)
    if !ok {
        return nil, false
    }

    for parser_match(parser, []TokenType{Minus, Plus}) {
        operator := parser_previous(parser)

        right, ok := parser_factor(parser)
        if !ok {
            return nil, false
        }

        expr = new_binary(expr, operator, right)
    }

    return expr, true
}

parser_factor :: proc(parser: ^Parser) -> (^Expr, bool) {
    using TokenType

    expr, ok := parser_unary(parser)
    if !ok {
        return nil, false
    }

    for parser_match(parser, []TokenType{Slash, Star}) {
        operator := parser_previous(parser)

        right, ok := parser_unary(parser)
        if !ok {
            return nil, false
        }

        expr = new_binary(expr, operator, right)
    }

    return expr, true
}

parser_unary :: proc(parser: ^Parser) -> (^Expr, bool) {
    using TokenType

    expr: ^Expr

    if parser_match(parser, []TokenType{Bang, Minus}) {
        operator := parser_previous(parser)
        right, ok := parser_unary(parser)
        if !ok {
            return nil, false
        }

        expr = new_unary(operator, right)
    } else {
        primary, ok := parser_primary(parser)
        if !ok {
            return nil, false
        }

        expr = primary
    }

    return expr, true
}

parser_primary :: proc(parser: ^Parser) -> (^Expr, bool) {
    using TokenType

    expr: ^Expr

    switch {
    case parser_check(parser, False):
        expr = new_literal(parser_advance(parser))
    case parser_check(parser, True):
        expr = new_literal(parser_advance(parser))
    case parser_check(parser, Nil):
        expr = new_literal(parser_advance(parser))
    case parser_check(parser, Number):
        expr = new_literal(parser_advance(parser))
    case parser_check(parser, String):
        expr = new_literal(parser_advance(parser))
    case parser_check(parser, LeftParen):
        parser_consume(parser, LeftParen)

        inner, ok := parser_expression(parser)
        if !ok {
            return nil, false
        }

        _, ok = parser_consume(parser, RightParen, "Expect ')' after expression.")
        if !ok {
            return nil, false
        }

        expr = new_grouping(inner)
    case:
        parser_error(parser, "Expect expression.")

        return nil, false
    }

    return expr, true
}

parser_match :: proc(parser: ^Parser, types: []TokenType) -> bool {
    for type in types {
        if parser_check(parser, type) {
            parser_advance(parser)

            return true
        }
    }

    return false
}

parser_consume :: proc(parser: ^Parser, type: TokenType, msg := "") -> (Token, bool) {
    if parser_check(parser, type) {
        return parser_advance(parser), true
    }

    parser_error(parser, msg)

    return Token{}, false
}

parser_check :: proc(parser: ^Parser, type: TokenType) -> bool {
    if parser_is_at_end(parser) {
        return false
    }

    return parser_peek(parser).type == type
}

parser_advance :: proc(parser: ^Parser) -> Token {
    if !parser_is_at_end(parser) {
        parser.current += 1
    }

    return parser_previous(parser)
}

parser_is_at_end :: proc(parser: ^Parser) -> bool {
    return parser_peek(parser).type == TokenType.EOF
}

parser_peek :: proc(parser: ^Parser) -> Token {
    return parser.tokens[parser.current]
}

// TODO(daniel): peek with offset -1
parser_previous :: proc(parser: ^Parser) -> Token {
    return parser.tokens[parser.current-1]
}

parser_error :: proc(parser: ^Parser, msg: string) {
    token := parser_peek(parser)

    error(token, msg)
}

parser_synchronize :: proc(parser: ^Parser) {
    using TokenType

    parser_advance(parser)

    for !parser_is_at_end(parser) {
        if parser_previous(parser).type == EOF {
            return
        }

        #partial switch parser_peek(parser).type {
        case Class, Fun, Var, For, If, While, Print, Return:
            return
        }

        parser_advance(parser)
    }
}
