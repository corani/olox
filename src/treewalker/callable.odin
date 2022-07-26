package main 

import "core:fmt"
import "core:time"

Callable :: union{
    ^NativeFunction,
    ^LoxFunction,
    ^LoxClass,
}

new_callable_clock :: proc() -> Callable {
    return new_native_function(
        proc(interp: ^Interpreter, arguments: []Value) -> Result {
            return ReturnResult{
                value = f64(time.time_to_unix(time.now())),
            }
        }, "<native clock>", 0,
    )
}

callable_bind :: proc(callable: Callable, instance: ^Instance) -> Callable {
    #partial switch fn in callable {
    case ^LoxFunction:
        environment := new_environment(fn.closure)

        environment_define(environment, Token{
            type = .This,
            text = "this",
        }, instance)

        return new_lox_function(fn.decl, environment, fn.isInitializer)
    }

    return callable
}

callable_get_arity :: proc(callable: Callable) -> int {
    switch v in callable {
    case ^NativeFunction:
        return v.arity
    case ^LoxFunction:
        return v.arity
    case ^LoxClass:
        return v.arity
    case:
        return 0
    }
}

callable_get_name :: proc(callable: Callable) -> string {
    switch v in callable {
    case ^NativeFunction:
        return v.name
    case ^LoxFunction:
        return v.name
    case ^LoxClass:
        return v.name
    case:
        return ""
    }
}

callable_get_token :: proc(callable: Callable) -> Token {
    switch v in callable {
    case ^NativeFunction: 
        return native_function_get_token(v)
    case ^LoxFunction: 
        return lox_function_get_token(v)
    case ^LoxClass:
        return class_get_token(v)
    case:
        return Token{}
    }
}

callable_call :: proc(interp: ^Interpreter, token: Token, value: Value, arguments: []Value) -> Value {
    res: Result

    #partial switch callee in value {
    case Callable:
        if exp := callable_get_arity(callee); len(arguments) != exp {
            runtime_error(token, 
                fmt.tprintf("Expected %d arguments but got %d.", exp, len(arguments)))
            break
        }

        switch v in callee {
        case ^NativeFunction:
            res = native_function_call(v, interp, arguments)
        case ^LoxFunction:
            res = lox_function_call(v, interp, arguments)
        case ^LoxClass:
            res = class_new_instance(v, interp, arguments)
        case:
            report("Callable has no implementation.")
            res = OkResult{}
        }
    case:
        runtime_error(token, "Can only call functions and classes.")
    }

    #partial switch v in res {
    case ReturnResult:
        return v.value
    case:
        return Nil{}
    }
}
