package main 

import "core:fmt"
import "core:time"

new_callable_clock :: proc() -> Value {
    return new_callable(
        name="<native fn>",
        arity=0,
        call=proc(interp: ^Interpreter, arguments: []Value) -> Result {
            return ReturnResult{
                value=f64(time.time_to_unix(time.now())),
            }
        },
    )
}

new_callable_function :: proc(fn: ^Function) -> Value {
    return new_callable(
        name=fmt.tprintf("<fn %s>", fn.name.text),
        arity=len(fn.params),
        fn=fn,
    )
}

callable_function_call :: proc(interp: ^Interpreter, callee: Callable, arguments: []Value) -> Result {
    environment := new_environment(interp.globals)

    for i := 0; i < len(callee.fn.params); i += 1 {
        environment_define(environment, callee.fn.params[i], arguments[i])
    }

    return interpret_block(interp, callee.fn.body[:], environment)
}

callable_native_call :: proc(interp: ^Interpreter, callee: Callable, arguments: []Value) -> Result {
    return callee.call(interp, arguments)
}

callable_call :: proc(interp: ^Interpreter, callee: Callable, arguments: []Value) -> Value {
    res: Result

    if callee.call != nil {
        res = callable_native_call(interp, callee, arguments)
    } else if callee.fn != nil {
        res = callable_function_call(interp, callee, arguments)
    } else {
        report("Callable has no implementation.")
        res = OkResult{}
    }

    #partial switch v in res {
    case ReturnResult:
        return v.value
    case:
        return Nil{}
    }
}
