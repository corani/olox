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

callable_proc :: proc(interp: ^Interpreter, arguments: []Value) -> Result

Callable :: struct{
    name: string,
    arity: int,
    call: callable_proc,
    fn: ^Function,
    closure: ^Environment,
}

new_callable :: proc(name: string, arity: int, call: callable_proc = nil, fn: ^Function = nil, closure: ^Environment = nil) -> Value {
    callable : Value = Callable{
        name=name,
        arity=arity,
        call=call,
        fn=fn,
        closure=closure,
    }

    return callable
}

Token :: struct{
    type: TokenType,
    line: int,
    text: string,
    value: Value,
}
