package main

import "core:os"
import "core:fmt"

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

parser_parse :: proc(parser: ^Parser) -> []^Stmt {
    statements: [dynamic]^Stmt

    for !parser_is_at_end(parser) {
        stmt := parser_declaration(parser)

        append(&statements, stmt)
    }

    return statements[:]
    /* expr, ok := parser_expression(parser) */
    /* if !ok { */
    /*     return nil */
    /* } */

    /* return expr */
}

parser_declaration :: proc(parser: ^Parser) -> ^Stmt {
    using TokenType

    stmt: ^Stmt
    ok: bool

    switch {
    case parser_match(parser, []TokenType{Class}):
        stmt, ok = parser_class_declaration(parser)
    case parser_match(parser, []TokenType{Fun}):
        stmt, ok = parser_function_declaration(parser, "function")
    case parser_match(parser, []TokenType{Var}):
        stmt, ok = parser_var_declaration(parser)
    case:
        stmt, ok = parser_statement(parser)
    }

    if !ok {
        parser_synchronize(parser)

        return nil
    }

    return stmt
}

parser_class_declaration :: proc(parser: ^Parser) -> (^Stmt, bool) {
    using TokenType

    name, ok := parser_consume(parser, Identifier, "Expect class name.")
    if !ok {
        return nil, false
    }

    _, ok = parser_consume(parser, LeftBrace, "Expect '{' before class body.")
    if !ok {
        return nil, false
    }

    methods: [dynamic]Function

    for !parser_check(parser, RightBrace) && !parser_is_at_end(parser) {
        function, ok := parser_function_declaration(parser, "method")
        if !ok {
            return nil, false
        }

        #partial switch v in function {
        case Function:
            append(&methods, v)
        }
    }

    _, ok = parser_consume(parser, RightBrace, "Expect '}' after class body.")
    if !ok {
        return nil, false
    }

    return new_class(name, Variable{}, methods[:]), true
}

parser_function_declaration :: proc(parser: ^Parser, kind: string) -> (^Stmt, bool) {
    using TokenType

    name, ok := parser_consume(parser, Identifier, 
        fmt.tprintf("Expect %s name.", kind))
    if !ok {
        return nil, false
    }

    _, ok = parser_consume(parser, LeftParen,
        fmt.tprintf("Expect '(' after %s name.", kind))
    if !ok {
        return nil, false
    }

    parameters: [dynamic]Token

    if !parser_check(parser, RightParen) {
        for {
            if len(parameters) >= 255 {
                error(parser_peek(parser), "Can't have more than 255 parameters.")
                return nil, false
            }

            name, ok := parser_consume(parser, Identifier, "Expect parameter name.")
            if !ok {
                return nil, false
            }

            append(&parameters, name)

            if !parser_match(parser, []TokenType{Comma}) {
                break
            }
        }
    }

    _, ok = parser_consume(parser, RightParen, 
        "Expect ')' after parameters.")
    if !ok {
        return nil, false
    }

    _, ok = parser_consume(parser, LeftBrace,
        fmt.tprintf("Expect '{' before %s body.", kind))
    if !ok {
        return nil, false
    }

    body: []^Stmt

    body, ok = parser_block(parser)
    if !ok {
        return nil, false
    }

    return new_function(name, parameters[:], body), true
}

parser_var_declaration :: proc(parser: ^Parser) -> (^Stmt, bool) {
    using TokenType

    name, ok := parser_consume(parser, Identifier, "Expect variable name")
    if !ok {
        return nil, false
    }

    initializer: ^Expr
    if parser_match(parser, []TokenType{Equal}) {
        initializer, ok = parser_expression(parser)
        if !ok {
            return nil, false
        }
    }

    _, ok = parser_consume(parser, Semicolon, "Expect ';' after variable declaration.")
    if !ok {
        return nil, false
    }

    return new_var(name, initializer), true
}

parser_statement :: proc(parser: ^Parser) -> (^Stmt, bool) {
    using TokenType

    switch {
    case parser_match(parser, []TokenType{For}):
        return parser_for_statement(parser)
    case parser_match(parser, []TokenType{If}):
        return parser_if_statement(parser)
    case parser_match(parser, []TokenType{Print}):
        return parser_print_statement(parser)
    case parser_match(parser, []TokenType{Return}):
        return parser_return_statement(parser)
    case parser_match(parser, []TokenType{While}):
        return parser_while_statement(parser)
    case parser_match(parser, []TokenType{LeftBrace}):
        return parser_block_statement(parser)
    }

    return parser_expression_statement(parser)
}

parser_for_statement :: proc(parser: ^Parser) -> (^Stmt, bool) {
    using TokenType

    _, ok := parser_consume(parser, LeftParen, "Expect '(' after 'if'.")
    if !ok {
        return nil, false
    }

    initializer: ^Stmt
    condition: ^Expr
    increment: ^Expr
    body: ^Stmt

    if parser_match(parser, []TokenType{Semicolon}) {
        initializer = nil
    } else if parser_match(parser, []TokenType{Var}) {
        initializer, ok = parser_var_declaration(parser)
    } else {
        initializer, ok = parser_expression_statement(parser)
    }

    if !ok {
        return nil, false
    }

    if !parser_check(parser, Semicolon) {
        condition, ok = parser_expression(parser)
        if !ok {
            return nil, false
        }
    }

    _, ok = parser_consume(parser, Semicolon, "Expect ';' after loop condition.")
    if !ok {
        return nil, false
    }

    if !parser_check(parser, RightParen) {
        increment, ok = parser_expression(parser)
        if !ok {
            return nil, false
        }
    }

    _, ok = parser_consume(parser, RightParen, "Expect ')' after for clauses.")
    if !ok {
        return nil, false
    }

    body, ok = parser_statement(parser)

    // desugaring for -> while

    if increment != nil {
        body = new_block([]^Stmt{
            body,
            new_expression(increment),
        })
    }

    if condition == nil {
        condition = new_literal(Token{
            type=True,
            value=true,
        })
    }

    body = new_while(condition, body)

    if initializer != nil {
        body = new_block([]^Stmt{
            initializer,
            body,
        })
    }

    return body, true
}

parser_if_statement :: proc(parser: ^Parser) -> (^Stmt, bool) {
    using TokenType

    if _, ok := parser_consume(parser, LeftParen, "Expect '(' after 'if'."); !ok {
        return nil, false
    }

    condition, ok := parser_expression(parser)
    if !ok {
        return nil, false
    }

    if _, ok := parser_consume(parser, RightParen, "Expect ')' after if condition."); !ok {
        return nil, false
    }

    thenBranch: ^Stmt
    elseBranch: ^Stmt

    thenBranch, ok = parser_statement(parser)
    if !ok {
        return nil, false
    }

    if parser_match(parser, []TokenType{Else}) {
        elseBranch, ok = parser_statement(parser)
        if !ok {
            return nil, false
        }
    }

    return new_if(condition, thenBranch, elseBranch), true
}

parser_while_statement :: proc(parser: ^Parser) -> (^Stmt, bool) {
    using TokenType

    if _, ok := parser_consume(parser, LeftParen, "Expect '(' after 'while'."); !ok {
        return nil, false
    }

    condition, ok := parser_expression(parser)
    if !ok {
        return nil, false
    }

    if _, ok := parser_consume(parser, RightParen, "Expect ')' after while condition."); !ok {
        return nil, false
    }

    body: ^Stmt
    body, ok = parser_statement(parser)
    if !ok {
        return nil, false
    }

    return new_while(condition, body), true
}

parser_print_statement :: proc(parser: ^Parser) -> (^Stmt, bool) {
    using TokenType

    value, ok := parser_expression(parser)
    if !ok {
        return nil, false
    }

    _, ok = parser_consume(parser, Semicolon, "Expect ';' after value.")
    if !ok {
        return nil, false
    }

    return new_print(value), true 
}

parser_return_statement :: proc(parser: ^Parser) -> (^Stmt, bool) {
    using TokenType

    keyword := parser_previous(parser)

    value: ^Expr
    ok: bool

    if !parser_check(parser, Semicolon) {
        value, ok = parser_expression(parser)
        if !ok {
            return nil, false
        }
    }

    _, ok = parser_consume(parser, Semicolon, "Expect ';' after return value.")
    if !ok {
        return nil, false
    }

    return new_return(keyword, value), true
}

parser_expression_statement :: proc(parser: ^Parser) -> (^Stmt, bool) {
    using TokenType

    expr, ok := parser_expression(parser)
    if !ok {
        return nil, false
    }

    _, ok = parser_consume(parser, Semicolon, "Expect ';' after value.")
    if !ok {
        return nil, false
    }

    return new_expression(expr), true
}

parser_block_statement :: proc(parser: ^Parser) -> (^Stmt, bool) {
    body, ok := parser_block(parser)
    if !ok {
        return nil, false
    }

    return new_block(body), true
}

parser_block :: proc(parser: ^Parser) -> ([]^Stmt, bool) {
    using TokenType

    statements: [dynamic]^Stmt

    for !parser_check(parser, RightBrace) && !parser_is_at_end(parser) {
        stmt := parser_declaration(parser)
        if stmt == nil {
            return nil, false
        }

        append(&statements, stmt)
    }

    _, ok := parser_consume(parser, RightBrace, "Expect '}' after block.")
    if !ok {
        return nil, false
    }

    return statements[:], true
}

parser_expression :: proc(parser: ^Parser) -> (^Expr, bool) {
    return parser_assignment(parser)
}

parser_assignment :: proc(parser: ^Parser) -> (^Expr, bool) {
    using TokenType

    expr, ok := parser_or(parser)
    if !ok {
        return nil, false
    }

    if parser_match(parser, []TokenType{Equal}) {
        equals := parser_previous(parser)
        value, ok := parser_assignment(parser)
        if !ok {
            return nil, false
        }

        #partial switch l in expr {
        case Variable:
            return new_assign(l.name, value), true
        }

        error(equals, "Invalid assignment target.")
    }

    return expr, true
}

parser_or :: proc(parser: ^Parser) -> (^Expr, bool) {
    using TokenType

    expr, ok := parser_equality(parser)
    if !ok {
        return nil, false
    }

    for parser_match(parser, []TokenType{Or}) {
        operator := parser_previous(parser)

        right, ok := parser_equality(parser)
        if !ok {
            return nil, false
        }

        expr = new_logical(expr, operator, right)
    }

    return expr, true
}

parser_and :: proc(parser: ^Parser) -> (^Expr, bool) {
    using TokenType

    expr, ok := parser_equality(parser)
    if !ok {
        return nil, false
    }

    for parser_match(parser, []TokenType{And}) {
        operator := parser_previous(parser)

        right, ok := parser_equality(parser)
        if !ok {
            return nil, false
        }

        expr = new_logical(expr, operator, right)
    }

    return expr, true
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
        call, ok := parser_call(parser)
        if !ok {
            return nil, false
        }

        expr = call
    }

    return expr, true
}

parser_call :: proc(parser: ^Parser) -> (^Expr, bool) {
    using TokenType

    expr, ok := parser_primary(parser)
    if !ok {
        return nil, false
    }

    for {
        if parser_match(parser, []TokenType{LeftParen}) {
            expr, ok = parser_finish_call(parser, expr)
            if !ok {
                return nil, false
            }
        } else {
            break
        }
    }

    return expr, true
}

parser_finish_call :: proc(parser: ^Parser, callee: ^Expr) -> (^Expr, bool) {
    using TokenType

    arguments: [dynamic]^Expr

    if !parser_check(parser, RightParen) {
        for {
            if len(arguments) >= 255 {
                error(parser_peek(parser), "Can't have more than 255 arguments.")
            }

            expr, ok := parser_expression(parser)
            if !ok {
                return nil, false
            }

            append(&arguments, expr)

            if !parser_match(parser, []TokenType{Comma}) {
                break
            }
        }
    }

    paren, ok := parser_consume(parser, RightParen, "Expect ')' after arguments.")
    if !ok {
        return nil, false
    }

    return new_call(callee, paren, arguments[:]), true
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
    case parser_check(parser, Identifier):
        expr = new_variable(parser_advance(parser))
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
