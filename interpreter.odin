package main 

import "core:strings"
import "core:fmt"

Interpreter :: struct {
    environment: ^Environment,
}

new_interpreter :: proc() -> ^Interpreter {
    interp := new(Interpreter)
    interp.environment = new_environment()

    return interp
}

interpret :: proc(interp: ^Interpreter, stmts: []^Stmt) {
    for stmt in stmts {
        interpret_stmt(interp, stmt)
    }
}

interpret_stmt :: proc(interp: ^Interpreter, stmt: ^Stmt) -> Void {
    switch v in stmt {
    case Block:
        return interpret_block_stmt(interp, v)
    case Class:
    case Expression:
        return interpret_expression_stmt(interp, v)
    case Function:
    case If:
        return interpret_if_stmt(interp, v)
    case Print:
        return interpret_print_stmt(interp, v)
    case Return:
    case Var:
        return interpret_var_stmt(interp, v)
    case While:
    }

    return Void{}
}

interpret_print_stmt :: proc(interp: ^Interpreter, v: Print) -> Void {
    value := interpret_expr(interp, v.expression)

    fmt.println(interpret_stringify(value))

    return Void{}
}

interpret_expression_stmt :: proc(interp: ^Interpreter, v: Expression) -> Void {
    interpret_expr(interp, v.expression)

    return Void{}
}

interpret_if_stmt :: proc(interp: ^Interpreter, v: If) -> Void {
    condition := interpret_expr(interp, v.condition)
    if interpret_is_truthy(condition) {
        interpret_stmt(interp, v.thenBranch)
    } else if v.elseBranch != nil {
        interpret_stmt(interp, v.elseBranch)
    }

    return Void{}
}

interpret_block_stmt :: proc(interp: ^Interpreter, v: Block) -> Void {
    previous := interp.environment

    interp.environment = new_environment(previous)
    {
        interpret(interp, v.statements[:])
    }
    interp.environment = previous

    return Void{}
}

interpret_var_stmt :: proc(interp: ^Interpreter, v: Var) -> Void {
    value : Value = Nil{}

    if v.initializer != nil {
        value = interpret_expr(interp, v.initializer)
    }

    environment_define(interp.environment, v.name, value)

    return Void{}
}

interpret_expr :: proc(interp: ^Interpreter, expr: ^Expr) -> Value {
    switch v in expr {
    case Assign:
        return interpret_assign_expr(interp, v)
    case Binary:
        return interpret_binary_expr(interp, v)
    case Call:
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

    environment_assign(interp.environment, v.name, value)

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
            if type_of(right) != String {
                runtime_error(v.operator, "Operands must be two strings.")

                return ""
            }

            return strings.concatenate([]string{
                left.(String), right.(String),
            })
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

interpret_variable_expr :: proc(interp: ^Interpreter, v: Variable) -> Value {
    return environment_get(interp.environment, v.name)
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
    }

    return "<invalid>"
}
