package main 

import "core:fmt"
import "core:time"

new_callable_clock :: proc() -> Value {
    return new_callable(
        name="<native fn>",
        arity=0,
        call=proc(interp: ^Interpreter, arguments: []Value) -> Value {
            return f64(time.time_to_unix(time.now()))
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

callable_function_call :: proc(interp: ^Interpreter, callee: Callable, arguments: []Value) -> Value {
    environment := new_environment(interp.globals)

    for i := 0; i < len(callee.fn.params); i += 1 {
        environment_define(environment, callee.fn.params[i], arguments[i])
    }

    interpret_block(interp, callee.fn.body[:], environment)

    return Nil{}
}

callable_native_call :: proc(interp: ^Interpreter, callee: Callable, arguments: []Value) -> Value {
    return callee.call(interp, arguments)
}

callable_call :: proc(interp: ^Interpreter, callee: Callable, arguments: []Value) -> Value {
    if callee.call != nil {
        return callable_native_call(interp, callee, arguments)
    }
    if callee.fn != nil {
        return callable_function_call(interp, callee, arguments)
    }

    report("Callable has no implementation.")

    return Nil{}
}
