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

new_assign :: proc(name: Token, value: ^Expr) -> ^Expr {
    assign := new(Expr)
    assign^ = Assign{
        name=name,
        value=value,
    }

    return assign
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

new_call :: proc(callee: ^Expr, paren: Token, arguments: []^Expr) -> ^Expr {
    args: [dynamic]^Expr

    for arg in arguments {
        append(&args, arg)
    }

    call := new(Expr)
    call^ = Call{
        callee=callee,
        paren=paren,
        arguments=args,
    }

    return call
}

Get :: struct{
    object: ^Expr,
    name  : Token,
}

new_get :: proc(object: ^Expr, name: Token) -> ^Expr {
    get := new(Expr)
    get^ = Get{
        object=object,
        name=name,
    }

    return get
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

new_logical :: proc(left: ^Expr, operator: Token, right: ^Expr) -> ^Expr {
    logical := new(Expr)
    logical^ = Logical{
        left=left,
        operator=operator,
        right=right,
    }

    return logical
}

Set :: struct{
    object: ^Expr,
    name  : Token,
    value : ^Expr,
}

new_set :: proc(object: ^Expr, name: Token, value: ^Expr) -> ^Expr {
    set := new(Expr)
    set^ = Set{
        object=object,
        name=name,
        value=value,
    }

    return set
}

Super :: struct{
    keyword: Token,
    method : Token,
}

new_super :: proc(keyword: Token, method: Token) -> ^Expr {
    super := new(Expr)
    super^ = Super{
        keyword=keyword,
        method=method,
    }

    return super
}

This :: struct{
    keyword: Token,
}

new_this :: proc(keyword: Token) -> ^Expr {
    this := new(Expr)
    this^ = This{
        keyword=keyword,
    }

    return this
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

new_variable :: proc(name: Token) -> ^Expr {
    variable := new(Expr)
    variable^ = Variable{
        name=name,
    }

    return variable
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

new_block :: proc(statements: []^Stmt) -> ^Stmt {
    stmts: [dynamic]^Stmt

    for stmt in statements {
        append(&stmts, stmt)
    }

    block := new(Stmt)
    block^ = Block{
        statements=stmts,
    }

    return block
}

Class :: struct{
    name      : Token,
    superclass: Variable,
    methods   : [dynamic]^Function,
}

new_class :: proc(name: Token, superclass: Variable, methods: []^Function) -> ^Stmt {
    _methods: [dynamic]^Function

    for m in methods {
        append(&_methods, m)
    }

    class := new(Stmt)
    class^ = Class{
        name=name,
        superclass=superclass,
        methods=_methods,
    }

    return class
}

Expression :: struct{
    expression: ^Expr,
}

new_expression :: proc(expression: ^Expr) -> ^Stmt {
    stmt := new(Stmt)
    stmt^ = Expression{
        expression=expression,
    }

    return stmt
}

Function :: struct{
    name  : Token,
    params: [dynamic]Token,
    body  : [dynamic]^Stmt,
}

new_function :: proc(name: Token, params: []Token, body: []^Stmt) -> ^Stmt {
    _params: [dynamic]Token
    _body: [dynamic]^Stmt

    for p in params{
        append(&_params, p)
    }

    for s in body{
        append(&_body, s)
    }

    function := new(Stmt)
    function^ = Function{
        name=name,
        params=_params,
        body=_body,
    }

    return function
}

If :: struct{
    condition : ^Expr,
    thenBranch: ^Stmt,
    elseBranch: ^Stmt,
}

new_if :: proc(condition: ^Expr, thenBranch: ^Stmt, elseBranch: ^Stmt) -> ^Stmt {
    ifs := new(Stmt)
    ifs^ = If{
        condition=condition,
        thenBranch=thenBranch,
        elseBranch=elseBranch,
    }

    return ifs
}

Print :: struct{
    expression: ^Expr,
}

new_print :: proc(expression: ^Expr) -> ^Stmt {
    stmt := new(Stmt)
    stmt^ = Print{
        expression=expression,
    }

    return stmt
}


Return :: struct{
    keyword: Token,
    value  : ^Expr,
}

new_return :: proc(keyword: Token, value: ^Expr) -> ^Stmt {
    returns := new(Stmt)
    returns^ = Return{
        keyword=keyword,
        value=value,
    }

    return returns
}

Var :: struct{
    name       : Token,
    initializer: ^Expr,
}

new_var :: proc(name: Token, initializer: ^Expr) -> ^Stmt {
    var := new(Stmt)
    var^ = Var{
        name=name,
        initializer=initializer,
    }

    return var
}

While :: struct{
    condition: ^Expr,
    body     : ^Stmt,
}

new_while :: proc(condition: ^Expr, body: ^Stmt) -> ^Stmt {
    while := new(Stmt)
    while^ = While{
        condition=condition,
        body=body,
    }

    return while
}
