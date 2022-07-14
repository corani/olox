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

/*
visit_expr :: proc(expr: ^Expr) {
    switch v in expr {
    case Assign  : visit_expr_assign(v)
    case Binary  : visit_expr_binary(v)
    case Call    : visit_expr_call(v)
    case Get     : visit_expr_get(v)
    case Grouping: visit_expr_grouping(v)
    case Literal : visit_expr_literal(v)
    case Logical : visit_expr_logical(v)
    case Set     : visit_expr_set(v)
    case Super   : visit_expr_super(v)
    case This    : visit_expr_this(v)
    case Unary   : visit_expr_unary(v)
    case Variable: visit_expr_variable(v)
    }
}
*/

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

/*
visit_stmt :: proc(stmt: ^Stmt) {
    switch v in stmt {
    case Block     : visit_stmt_block(v)
    case Class     : visit_stmt_class(v)
    case Expression: visit_stmt_expression(v)
    case Function  : visit_stmt_function(v)
    case If        : visit_stmt_if(v)
    case Print     : visit_stmt_print(v)
    case Return    : visit_stmt_return(v)
    case Var       : visit_stmt_var(v)
    case While     : visit_stmt_while(v)
    }
}
*/
