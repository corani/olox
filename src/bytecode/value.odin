package main

import "core:fmt"

Value :: distinct f64

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
    fmt.printf("%g", value)
}
