package main

import "core:fmt"

Nil :: struct{}

//Value :: distinct f64
Value :: union{
    bool,
    f64,
    Nil,
}

ValueArray :: struct {
    values: [dynamic]Value,
}

value_array_init :: proc(array: ^ValueArray) {
    // nothing, for now
}

value_array_append :: proc(array: ^ValueArray, value: Value) -> int {
    append(&array.values, value)

    return len(array.values)-1
}

value_array_free :: proc(array: ^ValueArray) {
    delete(array.values)
    value_array_init(array)
}

value_print :: proc(value: Value) {
    switch v in value {
    case bool:
        fmt.printf("%v", v)
    case f64:
        fmt.printf("%v", v)
    case Nil:
        fmt.print("<nil>")
    }
}

value_equal :: proc(va, vb: Value) -> bool {
    switch a in va {
    case bool:
        switch b in vb {
        case bool:
            return a == b
        case f64:
            return false
        case Nil:
            return false
        }
    case f64:
        switch b in vb {
        case bool:
            return false
        case f64:
            return a == b
        case Nil:
            return false
        }
    case Nil:
        switch b in vb {
        case bool:
            return false
        case f64:
            return false
        case Nil:
            return true
        }
    }

    panic("unreachable")
}
