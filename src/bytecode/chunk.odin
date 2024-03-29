package main

OpCode :: enum u8 {
    Constant,
    Nil,
    True,
    False,
    Pop,
    DefineGlobal,
    GetGlobal,
    SetGlobal,
    GetLocal,
    SetLocal,
    Equal,
    Greater,
    Less,
    Add,
    Subtract,
    Multiply,
    Divide,
    Not,
    Negate,
    Print,
    Jump,
    JumpIfFalse,
    Loop,
    Call,
    Closure,
    Return,
}

Chunk :: struct {
    code      : [dynamic]u8,
    lines     : [dynamic]int,
    constants : ValueArray,
}

chunk_init :: proc(chunk: ^Chunk) {
    value_array_init(&chunk.constants)
}

chunk_append_u8 :: proc(chunk: ^Chunk, v: u8, line: int) {
    append(&chunk.code, v)
    append(&chunk.lines, line)
}

chunk_append_op :: proc(chunk: ^Chunk, v: OpCode, line: int) {
    chunk_append_u8(chunk, u8(v), line)
}

chunk_size :: proc(chunk: ^Chunk) -> int {
    return len(chunk.code)
}

chunk_free :: proc(chunk: ^Chunk) {
    delete(chunk.code)
    delete(chunk.lines)
    value_array_free(&chunk.constants)
    free(chunk)
}

chunk_add_constant :: proc(chunk: ^Chunk, value: Value) -> int {
    return value_array_append(&chunk.constants, value)
}
