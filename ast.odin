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

Assign :: struct{
    name : Token,
    value: ^Expr,
    id: int,
}

new_assign :: proc(name: Token, value: ^Expr) -> ^Expr {
    assign := new(Expr)
    assign^ = Assign{
        name=name,
        value=value,
        id=new_ast_id(),
    }

    return assign
}

Binary :: struct{
    left    : ^Expr,
    operator: Token,
    right   : ^Expr,
    id: int,
}

new_binary :: proc(left: ^Expr, operator: Token, right: ^Expr) -> ^Expr {
    binary := new(Expr)
    binary^ = Binary{
        left=left,
        operator=operator,
        right=right,
        id=new_ast_id(),
    }

    return binary
}

Call :: struct{
    callee   : ^Expr,
    paren    : Token,
    arguments: [dynamic]^Expr,
    id: int,
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
        id=new_ast_id(),
    }

    return call
}

Get :: struct{
    object: ^Expr,
    name  : Token,
    id: int,
}

new_get :: proc(object: ^Expr, name: Token) -> ^Expr {
    get := new(Expr)
    get^ = Get{
        object=object,
        name=name,
        id=new_ast_id(),
    }

    return get
}

Grouping :: struct{
    expression: ^Expr,
    id: int,
}

new_grouping :: proc(expr: ^Expr) -> ^Expr {
    grouping := new(Expr)
    grouping^ = Grouping{
        expression=expr,
        id=new_ast_id(),
    }

    return grouping
}

Literal :: struct{
    value: Token,
    id: int,
}

new_literal :: proc(value: Token) -> ^Expr {
    literal := new(Expr)
    literal^ = Literal{
        value=value,
        id=new_ast_id(),
    }

    return literal
}

Logical :: struct{
    left    : ^Expr,
    operator: Token,
    right   : ^Expr,
    id: int,
}

new_logical :: proc(left: ^Expr, operator: Token, right: ^Expr) -> ^Expr {
    logical := new(Expr)
    logical^ = Logical{
        left=left,
        operator=operator,
        right=right,
        id=new_ast_id(),
    }

    return logical
}

Set :: struct{
    object: ^Expr,
    name  : Token,
    value : ^Expr,
    id: int,
}

new_set :: proc(object: ^Expr, name: Token, value: ^Expr) -> ^Expr {
    set := new(Expr)
    set^ = Set{
        object=object,
        name=name,
        value=value,
        id=new_ast_id(),
    }

    return set
}

Super :: struct{
    keyword: Token,
    method : Token,
    id: int,
}

new_super :: proc(keyword: Token, method: Token) -> ^Expr {
    super := new(Expr)
    super^ = Super{
        keyword=keyword,
        method=method,
        id=new_ast_id(),
    }

    return super
}

This :: struct{
    keyword: Token,
    id: int,
}

new_this :: proc(keyword: Token) -> ^Expr {
    this := new(Expr)
    this^ = This{
        keyword=keyword,
        id=new_ast_id(),
    }

    return this
}

Unary :: struct{
    operator: Token,
    right   : ^Expr,
    id: int,
}

new_unary :: proc(operator: Token, right: ^Expr) -> ^Expr {
    unary := new(Expr)
    unary^ = Unary{
        operator=operator,
        right=right,
        id=new_ast_id(),
    }

    return unary
}

Variable :: struct{
    name: Token,
    id: int,
}

new_variable :: proc(name: Token) -> ^Expr {
    variable := new(Expr)
    variable^ = Variable{
        name=name,
        id=new_ast_id(),
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
    id: int,
}

new_block :: proc(statements: []^Stmt) -> ^Stmt {
    stmts: [dynamic]^Stmt

    for stmt in statements {
        append(&stmts, stmt)
    }

    block := new(Stmt)
    block^ = Block{
        statements=stmts,
        id=new_ast_id(),
    }

    return block
}

Class :: struct{
    name      : Token,
    superclass: Variable,
    methods   : [dynamic]Function,
    id: int,
}

new_class :: proc(name: Token, superclass: Variable, methods: []Function) -> ^Stmt {
    _methods: [dynamic]Function

    for m in methods {
        append(&_methods, m)
    }

    class := new(Stmt)
    class^ = Class{
        name=name,
        superclass=superclass,
        methods=_methods,
        id=new_ast_id(),
    }

    return class
}

Expression :: struct{
    expression: ^Expr,
    id: int,
}

new_expression :: proc(expression: ^Expr) -> ^Stmt {
    stmt := new(Stmt)
    stmt^ = Expression{
        expression=expression,
        id=new_ast_id(),
    }

    return stmt
}

Function :: struct{
    name  : Token,
    params: [dynamic]Token,
    body  : [dynamic]^Stmt,
    id: int,
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
        id=new_ast_id(),
    }

    return function
}

If :: struct{
    condition : ^Expr,
    thenBranch: ^Stmt,
    elseBranch: ^Stmt,
    id: int,
}

new_if :: proc(condition: ^Expr, thenBranch: ^Stmt, elseBranch: ^Stmt) -> ^Stmt {
    ifs := new(Stmt)
    ifs^ = If{
        condition=condition,
        thenBranch=thenBranch,
        elseBranch=elseBranch,
        id=new_ast_id(),
    }

    return ifs
}

Print :: struct{
    expression: ^Expr,
    id: int,
}

new_print :: proc(expression: ^Expr) -> ^Stmt {
    stmt := new(Stmt)
    stmt^ = Print{
        expression=expression,
        id=new_ast_id(),
    }

    return stmt
}


Return :: struct{
    keyword: Token,
    value  : ^Expr,
    id: int,
}

new_return :: proc(keyword: Token, value: ^Expr) -> ^Stmt {
    returns := new(Stmt)
    returns^ = Return{
        keyword=keyword,
        value=value,
        id=new_ast_id(),
    }

    return returns
}

Var :: struct{
    name       : Token,
    initializer: ^Expr,
    id: int,
}

new_var :: proc(name: Token, initializer: ^Expr) -> ^Stmt {
    var := new(Stmt)
    var^ = Var{
        name=name,
        initializer=initializer,
        id=new_ast_id(),
    }

    return var
}

While :: struct{
    condition: ^Expr,
    body     : ^Stmt,
    id: int,
}

new_while :: proc(condition: ^Expr, body: ^Stmt) -> ^Stmt {
    while := new(Stmt)
    while^ = While{
        condition=condition,
        body=body,
        id=new_ast_id(),
    }

    return while
}
