package main

import "core:fmt"

FunctionType :: enum{
    None,
    Function,
    Method,
}

LoxFunction :: struct{
    function: ^Function,
    closure: ^Environment,
    name: string,
    arity: int,
}

new_lox_function :: proc(function: ^Function, closure: ^Environment) -> ^LoxFunction {
    result := new(LoxFunction)
    result.function = function
    result.closure = closure
    result.name = fmt.tprintf("<fn %s>", function.name.text)
    result.arity = len(function.params)

    return result
}

lox_function_call :: proc(function: ^LoxFunction, interp: ^Interpreter, arguments: []Value) -> Result {
    environment := new_environment(function.closure)

    for i := 0; i < function.arity; i += 1 {
        environment_define(environment, function.function.params[i], arguments[i])
    }

    return interpret_block(interp, function.function.body[:], environment)
}

callable_proc :: proc(interp: ^Interpreter, arguments: []Value) -> Result

NativeFunction :: struct{
    function: callable_proc,
    name: string,
    arity: int,
}

new_native_function :: proc(function: callable_proc, name: string, arity: int) -> ^NativeFunction {
    result := new(NativeFunction)
    result.function = function
    result.name = fmt.tprintf("<native %s>", name)
    result.arity = arity

    return result
}

native_function_call :: proc(native: ^NativeFunction, interp: ^Interpreter, arguments: []Value) -> Result {
    return native.function(interp, arguments)
}
