package main 

import "core:fmt"
import "core:os"

main :: proc() {
    chunk: Chunk
    chunk_init(&chunk)

    constant := chunk_add_constant(&chunk, Value(1.2))
    chunk_append_op(&chunk, .Constant, 123)
    chunk_append_u8(&chunk, constant, 123)

    chunk_append_op(&chunk, .Return, 123)

    chunk_disassemble(&chunk, "test chunk")
    chunk_free(&chunk)

    os.exit(0)
}
