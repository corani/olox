package main

import "core:fmt"

FunctionType :: enum{
    None,
    Function,
    Initializer,
    Method,
}

LoxFunction :: struct{
    decl: ^Function,
    closure: ^Environment,
    name: string,
    arity: int,
    isInitializer: bool,
}

new_lox_function :: proc(decl: ^Function, closure: ^Environment, isInitializer: bool) -> ^LoxFunction {
    result := new(LoxFunction)
    result.decl = decl
    result.closure = closure
    result.isInitializer = isInitializer
    result.name = fmt.tprintf("<fn %s>", decl.name.text)
    result.arity = len(decl.params)

    return result
}

lox_function_call :: proc(function: ^LoxFunction, interp: ^Interpreter, arguments: []Value) -> Result {
    environment := new_environment(function.closure)

    for i := 0; i < function.arity; i += 1 {
        environment_define(environment, function.decl.params[i], arguments[i])
    }

    result := interpret_block(interp, function.decl.body[:], environment)
    #partial switch in result {
    case ReturnResult:
        if function.isInitializer {
            value := environment_get_at(function.closure, Token{text="this"}, 0)

            result = ReturnResult{value=value}
        }
    case:
        if function.isInitializer {
            value := environment_get_at(function.closure, Token{text="this"}, 0)

            result = ReturnResult{value=value}
        }
    }

    return result
}

lox_function_get_token :: proc(function: ^LoxFunction) -> Token {
    return function.decl.name
}

callable_proc :: proc(interp: ^Interpreter, arguments: []Value) -> Result

NativeFunction :: struct{
    defn: callable_proc,
    name: string,
    arity: int,
}

new_native_function :: proc(defn: callable_proc, name: string, arity: int) -> ^NativeFunction {
    result := new(NativeFunction)
    result.defn = defn
    result.name = fmt.tprintf("<native %s>", name)
    result.arity = arity

    return result
}

native_function_call :: proc(native: ^NativeFunction, interp: ^Interpreter, arguments: []Value) -> Result {
    return native.defn(interp, arguments)
}

native_function_get_token :: proc(native: ^NativeFunction) -> Token {
    return Token{
        type=TokenType.Identifier,
        text=native.name,
    }
}
