package main

import "core:fmt"

chunk_disassemble :: proc(chunk: ^Chunk, name: string) {
    fmt.printf("== %s ==\n", name)

    for offset := 0; offset < len(chunk.code); {
        offset = chunk_disassemble_instruction(chunk, offset)
    }
}

chunk_disassemble_instruction :: proc(chunk: ^Chunk, offset: int) -> int {
    fmt.printf("%04d ", offset)

    if offset > 0 && chunk.lines[offset] == chunk.lines[offset-1] {
        fmt.printf("   | ")
    } else {
        fmt.printf("%4d ", chunk.lines[offset])
    }

    switch opcode := OpCode(chunk.code[offset]); opcode {
    case .Constant:
        return constant_instruction("OP_CONSTANT", chunk, offset)
    case .Add:
        return simple_instruction("OP_ADD", offset)
    case .Subtract:
        return simple_instruction("OP_SUBTRACT", offset)
    case .Multiply:
        return simple_instruction("OP_MULTIPLY", offset)
    case .Divide:
        return simple_instruction("OP_DIVIDE", offset)
    case .Negate:
        return simple_instruction("OP_NEGATE", offset)
    case .Return:
        return simple_instruction("OP_RETURN", offset)
    case:
        fmt.printf("Unknown opcode %d\n", opcode)
        return offset + 1
    }
}

constant_instruction :: proc(name: string, chunk: ^Chunk, offset: int) -> int {
    constant := chunk.code[offset+1]

    fmt.printf("%-16s %4d '", name, constant)
    value_print(chunk.constants.values[constant])
    fmt.printf("'\n")

    return offset + 2
}

simple_instruction :: proc(name: string, offset: int) -> int {
    fmt.printf("%s\n", name)

    return offset + 1
}
