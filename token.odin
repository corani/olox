package main

Value :: union{
    Number,
    String,
    Boolean,
    Callable,
    ^LoxClass,
    ^Instance,
    Nil,
}

Void :: struct{}

Number :: f64
String :: string
Boolean :: bool
Nil :: struct{}

Token :: struct{
    type: TokenType,
    line: int,
    text: string,
    value: Value,
}
