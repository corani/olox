package main

import "core:fmt"

VM :: struct {
    chunk    : ^Chunk,
    ip       : int,
    stack    : [StackMax]Value,
    stack_top: int,
}

InterpretResult :: enum {
    Ok,
    CompileError,
    RuntimeError,
}

// TODO(daniel): make this a local in main?
vm: VM

vm_init :: proc(vm: ^VM) {
    // nothing, for now
}

vm_free :: proc(vm: ^VM) {
    // nothing, for now
}

vm_stack_reset :: proc(vm: ^VM) {
    vm.stack_top = 0
}

vm_stack_push :: proc(vm: ^VM, value: Value) {
    vm.stack[vm.stack_top] = value
    vm.stack_top += 1
}

vm_stack_pop :: proc(vm: ^VM) -> Value {
    vm.stack_top -= 1
    return vm.stack[vm.stack_top]
}

vm_stack_print :: proc(vm: ^VM) {
    fmt.print("          ")
    for i := 0; i < vm.stack_top; i += 1 {
        fmt.print("[ ")
        value_print(vm.stack[i])
        fmt.print(" ]")
    }
    fmt.println()
}

vm_interpret :: proc(vm: ^VM, chunk: ^Chunk) -> InterpretResult {
    vm.chunk = chunk
    vm.ip    = 0

    return vm_run(vm)
}

vm_run :: proc(vm: ^VM) -> InterpretResult {
    for {
        when DebugTraceExecution {
            vm_stack_print(vm)
            chunk_disassemble_instruction(vm.chunk, vm.ip)
        }

        switch instruction := vm_read_byte(vm); OpCode(instruction) {
        case .Return:
            return .Ok
        case .Add:
            vm_exec_binary(vm, proc(a, b: Value) -> Value { return a + b })
        case .Subtract:
            vm_exec_binary(vm, proc(a, b: Value) -> Value { return a - b })
        case .Multiply:
            vm_exec_binary(vm, proc(a, b: Value) -> Value { return a * b })
        case .Divide:
            vm_exec_binary(vm, proc(a, b: Value) -> Value { return a / b })
        case .Negate:
            vm_stack_push(vm, -vm_stack_pop(vm))
        case .Constant:
            constant := vm_read_constant(vm)
            vm_stack_push(vm, constant)
        }
    }
}

vm_exec_binary :: proc(vm: ^VM, fn: proc(a, b: Value) -> Value) {
    // in this order!
    b := vm_stack_pop(vm)
    a := vm_stack_pop(vm)

    vm_stack_push(vm, fn(a, b))
}

vm_read_constant :: proc(vm: ^VM) -> Value {
    index := vm_read_byte(vm)

    return vm.chunk.constants.values[index]
}

vm_read_byte :: proc(vm: ^VM) -> u8 {
    defer vm.ip += 1

    return vm.chunk.code[vm.ip]
}
