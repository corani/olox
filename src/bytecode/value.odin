package main

import "core:fmt"

Nil :: struct{}

// TODO(daniel): instead of type punning, should we use another union?
ObjType :: enum {
    String,
}

Obj :: struct{
    type: ObjType,
    next: ^Obj,
}

ObjString :: struct{
    using obj : Obj,
    chars     : string,
}

Value :: union{
    bool,
    f64,
    Nil,
    ^Obj,
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
    case ^Obj:
        value_print_object(v)
    }
}

value_print_object :: proc(value: ^Obj) {
    switch value.type {
    case .String:
        str := cast(^ObjString) value

        fmt.printf("\"%s\"", str.chars)
    case:
        panic("unreachable")
    }
}

value_equal :: proc(va, vb: Value) -> bool {
    switch a in va {
    case bool:
        #partial switch b in vb {
        case bool:
            return a == b
        case:
            return false
        }
    case f64:
        #partial switch b in vb {
        case f64:
            return a == b
        case:
            return false
        }
    case Nil:
        #partial switch b in vb {
        case Nil:
            return true
        case:
            return false
        }
    case ^Obj:
        #partial switch b in vb {
        case ^Obj:
            return value_equal_obj(a, b)
        case:
            return false
        }
    }

    panic("unreachable")
}

value_equal_obj :: proc(a, b: ^Obj) -> bool {
    if a.type != b.type {
        return false
    }

    switch a.type {
    case .String:
        stra := cast(^ObjString) a
        strb := cast(^ObjString) b

        // TODO(daniel): should we intern strings to speed up comparisons?
        return stra.chars == strb.chars
    case:
        panic("unreachable")
    }
}

// TODO(daniel): does this need to be allocated through vm_allocate_string so that it
// gets freed? Or is it okay to leak these?
value_new_string :: proc(v: string) -> Value {
    obj := new(ObjString)
    obj.type  = .String
    obj.chars = v

    return cast(^Obj) obj
}

value_is_string :: proc(v: Value) -> bool {
    if obj, ok := v.(^Obj); ok {
        return obj.type == .String
    }

    return false
}

value_as_string :: proc(v: Value) -> string {
    return (cast(^ObjString) v.(^Obj)).chars
}

value_new_number :: proc(v: f64) -> Value {
    return v
}

value_is_number :: proc(v: Value) -> bool {
    _, ok := v.(f64)
    return ok
}

value_as_number :: proc(v: Value) -> f64 {
    return v.(f64)
}

value_is_falsey :: proc(value: Value) -> bool {
    switch v in value {
    case f64:
        return false
    case bool:
        return !v
    case Nil:
        return true
    case ^Obj:
        switch v.type {
        case .String:
            return false
        case:
            panic("unreachable")
        }
    case:
        panic("unreachable")
    }
}

object_free :: proc(object: ^Obj) {
    switch object.type {
    case .String:
        free(cast(^ObjString) object)
    case:
        panic("unreachable")
    }
}
