package main

import "core:strings"

print_expr :: proc(expr: ^Expr) -> string {
    parts := [dynamic]string{}

    switch v in expr {
    case Assign  :
        append(&parts, "(assign ")
        append(&parts, v.name.text)
        append(&parts, " ")
        append(&parts, print_expr(v.value))
        append(&parts, ")")
    case Binary  : 
        append(&parts, "(")
        append(&parts, v.operator.text)
        append(&parts, " ")
        append(&parts, print_expr(v.left))
        append(&parts, " ")
        append(&parts, print_expr(v.right))
        append(&parts, ")")
    case Call    :
        append(&parts, "(call ")
        append(&parts, print_expr(v.callee))
        for arg in v.arguments {
            append(&parts, " ")
            append(&parts, print_expr(arg))
        }
        append(&parts, ")")
    case Get     :
        append(&parts, "(get ")
        append(&parts, print_expr(v.object))
        append(&parts, " ")
        append(&parts, v.name.text)
        append(&parts, ")")
    case Grouping:
        append(&parts, "(group ")    
        append(&parts, print_expr(v.expression))
        append(&parts, ")")
    case Literal :
        append(&parts, v.value.text)
    case Logical :
        append(&parts, "(")
        append(&parts, v.operator.text)
        append(&parts, " ")
        append(&parts, print_expr(v.left))
        append(&parts, " ")
        append(&parts, print_expr(v.right))
        append(&parts, ")")
    case Set     :
        append(&parts, "(set ")
        append(&parts, print_expr(v.object))
        append(&parts, " ")
        append(&parts, v.name.text)
        append(&parts, " ")
        append(&parts, print_expr(v.value))
        append(&parts, ")")
    case Super   :
        append(&parts, "(super ")
        append(&parts, v.keyword.text)
        append(&parts, " ")
        append(&parts, v.method.text)
        append(&parts, ")")
    case This    :
        append(&parts, "(this ")
        append(&parts, v.keyword.text)
        append(&parts, ")")
    case Unary   :
        append(&parts, "(")
        append(&parts, v.operator.text)
        append(&parts, " ")
        append(&parts, print_expr(v.right))
        append(&parts, ")")
    case Variable:
        append(&parts, "(variable ")
        append(&parts, v.name.text)
        append(&parts, ")")
    }

    return strings.concatenate(parts[:])
}
