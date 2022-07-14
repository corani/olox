package main 

import "core:strings"
import "core:fmt"

interpret :: proc(expr: ^Expr) -> string{
    value := interpret_expr(expr)
    return interpret_stringify(value)
}

interpret_expr :: proc(expr: ^Expr) -> Value {
    switch v in expr {
    case Assign:
    case Binary:
        return interpret_binary_expr(v)
    case Call:
    case Get:
    case Grouping:
        return interpret_expr(v.expression)
    case Literal:
        return v.value.value
    case Logical:
    case Set:
    case Super:
    case This:
    case Unary:
        return interpret_unary_expr(v)
    case Variable:
    }

    return Nil{}
}

interpret_unary_expr :: proc(v: Unary) -> Value {
    right := interpret_expr(v.right)

    #partial switch v.operator.type {
    case TokenType.Minus:
        return -interpret_assert_number(v.operator, right)
    case TokenType.Bang:
        #partial switch val in right {
        case Boolean:
                return !val
        case Nil:
                return true
        }
    }

    // TODO: unreachable
    return Nil{}
}

interpret_binary_expr :: proc(v: Binary) -> Value {
    left := interpret_expr(v.left)
    right := interpret_expr(v.right)

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
