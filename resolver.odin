package main 

import "core:fmt"
import "core:container/queue"

Resolver :: struct{
    interp: ^Interpreter,
    scopes: queue.Queue(map[string]bool),
    currentFunction: FunctionType,
    currentClass: ClassType,
}

new_resolver :: proc(interp: ^Interpreter) -> ^Resolver {
    resolver := new(Resolver)
    resolver.interp = interp
    resolver.currentFunction = FunctionType.None
    resolver.currentClass = ClassType.None
    queue.init(&resolver.scopes)

    return resolver
}

resolve :: proc(resolver: ^Resolver, stmts: []^Stmt) {
    for stmt in stmts {
        resolve_stmt(resolver, stmt)
    }
}

resolve_stmt :: proc(resolver: ^Resolver, stmt: ^Stmt) {
    switch v in stmt {
    case Block:
        resolve_block_stmt(resolver, v)
    case Class:
        resolve_class_stmt(resolver, v)
    case Expression:
        resolve_expr(resolver, v.expression)
    case Function:
        resolve_function_stmt(resolver, v)
    case If:
        resolve_if_stmt(resolver, v)
    case Print:
        resolve_expr(resolver, v.expression)
    case Return:
        resolve_return_stmt(resolver, v)
    case Var:
        resolve_var_stmt(resolver, v)
    case While:
        resolve_while_stmt(resolver, v)
    }
}

resolve_block_stmt :: proc(resolver: ^Resolver, block: Block) {
    resolve_begin_scope(resolver)
    resolve(resolver, block.statements[:])
    resolve_end_scope(resolver)
}

resolve_class_stmt :: proc(resolver: ^Resolver, class: Class) {
    enclosingClass := resolver.currentClass
    resolver.currentClass = ClassType.Class

    resolve_declare(resolver, class.name)
    resolve_define(resolver, class.name)

    resolve_begin_scope(resolver)
    resolve_define(resolver, Token{
        type=TokenType.This,
        line=class.name.line,
        text="this",
    })

    for method in class.methods {
        resolve_function(resolver, method, FunctionType.Method)
    }

    resolve_end_scope(resolver)

    resolver.currentClass = enclosingClass
}

resolve_function_stmt :: proc(resolver: ^Resolver, function: Function) {
    resolve_declare(resolver, function.name)
    resolve_define(resolver, function.name)

    fn := new(Function)
    fn^ = function

    resolve_function(resolver, fn, FunctionType.Function)
}

resolve_function :: proc(resolver: ^Resolver, function: ^Function, type: FunctionType) {
    enclosingFunction := resolver.currentFunction
    resolver.currentFunction = type

    resolve_begin_scope(resolver)
    {
        for param in function.params {
            resolve_declare(resolver, param)
            resolve_define(resolver, param)
        }

        resolve(resolver, function.body[:])
    }
    resolve_end_scope(resolver)

    resolver.currentFunction = enclosingFunction
}

resolve_return_stmt :: proc(resolver: ^Resolver, stmt: Return) {
    if resolver.currentFunction == FunctionType.None {
        error(stmt.keyword, "Can't return from top-level code.")
    }

    if stmt.value != nil {
        resolve_expr(resolver, stmt.value)
    }
}

resolve_if_stmt :: proc(resolver: ^Resolver, stmt: If) {
    resolve_expr(resolver, stmt.condition)
    resolve_stmt(resolver, stmt.thenBranch)
    if stmt.elseBranch != nil {
        resolve_stmt(resolver, stmt.elseBranch)
    }
}

resolve_var_stmt :: proc(resolver: ^Resolver, stmt: Var) {
    resolve_declare(resolver, stmt.name)
    if stmt.initializer != nil {
        resolve_expr(resolver, stmt.initializer)
    }
    resolve_define(resolver, stmt.name)
}

resolve_while_stmt :: proc(resolver: ^Resolver, while: While) {
    resolve_expr(resolver, while.condition)
    resolve_stmt(resolver, while.body)
}

resolve_expr :: proc(resolver: ^Resolver, expr: ^Expr) {
    switch v in expr {
    case Assign:
        resolve_assign_expr(resolver, v)
    case Binary:
        resolve_binary_expr(resolver, v)
    case Call:
        resolve_call_expr(resolver, v)
    case Get:
        resolve_get_expr(resolver, v)
    case Grouping:
        resolve_expr(resolver, v.expression)
    case Literal:
    case Logical:
        resolve_logical_expr(resolver, v)
    case Set:
        resolve_set_expr(resolver, v)
    case Super:
    case This:
        resolve_this_expr(resolver, v)
    case Unary:
        resolve_expr(resolver, v.right)
    case Variable:
        resolve_variable_expr(resolver, v)
    }
}

resolve_this_expr :: proc(resolver: ^Resolver, this: This) {
    if resolver.currentClass == ClassType.None {
        error(this.keyword, "Can't use `this` outside of a class.")
        return
    }

    expr := new(Expr)
    expr^ = this

    resolve_local(resolver, expr, this.keyword)
}

resolve_assign_expr :: proc(resolver: ^Resolver, assign: Assign) {
    resolve_expr(resolver, assign.value)

    expr := new(Expr)
    expr^ = assign

    resolve_local(resolver, expr, assign.name)
}

resolve_binary_expr :: proc(resolver: ^Resolver, expr: Binary) {
    resolve_expr(resolver, expr.left)
    resolve_expr(resolver, expr.right)
}

resolve_call_expr :: proc(resolver: ^Resolver, call: Call) {
    resolve_expr(resolver, call.callee)

    for argument in call.arguments {
        resolve_expr(resolver, argument)
    }
}

resolve_get_expr :: proc(resolver: ^Resolver, get: Get) {
    resolve_expr(resolver, get.object)
}

resolve_set_expr :: proc(resolver: ^Resolver, set: Set) {
    resolve_expr(resolver, set.value)
    resolve_expr(resolver, set.object)
}

resolve_logical_expr :: proc(resolver: ^Resolver, expr: Logical) {
    resolve_expr(resolver, expr.left)
    resolve_expr(resolver, expr.right)
}

resolve_variable_expr :: proc(resolver: ^Resolver, var: Variable) {
    if queue.len(resolver.scopes) > 0 {
        scope := queue.back(&resolver.scopes)

        if v, ok := scope[var.name.text]; ok && !v {
            error(var.name, "Can't read local variable in its own initializer.")
        }
    }

    expr := new(Expr)
    expr^ = var

    resolve_local(resolver, expr, var.name)
}

resolve_begin_scope :: proc(resolver: ^Resolver) {
    queue.push_back(&resolver.scopes, map[string]bool{})
}

resolve_end_scope :: proc(resolver: ^Resolver) {
    queue.pop_back(&resolver.scopes)
}

resolve_declare :: proc(resolver: ^Resolver, name: Token) {
    if queue.len(resolver.scopes) == 0 {
        return
    }

    scope := queue.pop_back(&resolver.scopes)
    if _, ok := scope[name.text]; ok {
        error(name, "Already a variable with this name in this scope.")
    } else {
        scope[name.text] = false
    }

    queue.push_back(&resolver.scopes, scope)
}

resolve_define :: proc(resolver: ^Resolver, name: Token) {
    if queue.len(resolver.scopes) == 0 {
        return
    }

    scope := queue.pop_back(&resolver.scopes)
    scope[name.text] = true
    queue.push_back(&resolver.scopes, scope)
}

resolve_local :: proc(resolver: ^Resolver, expr: ^Expr, name: Token) {
    for i := queue.len(resolver.scopes)-1; i >= 0; i -= 1 {
        scope := queue.get(&resolver.scopes, i)

        if _, ok := scope[name.text]; ok {
            interpret_resolve(resolver.interp, expr, queue.len(resolver.scopes)-1-i)
            return
        }
    }
}
