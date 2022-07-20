package main 

import "core:fmt"
import "core:time"

callable_proc :: proc(interp: ^Interpreter, arguments: []Value) -> Result

Callable :: struct{
    name: string,
    arity: int,
    native: callable_proc,
    fn: ^Function,
    class: ^Class,
    closure: ^Environment,
}

new_callable :: proc(name: string, arity: int, 
    native: callable_proc = nil, 
    fn: ^Function = nil, 
    class: ^Class = nil,
    closure: ^Environment = nil,
) -> Value {
    callable : Value = Callable{
        name=name,
        arity=arity,
        native=native,
        fn=fn,
        class=class,
        closure=closure,
    }

    return callable
}

new_callable_clock :: proc() -> Value {
    return new_callable(
        name="<native fn>",
        arity=0,
        native=proc(interp: ^Interpreter, arguments: []Value) -> Result {
            return ReturnResult{
                value=f64(time.time_to_unix(time.now())),
            }
        },
    )
}

new_callable_function :: proc(fn: ^Function, closure: ^Environment) -> Value {
    return new_callable(
        name=fmt.tprintf("<fn %s>", fn.name.text),
        arity=len(fn.params),
        fn=fn,
        closure=closure,
    )
}

new_callable_class :: proc(class: ^Class) -> Value {
    return new_callable(
        name=fmt.tprintf("<instance %s>", class.name),
        arity=0,
        class=class,
    )
}

callable_function_call :: proc(interp: ^Interpreter, callee: Callable, arguments: []Value) -> Result {
    environment := new_environment(callee.closure)

    for i := 0; i < len(callee.fn.params); i += 1 {
        environment_define(environment, callee.fn.params[i], arguments[i])
    }

    return interpret_block(interp, callee.fn.body[:], environment)
}

callable_native_call :: proc(interp: ^Interpreter, callee: Callable, arguments: []Value) -> Result {
    return callee.native(interp, arguments)
}

callable_class_call :: proc(interp: ^Interpreter, callee: Callable, arguments: []Value) -> Result {
    instance := new_lox_instance(callee.class)

    return ReturnResult{value=instance}
}

callable_call :: proc(interp: ^Interpreter, token: Token, value: Value, arguments: []Value) -> Value {
    res: Result

    #partial switch callee in value {
    case Callable:
        if len(arguments) != callee.arity {
            runtime_error(token, 
                fmt.tprintf("Expected %d arguments but got %d.", callee.arity, len(arguments)))
            break
        }

        if callee.native != nil {
            res = callable_native_call(interp, callee, arguments)
        } else if callee.fn != nil {
            res = callable_function_call(interp, callee, arguments)
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
