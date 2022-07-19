package main

Value :: union{
    Number,
    String,
    Boolean,
    Callable,
    Nil,
}

Void :: struct{}

Number :: f64
String :: string
Boolean :: bool
Nil :: struct{}

callable_proc :: proc(interp: ^Interpreter, arguments: []Value) -> Value

Callable :: struct{
    name: string,
    arity: int,
    call: callable_proc,
    fn: ^Function,
}

new_callable :: proc(name: string, arity: int, call: callable_proc = nil, fn: ^Function = nil) -> Value {
    callable : Value = Callable{
        name=name,
        arity=arity,
        call=call,
        fn=fn,
    }

    return callable
}

Token :: struct{
    type: TokenType,
    line: int,
    text: string,
    value: Value,
}
