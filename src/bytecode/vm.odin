package main

import "core:fmt"
import "core:strings"

VM :: struct {
    chunk    : ^Chunk,
    ip       : int,
    stack    : [StackMax]Value,
    stack_top: int,
    objects  : ^Obj,
    globals  : map[string]Value,
}

InterpretResult :: enum {
    Ok,
    CompileError,
    RuntimeError,
}

// TODO(daniel): make this a local in main?
vm: VM

vm_init :: proc(vm: ^VM) {
    vm_stack_reset(vm)
    vm.objects = nil
}

vm_free :: proc(vm: ^VM) {
    object := vm.objects

    for object != nil {
        next := object.next
        object_free(object)
        object = next
    }

    vm.objects = nil
}

vm_stack_reset :: proc(vm: ^VM) {
    vm.stack_top = 0
}

vm_stack_push :: proc(vm: ^VM, value: Value) {
    if vm.stack_top < StackMax {
        vm.stack[vm.stack_top] = value
        vm.stack_top += 1
        return
    }

    vm_runtime_error(vm, "Stack overflow.")
}

vm_stack_pop :: proc(vm: ^VM) -> Value {
    // TODO(daniel): when to free values that are popped?
    if vm.stack_top > 0 {
        vm.stack_top -= 1
        return vm.stack[vm.stack_top]
    }

    vm_runtime_error(vm, "Stack underflow.")
    return Nil{}
}

vm_stack_peek :: proc(vm: ^VM, distance := 0) -> Value {
    if vm.stack_top > distance {
        value := vm.stack[vm.stack_top - distance - 1]
        return value
    }

    vm_runtime_error(vm, "Stack underflow.")
    return Nil{}
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

vm_runtime_error :: proc(vm: ^VM, message: string) {
    line := vm.chunk.lines[vm.ip-1]
    fmt.eprintf("ERROR: %d: %s\n", line, message)
    vm_stack_reset(vm)
}

vm_allocate_object :: proc(vm: ^VM, $T: typeid, type: ObjType) -> ^T {
    object := new(T)
    object.type = type
    object.next = vm.objects

    vm.objects = object

    return object
}

vm_allocate_string :: proc(vm: ^VM, v: string) -> Value {
    object := vm_allocate_object(vm, ObjString, .String)
    object.chars = v

    return cast(^Obj) object
}

vm_interpret :: proc(vm: ^VM, source: string) -> InterpretResult {
    chunk: Chunk
    chunk_init(&chunk)
    defer chunk_free(&chunk)

    if !compile(&chunk, source) {
        return .CompileError
    }

    vm.chunk = &chunk
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
        case .Constant:
            constant := vm_read_constant(vm)
            vm_stack_push(vm, constant)
        case .False:
            vm_stack_push(vm, false)
        case .True:
            vm_stack_push(vm, true)
        case .Nil:
            vm_stack_push(vm, Nil{})
        case .Pop:
            vm_stack_pop(vm)
        case .DefineGlobal:
            name := vm_read_string(vm)
            vm.globals[name] = vm_stack_pop(vm)
        case .GetLocal:
            slot := vm_read_byte(vm)
            vm_stack_push(vm, vm.stack[slot])
        case .GetGlobal:
            name := vm_read_string(vm)
            if value, ok := vm.globals[name]; ok {
                vm_stack_push(vm, value)
            } else {
                vm_runtime_error(vm, fmt.tprintf("Undefined variable '%s'.", name))
                return .RuntimeError
            }
        case .SetLocal:
            slot := vm_read_byte(vm)
            vm.stack[slot] = vm_stack_peek(vm)
        case .SetGlobal:
            name := vm_read_string(vm)
            // TODO(daniel): do we need to free the old value?
            if _, ok := vm.globals[name]; ok {
                vm.globals[name] = vm_stack_peek(vm)
            } else {
                vm_runtime_error(vm, fmt.tprintf("Undefined variable '%s'.", name))
                return .RuntimeError
            }
        case .Equal:
            b := vm_stack_pop(vm)
            a := vm_stack_pop(vm)
            vm_stack_push(vm, value_equal(a, b))
        case .Greater:
            if !vm_exec_binary(vm, proc(a, b: Value) -> Value { return a.(f64) > b.(f64) }) {
                return .RuntimeError
            }
        case .Less:
            if !vm_exec_binary(vm, proc(a, b: Value) -> Value { return a.(f64) < b.(f64) }) {
                return .RuntimeError
            }
        case .Add:
            vb := vm_stack_peek(vm, 0)
            va := vm_stack_peek(vm, 1)

            switch {
            case value_is_string(va) && value_is_string(vb):
                b := value_as_string(vm_stack_pop(vm))
                a := value_as_string(vm_stack_pop(vm))
                c := strings.concatenate([]string{ a, b })
                vm_stack_push(vm, vm_allocate_string(vm, c))
            case value_is_number(va) && value_is_number(vb):
                b := value_as_number(vm_stack_pop(vm))
                a := value_as_number(vm_stack_pop(vm))
                vm_stack_push(vm, value_new_number(a+b))
            case:
                vm_runtime_error(vm, "Operands must be two numbers or two strings.")
                return .RuntimeError
            }
        case .Subtract:
            if !vm_exec_binary(vm, proc(a, b: Value) -> Value { return a.(f64) - b.(f64) }) {
                return .RuntimeError
            }
        case .Multiply:
            if !vm_exec_binary(vm, proc(a, b: Value) -> Value { return a.(f64) * b.(f64) }) {
                return .RuntimeError
            }
        case .Divide:
            if !vm_exec_binary(vm, proc(a, b: Value) -> Value { return a.(f64) / b.(f64) }) {
                return .RuntimeError
            }
        case .Not:
            vm_stack_push(vm, is_falsey(vm_stack_pop(vm)))
        case .Negate:
            if !vm_exec_negate(vm) {
                return .RuntimeError
            }
        case .Print:
            value_print(vm_stack_pop(vm))
            fmt.println()
        case .Return:
            return .Ok
        }
    }
}

vm_exec_negate :: proc(vm: ^VM) -> bool {
    value, ok := vm_stack_pop(vm).(f64)
    if !ok {
        vm_runtime_error(vm, "Operand must be a number.")
        return false
    }

    vm_stack_push(vm, Value(-value))
    return true
}

vm_exec_binary :: proc(vm: ^VM, fn: proc(a, b: Value) -> Value) -> bool {
    // in this order!
    b, okb := vm_stack_pop(vm).(f64)
    if !okb {
        vm_runtime_error(vm, "Operands must be numbers.")
        return false
    }

    a, oka := vm_stack_pop(vm).(f64)
    if !oka {
        vm_runtime_error(vm, "Operands must be numbers.")
        return false
    }

    vm_stack_push(vm, fn(a, b))

    return true
}

vm_read_byte :: proc(vm: ^VM) -> u8 {
    defer vm.ip += 1

    return vm.chunk.code[vm.ip]
}

vm_read_constant :: proc(vm: ^VM) -> Value {
    index := vm_read_byte(vm)

    return vm.chunk.constants.values[index]
}

vm_read_string :: proc(vm: ^VM) -> string {
    return value_as_string(vm_read_constant(vm))
}

is_falsey :: proc(value: Value) -> bool {
    switch v in value {
    case f64:
        return false
    case bool:
        return !v
    case Nil:
        return true
    case ^Obj:
        switch v.type {
        case .String:
            return false
        case:
            panic("unreachable")
        }
    case:
        panic("unreachable")
    }
}
