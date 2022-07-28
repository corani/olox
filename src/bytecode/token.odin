package main

Token :: struct{
    type: TokenType,
    text: string,
    line: int,
}

TokenType :: enum{
    // Single-character tokens.
    LeftParen, RightParen, LeftBrace, RightBrace, 
    Comma, Dot, Semicolon, Minus, Plus, Slash, Star,

    // One or two character tokens.
    Bang, BangEqual, Equal, EqualEqual,
    Greater, GreaterEqual, Less, LessEqual,

    // Literals.
    Identifier, String, Number,

    // Keywords.
    And, Class, Else, False, For, Fun, If, Nil, Or,
    Print, Return, Super, This, True, Var, While,

    // Other.
    Error, Eof,
}
