package main 

global_ast_id := 0

new_ast_id :: proc() -> int {
    result := global_ast_id
    global_ast_id += 1

    return result
}

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

new_expr :: proc(N: $I) -> ^Expr {
    expr := new(Expr)
    expr^ = N

    return expr
}

Assign :: struct{
    name  : Token,
    value : ^Expr,
    id    : int,
}

new_assign :: proc(name: Token, value: ^Expr) -> ^Expr {
    return new_expr(Assign{
        name  = name,
        value = value,
        id    = new_ast_id(),
    })
}

Binary :: struct{
    left     : ^Expr,
    operator : Token,
    right    : ^Expr,
    id       : int,
}

new_binary :: proc(left: ^Expr, operator: Token, right: ^Expr) -> ^Expr {
    return new_expr(Binary{
        left     = left,
        operator = operator,
        right    = right,
        id       = new_ast_id(),
    })
}

Call :: struct{
    callee    : ^Expr,
    paren     : Token,
    arguments : [dynamic]^Expr,
    id        : int,
}

new_call :: proc(callee: ^Expr, paren: Token, arguments: []^Expr) -> ^Expr {
    args: [dynamic]^Expr

    for arg in arguments {
        append(&args, arg)
    }

    return new_expr(Call{
        callee    = callee,
        paren     = paren,
        arguments = args,
        id        = new_ast_id(),
    })
}

Get :: struct{
    object : ^Expr,
    name   : Token,
    id     : int,
}

new_get :: proc(object: ^Expr, name: Token) -> ^Expr {
    return new_expr(Get{
        object = object,
        name   = name,
        id     = new_ast_id(),
    })
}

Grouping :: struct{
    expression : ^Expr,
    id         : int,
}

new_grouping :: proc(expr: ^Expr) -> ^Expr {
    return new_expr(Grouping{
        expression = expr,
        id         = new_ast_id(),
    })
}

Literal :: struct{
    value : Token,
    id    : int,
}

new_literal :: proc(value: Token) -> ^Expr {
    return new_expr(Literal{
        value = value,
        id    = new_ast_id(),
    })
}

Logical :: struct{
    left     : ^Expr,
    operator : Token,
    right    : ^Expr,
    id       : int,
}

new_logical :: proc(left: ^Expr, operator: Token, right: ^Expr) -> ^Expr {
    return new_expr(Logical{
        left     = left,
        operator = operator,
        right    = right,
        id       = new_ast_id(),
    })
}

Set :: struct{
    object : ^Expr,
    name   : Token,
    value  : ^Expr,
    id     : int,
}

new_set :: proc(object: ^Expr, name: Token, value: ^Expr) -> ^Expr {
    return new_expr(Set{
        object = object,
        name   = name,
        value  = value,
        id     = new_ast_id(),
    })
}

Super :: struct{
    keyword : Token,
    method  : Token,
    id      : int,
}

new_super :: proc(keyword: Token, method: Token) -> ^Expr {
    return new_expr(Super{
        keyword = keyword,
        method  = method,
        id      = new_ast_id(),
    })
}

This :: struct{
    keyword : Token,
    id      : int,
}

new_this :: proc(keyword: Token) -> ^Expr {
    return new_expr(This{
        keyword = keyword,
        id      = new_ast_id(),
    })
}

Unary :: struct{
    operator : Token,
    right    : ^Expr,
    id       : int,
}

new_unary :: proc(operator: Token, right: ^Expr) -> ^Expr {
    return new_expr(Unary{
        operator = operator,
        right    = right,
        id       = new_ast_id(),
    })
}

Variable :: struct{
    name : Token,
    id   : int,
}

new_variable :: proc(name: Token) -> ^Expr {
    return new_expr(Variable{
        name = name,
        id   = new_ast_id(),
    })
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

new_stmt :: proc(N: $I) -> ^Stmt {
    stmt := new(Stmt)
    stmt^ = N

    return stmt
}

Block :: struct{
    statements : [dynamic]^Stmt,
    id         : int,
}

new_block :: proc(statements: []^Stmt) -> ^Stmt {
    stmts: [dynamic]^Stmt

    for stmt in statements {
        append(&stmts, stmt)
    }

    return new_stmt(Block{
        statements = stmts,
        id         = new_ast_id(),
    })
}

Class :: struct{
    name       : Token,
    superclass : ^Variable,
    methods    : [dynamic]^Function,
    id         : int,
}

new_class :: proc(name: Token, superclass: ^Variable, methods: []^Function) -> ^Stmt {
    fns: [dynamic]^Function

    for m in methods {
        append(&fns, m)
    }

    return new_stmt(Class{
        name       = name,
        superclass = superclass,
        methods    = fns,
        id         = new_ast_id(),
    })
}

Expression :: struct{
    expression : ^Expr,
    id         : int,
}

new_expression :: proc(expression: ^Expr) -> ^Stmt {
    return new_stmt(Expression{
        expression = expression,
        id         = new_ast_id(),
    })
}

Function :: struct{
    name   : Token,
    params : [dynamic]Token,
    body   : [dynamic]^Stmt,
    id     : int,
}

new_function :: proc(name: Token, params: []Token, body: []^Stmt) -> ^Stmt {
    _params: [dynamic]Token
    _stmts : [dynamic]^Stmt

    for p in params{
        append(&_params, p)
    }

    for s in body{
        append(&_stmts, s)
    }

    return new_stmt(Function{
        name   = name,
        params = _params,
        body   = _stmts,
        id     = new_ast_id(),
    })
}

If :: struct{
    condition  : ^Expr,
    thenBranch : ^Stmt,
    elseBranch : ^Stmt,
    id         : int,
}

new_if :: proc(condition: ^Expr, thenBranch: ^Stmt, elseBranch: ^Stmt) -> ^Stmt {
    return new_stmt(If{
        condition  = condition,
        thenBranch = thenBranch,
        elseBranch = elseBranch,
        id         = new_ast_id(),
    })
}

Print :: struct{
    expression : ^Expr,
    id         : int,
}

new_print :: proc(expression: ^Expr) -> ^Stmt {
    return new_stmt(Print{
        expression = expression,
        id         = new_ast_id(),
    })
}


Return :: struct{
    keyword : Token,
    value   : ^Expr,
    id      : int,
}

new_return :: proc(keyword: Token, value: ^Expr) -> ^Stmt {
    return new_stmt(Return{
        keyword = keyword,
        value   = value,
        id      = new_ast_id(),
    })
}

Var :: struct{
    name        : Token,
    initializer : ^Expr,
    id          : int,
}

new_var :: proc(name: Token, initializer: ^Expr) -> ^Stmt {
    return new_stmt(Var{
        name        = name,
        initializer = initializer,
        id          = new_ast_id(),
    })
}

While :: struct{
    condition : ^Expr,
    body      : ^Stmt,
    id        : int,
}

new_while :: proc(condition: ^Expr, body: ^Stmt) -> ^Stmt {
    return new_stmt(While{
        condition = condition,
        body      = body,
        id        = new_ast_id(),
    })
}
