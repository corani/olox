package main 

import "core:fmt"
import "core:os"

DebugTraceExecution :: true
StackMax            :: 1024

main :: proc() {
    vm_init(&vm)

    chunk: Chunk
    chunk_init(&chunk)

    constant := chunk_add_constant(&chunk, Value(1.2))
    chunk_append_op(&chunk, .Constant, 123)
    chunk_append_u8(&chunk, constant, 123)

    constant = chunk_add_constant(&chunk, Value(3.4))
    chunk_append_op(&chunk, .Constant, 123)
    chunk_append_u8(&chunk, constant, 123)

    chunk_append_op(&chunk, .Add, 123)

    constant = chunk_add_constant(&chunk, Value(5.6))
    chunk_append_op(&chunk, .Constant, 123)
    chunk_append_u8(&chunk, constant, 123)

    chunk_append_op(&chunk, .Divide, 123)
    chunk_append_op(&chunk, .Negate, 123)

    chunk_append_op(&chunk, .Return, 123)

    chunk_disassemble(&chunk, "test chunk")

    vm_interpret(&vm, &chunk)

    chunk_free(&chunk)
    vm_free(&vm)

    os.exit(0)
}
