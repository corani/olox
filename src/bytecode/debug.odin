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

    // TODO(daniel): print the opcode directly
    switch opcode := OpCode(chunk.code[offset]); opcode {
    case .Constant:
        return constant_instruction("OP_CONSTANT", chunk, offset)
    case .False:
        return simple_instruction("OP_FALSE", offset)
    case .Equal:
        return simple_instruction("OP_EQUAL", offset)
    case .Greater:
        return simple_instruction("OP_GREATER", offset)
    case .Less:
        return simple_instruction("OP_LESS", offset)
    case .True:
        return simple_instruction("OP_TRUE", offset)
    case .Nil:
        return simple_instruction("OP_NIL", offset)
    case .Pop:
        return simple_instruction("OP_POP", offset)
    case .DefineGlobal:
        return constant_instruction("OP_DEFINE_GLOBAL", chunk, offset)
    case .GetLocal:
        return byte_instruction("OP_GET_LOCAL", chunk, offset)
    case .SetLocal:
        return byte_instruction("OP_SET_LOCAL", chunk, offset)
    case .GetGlobal:
        return constant_instruction("OP_GET_GLOBAL", chunk, offset)
    case .SetGlobal:
        return constant_instruction("OP_SET_GLOBAL", chunk, offset)
    case .Add:
        return simple_instruction("OP_ADD", offset)
    case .Subtract:
        return simple_instruction("OP_SUBTRACT", offset)
    case .Multiply:
        return simple_instruction("OP_MULTIPLY", offset)
    case .Divide:
        return simple_instruction("OP_DIVIDE", offset)
    case .Not:
        return simple_instruction("OP_NOT", offset)
    case .Negate:
        return simple_instruction("OP_NEGATE", offset)
    case .Print:
        return simple_instruction("OP_PRINT", offset)
    case .Return:
        return simple_instruction("OP_RETURN", offset)
    case:
        fmt.printf("Unknown opcode %d\n", opcode)
        return offset + 1
    }
}

byte_instruction :: proc(name: string, chunk: ^Chunk, offset: int) -> int {
    slot := chunk.code[offset+1]

    fmt.printf("%-16s %4d\n", name, slot);

    return offset + 2;
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
