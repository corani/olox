package main 

import "core:strings"
import "core:fmt"

Interpreter :: struct {
    globals: ^Environment,
    environment: ^Environment,
    locals: map[int]int,
}

new_interpreter :: proc() -> ^Interpreter {
    interp := new(Interpreter)
    interp.globals = new_environment()
    interp.environment = interp.globals

    environment_define(interp.globals, Token{text="clock"}, new_callable_clock())

    return interp
}

interpret :: proc(interp: ^Interpreter, stmts: []^Stmt) -> Result{
    for stmt in stmts {
        res := interpret_stmt(interp, stmt)
        switch in res {
        case OkResult:
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
    decl := new(Class)
    decl^ = v

    environment_define(interp.environment, v.name, nil)

    class := new_callable_class(decl)

    environment_assign(interp.environment, v.name, class)

    return OkResult{}
}

interpret_expression_stmt :: proc(interp: ^Interpreter, v: Expression) -> Result {
    interpret_expr(interp, v.expression)

    return OkResult{}
}

interpret_function_stmt :: proc(interp: ^Interpreter, v: Function) -> Result {
    decl := new(Function)
    decl^ = v

    function := new_callable_function(decl, interp.environment)

    environment_define(interp.environment, v.name, function)

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
        case ErrorResult:
            return res
        case ReturnResult:
            return res
        }
    }

    return OkResult{}
}

interpret_block_stmt :: proc(interp: ^Interpreter, v: Block) -> Result {
    return interpret_block(interp, v.statements[:], new_environment(interp.environment))
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
    case Grouping:
        return interpret_expr(interp, v.expression)
    case Literal:
        return v.value.value
    case Logical:
        return interpret_logical_expr(interp, v)
    case Set:
    case Super:
    case This:
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
    case TokenType.Minus:
        return -interpret_assert_number(v.operator, right)
    case TokenType.Bang:
        return !interpret_is_truthy(right)
    }

    // TODO: unreachable
    return Nil{}
}

interpret_binary_expr :: proc(interp: ^Interpreter, v: Binary) -> Value {
    left := interpret_expr(interp, v.left)
    right := interpret_expr(interp, v.right)

    #partial switch v.operator.type {
    case TokenType.Greater:
        l, r := interpret_assert_numbers(v.operator, left, right)

        return l > r
    case TokenType.GreaterEqual:
        l, r := interpret_assert_numbers(v.operator, left, right)

        return l >= r
    case TokenType.Less:
        l, r := interpret_assert_numbers(v.operator, left, right)

        return l < r
    case TokenType.LessEqual:
        l, r := interpret_assert_numbers(v.operator, left, right)

        return l <= r
    case TokenType.BangEqual:
        return !interpret_is_equal(left, right)
    case TokenType.EqualEqual:
        return interpret_is_equal(left, right)
    case TokenType.Minus:
        l, r := interpret_assert_numbers(v.operator, left, right)

        return l - r
    case TokenType.Plus:
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
    case TokenType.Slash:
        l, r := interpret_assert_numbers(v.operator, left, right)

        return l / r
    case TokenType.Star:
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

    return callable_call(interp, call.paren, callee, arguments[:])
}

interpret_variable_expr :: proc(interp: ^Interpreter, v: Variable) -> Value {
    // TODO(daniel): there's got to be a better way. Casting doesn't work...
    expr := new(Expr)
    expr^ = v

    return interpret_lookup_variable(interp, v.name, expr)
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
    }
}

interpret_lookup_variable :: proc(interp: ^Interpreter, name: Token, expr: ^Expr) -> Value{
    id := -1

    #partial switch v in expr {
    case Assign:
        id = v.id
    case Variable:
        id = v.id
    }

    if id >= 0 {
        depth, ok := interp.locals[id]
        if ok {
            return environment_get_at(interp.environment, name, depth)
        }
    }

    return environment_get(interp.globals, name)
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
        #partial switch r in right {
        case Callable:
            return l.native == r.native
        }
    case LoxClass:
        // TODO(daniel): implementation
    case Instance:
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
        return fmt.tprintf("<fn %s>", v.name)
    case LoxClass:
        return fmt.tprintf("<class %s>", v.name)
    case Instance:
        return fmt.tprintf("<instance %s>", v.class.name.text)
    }

    return "<invalid>"
}
