package main 

import "core:fmt"
import "core:time"

// TODO(daniel): maybe Callable should be an enum?
Callable :: struct{
    native: ^NativeFunction,
    function: ^LoxFunction,
    class: ^LoxClass,
}

new_callable_clock :: proc() -> Callable {
    return Callable{
        native=new_native_function(
            proc(interp: ^Interpreter, arguments: []Value) -> Result {
                return ReturnResult{
                    value=f64(time.time_to_unix(time.now())),
                }
            }, "<native clock>", 0,
        ),
    }
}

new_callable_function :: proc(fn: ^Function, closure: ^Environment) -> Callable {
    return Callable{
        function=new_lox_function(fn, closure),
    }
}

new_callable_class :: proc(class: ^Class, methods: map[string]Callable) -> Value {
    return Callable{
        class=new_lox_class(class, methods),
    }
}

callable_class_call :: proc(interp: ^Interpreter, callee: Callable, arguments: []Value) -> Result {
    instance := new_lox_instance(callee.class)

    return ReturnResult{value=instance}
}

callable_get_arity :: proc(callable: Callable) -> int {
    switch {
    case callable.native   != nil: 
        return callable.native.arity
    case callable.function != nil: 
        return callable.function.arity
    case callable.class    != nil: 
        return callable.class.arity
    case:
        return 0
    }
}

callable_get_name :: proc(callable: Callable) -> string {
    switch {
    case callable.native   != nil: 
        return callable.native.name
    case callable.function != nil: 
        return callable.function.name
    case callable.class    != nil:
        return callable.class.name
    case:
        return ""
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

        if callee.native != nil {
            res = native_function_call(callee.native, interp, arguments)
        } else if callee.function != nil {
            res = lox_function_call(callee.function, interp, arguments)
        } else if callee.class != nil {
            res = callable_class_call(interp, callee, arguments)
        } else {
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
