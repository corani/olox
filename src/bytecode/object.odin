package main 

import "core:fmt"

// TODO(daniel): instead of type punning, should we use another union?
ObjType :: enum {
    String,
    Function,
    Closure,
    Native,
}

Obj :: struct{
    type: ObjType,
    next: ^Obj,
}

// ---- STRING ----------------------------------------------------------------

ObjString :: struct{
    using obj : Obj,
    chars     : string,
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
    return value_is_object_type(v, .String)
}

value_as_string :: proc(v: Value) -> ^ObjString {
    return cast(^ObjString) v.(^Obj)
}

// ---- FUNCTION --------------------------------------------------------------

ObjFunction :: struct{
    using obj : Obj,
    arity     : int,
    chunk     : ^Chunk,
    name      : string 
}

// TODO(daniel): does this need to be freed?
value_new_function :: proc(name: string) -> ^ObjFunction {
    obj := new(ObjFunction)
    obj.type  = .Function
    obj.name  = name
    obj.chunk = new(Chunk)

    chunk_init(obj.chunk)

    return obj
}

value_is_function :: proc(v: Value) -> bool {
    return value_is_object_type(v, .Function)
}

value_as_function :: proc(v: Value) -> ^ObjFunction {
    return cast(^ObjFunction) v.(^Obj)
}

// ---- CLOSURE ---------------------------------------------------------------

ObjClosure :: struct{
    using obj : Obj,
    function  : ^ObjFunction,
}

// TODO(daniel): does this need to be freed?
value_new_closure :: proc(function: ^ObjFunction) -> ^ObjClosure {
    obj := new(ObjClosure)
    obj.type     = .Closure
    obj.function = function

    return obj
}

value_is_closure :: proc(v: Value) -> bool {
    return value_is_object_type(v, .Closure)
}

value_as_closure :: proc(v: Value) -> ^ObjClosure {
    return cast(^ObjClosure) v.(^Obj)
}

// ---- NATIVE ----------------------------------------------------------------

ObjNative :: struct{
    using obj : Obj,
    function  : NativeFn,
}

// TODO(daniel): does this need to be freed?
value_new_native :: proc(function: NativeFn) -> ^ObjNative {
    obj := new(ObjNative)
    obj.type     = .Native
    obj.function = function

    return obj
}

value_is_native :: proc(v: Value) -> bool {
    return value_is_object_type(v, .Native)
}

value_as_native :: proc(v: Value) -> ^ObjNative {
    return cast(^ObjNative) v.(^Obj)
}

// ---- OBJECT ----------------------------------------------------------------

value_is_object_type :: proc(v: Value, type: ObjType) -> bool {
    if obj, ok := v.(^Obj); ok {
        return obj.type == type
    }

    return false
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
    case .Function:
        funa := cast(^ObjFunction) a
        funb := cast(^ObjFunction) b

        // TODO(daniel): function equality
        return false
    case .Closure:
        cla := cast(^ObjClosure) a
        clb := cast(^ObjClosure) b

        return value_equal_obj(cla.function, clb.function)
    case .Native:
        funa := cast(^ObjNative) a
        funb := cast(^ObjNative) b

        return funa.function == funb.function
    case:
        panic("unreachable")
    }
}

value_print_object :: proc(value: ^Obj) {
    switch value.type {
    case .String:
        str := value_as_string(value)

        fmt.printf("\"%s\"", str.chars)
    case .Function:
        fun := value_as_function(value)

        fmt.printf("<fn %s>", fun.name)
    case .Closure:
        clo := value_as_closure(value)

        // NOTE(daniel): closures "are" functions from the user's perspective.
        value_print_object(clo.function)
    case .Native:
        fun := value_as_native(value)

        // TODO(daniel): does this look reasonable? should we store a name for the native function?
        fmt.printf("<native fn %v>", fun.function)
    case:
        panic("unreachable")
    }
}

object_free :: proc(object: ^Obj) {
    switch object.type {
    case .String:
        v := cast(^ObjString) object

        free(v)
    case .Function:
        v := cast(^ObjFunction) object

        chunk_free(v.chunk)
        free(v)
    case .Closure:
        // NOTE(daniel): The closure doesn't "own" the function, so we're not freeing that here!
        v := cast(^ObjClosure) object

        free(v)
    case .Native:
        v := cast(^ObjNative) object

        free(v)
    case:
        panic("unreachable")
    }
}

