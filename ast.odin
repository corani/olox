package main 

Expr :: union{
    Assign,
    Binary,
    Call,
    Get,
    Grouping,
    Literal,
    Logical,
    Set,
    Super,
    This,
    Unary,
    Variable,
}

Assign :: struct{
    name : Token,
    value: ^Expr,
}

Binary :: struct{
    left    : ^Expr,
    operator: Token,
    right   : ^Expr,
}

new_binary :: proc(left: ^Expr, operator: Token, right: ^Expr) -> ^Expr {
    binary := new(Expr)
    binary^ = Binary{
        left=left,
        operator=operator,
        right=right,
    }

    return binary
}

Call :: struct{
    callee   : ^Expr,
    paren    : Token,
    arguments: [dynamic]^Expr,
}

Get :: struct{
    object: ^Expr,
    name  : Token,
}

Grouping :: struct{
    expression: ^Expr,
}

new_grouping :: proc(expr: ^Expr) -> ^Expr {
    grouping := new(Expr)
    grouping^ = Grouping{
        expression=expr,
    }

    return grouping
}

Literal :: struct{
    value: Token,
}

new_literal :: proc(value: Token) -> ^Expr {
    literal := new(Expr)
    literal^ = Literal{
        value=value,
    }

    return literal
}

Logical :: struct{
    left    : ^Expr,
    operator: Token,
    right   : ^Expr,
}

Set :: struct{
    object: ^Expr,
    name  : Token,
    value : ^Expr,
}

Super :: struct{
    keyword: Token,
    method : Token,
}

This :: struct{
    keyword: Token,
}

Unary :: struct{
    operator: Token,
    right   : ^Expr,
}

new_unary :: proc(operator: Token, right: ^Expr) -> ^Expr {
    unary := new(Expr)
    unary^ = Unary{
        operator=operator,
        right=right,
    }

    return unary
}

Variable :: struct{
    name: Token,
}

Stmt :: union{
    Block,
    Class,
    Expression,
    Function,
    If,
    Print,
    Return,
    Var,
    While,
}

Block :: struct{
    statements: [dynamic]^Stmt,
}

Class :: struct{
    name      : Token,
    superclass: Variable,
    methods   : [dynamic]^Function,
}

Expression :: struct{
    expression: ^Expr,
}

Function :: struct{
    name  : Token,
    params: [dynamic]Token,
    body  : [dynamic]^Stmt,
}

If :: struct{
    condition : ^Expr,
    thenBranch: ^Stmt,
    elseBranch: ^Stmt,
}

Print :: struct{
    expression: ^Expr,
}

Return :: struct{
    keyword: Token,
    value  : ^Expr,
}

Var :: struct{
    name       : Token,
    initializer: ^Expr,
}

While :: struct{
    condition: ^Expr,
    body     : ^Stmt,
}

