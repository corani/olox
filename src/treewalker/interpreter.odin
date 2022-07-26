package main 

import "core:strings"
import "core:fmt"

Interpreter :: struct {
    globals     : ^Environment,
    environment : ^Environment,
    locals      : map[int]int,
}

new_interpreter :: proc() -> ^Interpreter {
    interp := new(Interpreter)
    interp.globals     = new_environment()
    interp.environment = interp.globals

    // native functions:
    environment_define(interp.globals, Token{
        text = "clock",
        type = .Identifier,
    }, new_callable_clock())

    return interp
}

interpret :: proc(interp: ^Interpreter, stmts: []^Stmt) -> Result{
    for stmt in stmts {
        res := interpret_stmt(interp, stmt)
        switch in res {
        case OkResult:
            // continue
        case ErrorResult:
            return res
        case ReturnResult:
            return res
        }
    }

    return OkResult{}
}

interpret_stmt :: proc(interp: ^Interpreter, stmt: ^Stmt) -> Result {
    switch v in stmt {
    case Block:
        return interpret_block_stmt(interp, v)
    case Class:
        return interpret_class_stmt(interp, v)
    case Expression:
        return interpret_expression_stmt(interp, v)
    case Function:
        return interpret_function_stmt(interp, v)
    case If:
        return interpret_if_stmt(interp, v)
    case Print:
        return interpret_print_stmt(interp, v)
    case Return:
        return interpret_return_stmt(interp, v)
    case Var:
        return interpret_var_stmt(interp, v)
    case While:
        return interpret_while_stmt(interp, v)
    }

    return ErrorResult{text="unknown statement"}
}

interpret_print_stmt :: proc(interp: ^Interpreter, v: Print) -> Result {
    value := interpret_expr(interp, v.expression)

    fmt.println(interpret_stringify(value))

    return OkResult{}
}

interpret_class_stmt :: proc(interp: ^Interpreter, v: Class) -> Result {
    superclass: ^LoxClass

    if v.superclass != nil {
        super := interpret_variable_expr(interp, v.superclass^)

        #partial switch s in super {
        case Callable:
            #partial switch sc in s {
            case ^LoxClass:
                superclass = sc
            case:
                runtime_error(v.superclass.name, "Superclass must be a class.")
            }
        case:
            runtime_error(v.superclass.name, "Superclass must be a class.")
        }
    }

    enclosing := interp.environment
    environment_define(enclosing, v.name, nil)

    if superclass != nil {
        interp.environment = new_environment(enclosing)
        environment_define(interp.environment, Token{
            text = "super",
            type = .Identifier,
        }, superclass)
    }

    decl := new(Class)
    decl^ = v

    class := interpret_class(interp, decl, superclass)

    if superclass != nil {
        interp.environment = enclosing
    }

    environment_assign(interp.environment, v.name, class)

    return OkResult{}
}

interpret_class :: proc(interp: ^Interpreter, class: ^Class, super: ^LoxClass) -> Callable {
    methods: map[string]Callable

    for method in class.methods {
        fn := new_lox_function(method, interp.environment, method.name.text == "init")

        methods[method.name.text] = fn
    }

    return new_lox_class(class, super, methods)
}

interpret_expression_stmt :: proc(interp: ^Interpreter, v: Expression) -> Result {
    interpret_expr(interp, v.expression)

    return OkResult{}
}

interpret_function_stmt :: proc(interp: ^Interpreter, v: Function) -> Result {
    decl := new(Function)
    decl^ = v

    function := new_lox_function(decl, interp.environment, false)

    environment_define(interp.environment, v.name, Callable(function))

    return OkResult{}
}

interpret_return_stmt :: proc(interp: ^Interpreter, v: Return) -> Result {
    value: Value

    if v.value != nil {
        value = interpret_expr(interp, v.value)
    }

    return ReturnResult{
        value=value,
    }
}

interpret_if_stmt :: proc(interp: ^Interpreter, v: If) -> Result {
    condition := interpret_expr(interp, v.condition)

    if interpret_is_truthy(condition) {
        return interpret_stmt(interp, v.thenBranch)
    } else if v.elseBranch != nil {
        return interpret_stmt(interp, v.elseBranch)
    }

    return OkResult{}
}

interpret_while_stmt :: proc(interp: ^Interpreter, while: While) -> Result {
    for interpret_is_truthy(interpret_expr(interp, while.condition)) {
        res := interpret_stmt(interp, while.body)
        switch in res {
        case OkResult:
            // continue
        case ErrorResult:
            return res
        case ReturnResult:
            return res
        }
    }

    return OkResult{}
}

interpret_block_stmt :: proc(interp: ^Interpreter, v: Block) -> Result {
    environment := new_environment(interp.environment)
    defer environment_delete(environment)

    return interpret_block(interp, v.statements[:], environment)
}

interpret_block :: proc(interp: ^Interpreter, body: []^Stmt, environment: ^Environment) -> Result {
    previous := interp.environment

    interp.environment = environment
    res := interpret(interp, body)
    interp.environment = previous

    return res
}

interpret_var_stmt :: proc(interp: ^Interpreter, v: Var) -> Result {
    value : Value = Nil{}

    if v.initializer != nil {
        value = interpret_expr(interp, v.initializer)
    }

    environment_define(interp.environment, v.name, value)

    return OkResult{}
}

interpret_expr :: proc(interp: ^Interpreter, expr: ^Expr) -> Value {
    switch v in expr {
    case Assign:
        return interpret_assign_expr(interp, v)
    case Binary:
        return interpret_binary_expr(interp, v)
    case Call:
        return interpret_call_expr(interp, v)
    case Get:
        return interpret_get_expr(interp, v)
    case Grouping:
        return interpret_expr(interp, v.expression)
    case Literal:
        return v.value.value
    case Logical:
        return interpret_logical_expr(interp, v)
    case Set:
        return interpret_set_expr(interp, v)
    case Super:
        return interpret_super_expr(interp, v)
    case This:
        return interpret_lookup_variable(interp, v.keyword, -1)
    case Unary:
        return interpret_unary_expr(interp, v)
    case Variable:
        return interpret_variable_expr(interp, v)
    }

    return Nil{}
}

interpret_assign_expr :: proc(interp: ^Interpreter, v: Assign) -> Value {
    value := interpret_expr(interp, v.value)

    if depth, ok := interp.locals[v.id]; ok {
        environment_assign_at(interp.environment, v.name, depth, value)
    } else {
        environment_assign(interp.globals, v.name, value)
    }

    return value
}

interpret_unary_expr :: proc(interp: ^Interpreter, v: Unary) -> Value {
    right := interpret_expr(interp, v.right)

    #partial switch v.operator.type {
    case .Minus:
        return -interpret_assert_number(v.operator, right)
    case .Bang:
        return !interpret_is_truthy(right)
    }

    // TODO: unreachable
    return Nil{}
}

interpret_binary_expr :: proc(interp: ^Interpreter, v: Binary) -> Value {
    left := interpret_expr(interp, v.left)
    right := interpret_expr(interp, v.right)

    #partial switch v.operator.type {
    case .Greater:
        l, r := interpret_assert_numbers(v.operator, left, right)

        return l > r
    case .GreaterEqual:
        l, r := interpret_assert_numbers(v.operator, left, right)

        return l >= r
    case .Less:
        l, r := interpret_assert_numbers(v.operator, left, right)

        return l < r
    case .LessEqual:
        l, r := interpret_assert_numbers(v.operator, left, right)

        return l <= r
    case .BangEqual:
        return !interpret_is_equal(left, right)
    case .EqualEqual:
        return interpret_is_equal(left, right)
    case .Minus:
        l, r := interpret_assert_numbers(v.operator, left, right)

        return l - r
    case .Plus:
        #partial switch in left {
        case Number:
            l, r := interpret_assert_numbers(v.operator, left, right)

            return l + r
        case String:
            #partial switch in right {
            case String:
                return strings.concatenate([]string{
                    left.(String), right.(String),
                })
            }

            runtime_error(v.operator, "Operands must be two strings.")

            return ""
        }

        runtime_error(v.operator, "Operands must be two numbers or two strings.")

        return Nil{}
    case .Slash:
        l, r := interpret_assert_numbers(v.operator, left, right)

        return l / r
    case .Star:
        l, r := interpret_assert_numbers(v.operator, left, right)

        return l * r
    }

    return Nil{}
}

interpret_call_expr :: proc(interp: ^Interpreter, call: Call) -> Value {
    callee := interpret_expr(interp, call.callee)

    arguments: [dynamic]Value
    for argument in call.arguments {
        append(&arguments, interpret_expr(interp, argument))
    }
    defer delete(arguments)

    return callable_call(interp, call.paren, callee, arguments[:])
}

interpret_get_expr :: proc(interp: ^Interpreter, get: Get) -> Value {
    object := interpret_expr(interp, get.object)
    value  := Value(Nil{}) 

    #partial switch instance in object {
    case ^Instance:
        value = instance_get(instance, get.name)
    case:
        runtime_error(get.name, "Only instances have properties.")
    }

    return value
}

interpret_set_expr :: proc(interp: ^Interpreter, set: Set) -> Value {
    object := interpret_expr(interp, set.object)
    value  := interpret_expr(interp, set.value)

    #partial switch instance in object {
    case ^Instance:
        instance_set(instance, set.name, value)
    case:
        runtime_error(set.name, "Only instances have fields.")
    }

    return value
}

interpret_super_expr :: proc(interp: ^Interpreter, super: Super) -> Value {
    depth := interp.locals[super.id]

    superclass : ^LoxClass
    object     : ^Instance

    #partial switch v in environment_get_at(interp.environment, super.keyword, depth) {
    case ^LoxClass:
        superclass = v
    case:
        return Nil{}
    }

    #partial switch v in environment_get_at(interp.environment, Token{
        type = .Identifier,
        text = "this",
    }, depth-1) {
    case ^Instance:
        object = v
    case:
        return Nil{}
    }

    method, ok := class_find_method(superclass, super.method)
    if !ok {
        runtime_error(super.method, fmt.tprintf("Undefiend property `%s`.", super.method.text))

        return Nil{}
    }

    return callable_bind(method, object)
}

interpret_variable_expr :: proc(interp: ^Interpreter, v: Variable) -> Value {
    return interpret_lookup_variable(interp, v.name, v.id)
}

interpret_logical_expr :: proc(interp: ^Interpreter, v: Logical) -> Value {
    left := interpret_expr(interp, v.left)

    if v.operator.type == TokenType.Or {
        if interpret_is_truthy(left) {
            return left
        }
    } else {
        if !interpret_is_truthy(left) {
            return left
        }
    }

    return interpret_expr(interp, v.right)
}

interpret_resolve :: proc(interp: ^Interpreter, expr: ^Expr, depth: int) {
    #partial switch v in expr {
    case Assign:
        interp.locals[v.id] = depth
    case Variable:
        interp.locals[v.id] = depth
    case This:
        interp.locals[v.id] = depth
    case Super:
        interp.locals[v.id] = depth
    case:
        fmt.println("interpret_resolve: try to resolve", expr)
    }
}

interpret_lookup_variable :: proc(interp: ^Interpreter, name: Token, id: int) -> Value{
    if id >= 0 {
        depth, ok := interp.locals[id]
        if ok {
            return environment_get_at(interp.environment, name, depth)
        }
    }

    return environment_get(interp.environment, name)
}

interpret_is_equal :: proc(left, right: Value) -> bool {
    switch l in left {
    case Number:
        #partial switch r in right {
        case Number:
            return l == r
        }
    case Boolean:
        #partial switch r in right {
        case Boolean:
            return l == r
        }
    case String:
        #partial switch r in right {
        case String:
            return l == r
        }
    case Nil:
        #partial switch r in right {
        case Nil:
            return true
        }
    case Callable:
        // TODO(daniel): implementation
    case ^LoxClass:
        // TODO(daniel): implementation
    case ^Instance:
        // TODO(daniel): implementation
    }

    return false
}

interpret_assert_number :: proc(token: Token, operand: Value) -> Number {
    if v, ok := operand.(Number); ok {
        return v
    }

    runtime_error(token, "Operand must be a number.")

    return 0
}

interpret_assert_numbers :: proc(token: Token, left, right: Value) -> (Number, Number) {
    l, ok1 := left.(Number)
    r, ok2 := right.(Number)

    if ok1 && ok2 {
        return l, r
    }

    runtime_error(token, "Operands must be numbers.")

    return 0, 0
}

interpret_is_truthy :: proc(value: Value) -> bool {
    #partial switch val in value {
    case Boolean:
        return val
    case Nil:
        return false
    }
   
    return true
}

interpret_stringify :: proc(value: Value) -> string {
    switch v in value {
    case String:
        return v
    case Number:
        return fmt.tprint(v)
    case Boolean:
        return fmt.tprint(v)
    case Nil:
        return "<nil>"
    case Callable:
        return callable_get_name(v)
    case ^LoxClass:
        return v.name
    case ^Instance:
        return v.name
    }

    return "<invalid>"
}
