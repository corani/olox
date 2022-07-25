package main

TokenType :: enum{
    Invalid,

    // Single-character tokens.
    LeftParen, RightParen, LeftBrace, RightBrace,
    Comma, Dot, Minus, Plus, Semicolon, Slash, Star,

    // One or two character tokens.
    Bang, BangEqual,
    Equal, EqualEqual,
    Greater, GreaterEqual,
    Less, LessEqual,

    // Literals.
    Identifier, String, Number,

    // Keywords.
    And, Class, Else, False, Fun, For, If, Nil, Or,
    Print, Return, Super, This, True, Var, While,

    EOF
}

Value :: union{
    Number,
    String,
    Boolean,
    Callable,
    ^LoxClass,
    ^Instance,
    Nil,
}

Number  :: f64
String  :: string
Boolean :: bool
Nil     :: struct{}

Token :: struct{
    type  : TokenType,
    line  : int,
    text  : string,
    value : Value,
}
