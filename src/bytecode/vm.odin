package main

import "core:fmt"
import "core:strings"

VM :: struct {
    frame       : [FrameMax]CallFrame,
    frame_count : int,
    stack       : [StackMax]Value,
    stack_top   : int,
    objects     : ^Obj,
    globals     : map[string]Value,
}

CallFrame :: struct {
    closure     : ^ObjClosure,
    ip          : int, // TODO(daniel): `return_ip`?
    stack_index : int, // NOTE(daniel): in VM.stack
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

    vm_define_native(vm, "clock", native_clock)
}

vm_free :: proc(vm: ^VM) {
    object := vm.objects

    for object != nil {
        next := object.next
        object_free(object)
        object = next
    }

    // TODO(daniel): free the callframes (should be 1 at this point)
    // TODO(daniel): free the stack (should be 0 at this point)

    vm.objects = nil
}

vm_stack_reset :: proc(vm: ^VM) {
    vm.frame_count = 0
    vm.stack_top   = 0
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
    frame := vm_current_frame(vm)
    chunk := frame.closure.function.chunk

    line := chunk.lines[frame.ip-1]
    fmt.eprintf("ERROR: %d: %s\n", line, message)

    for i := vm.frame_count - 1; i >= 0; i -= 1 {
        frame    := vm.frame[i]
        closure := frame.closure

        fmt.eprintf("  [line %d] in %s\n", 
            closure.function.chunk.lines[frame.ip], closure.function.name)
    }

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

vm_allocate_function :: proc(vm: ^VM, name: string) -> Value {
    object := vm_allocate_object(vm, ObjFunction, .Function)
    object.arity = 0
    object.name  = name
    chunk_init(object.chunk)

    return cast(^Obj) object

}

vm_define_native :: proc(vm: ^VM, name: string, function: NativeFn) {
    vm.globals[name] = cast(^Obj) value_new_native(function)
}

vm_interpret :: proc(vm: ^VM, source: string) -> InterpretResult {
    function, ok := compile(source) 
    if !ok {
        return .CompileError
    }

    closure := value_new_closure(function)
    vm_stack_push(vm, cast(^Obj) closure)

    vm_call_closure(vm, closure, 0)

    return vm_run(vm)
}

vm_run :: proc(vm: ^VM) -> InterpretResult {
    frame := vm_current_frame(vm)

    for {
        when DebugTraceExecution {
            vm_stack_print(vm)
            chunk_disassemble_instruction(frame.closure.function.chunk, frame.ip)
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
            slot := int(vm_read_byte(vm)) + frame.stack_index
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
            slot := int(vm_read_byte(vm)) + frame.stack_index
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
                b := value_as_string(vm_stack_pop(vm)).chars
                a := value_as_string(vm_stack_pop(vm)).chars
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
            vm_stack_push(vm, value_is_falsey(vm_stack_pop(vm)))
        case .Negate:
            if !vm_exec_negate(vm) {
                return .RuntimeError
            }
        case .Print:
            value_print(vm_stack_pop(vm))
            fmt.println()
        case .Jump:
            offset := vm_read_short(vm)
            frame.ip += int(offset)
        case .JumpIfFalse:
            offset := vm_read_short(vm)
            if value_is_falsey(vm_stack_peek(vm, 0)) {
                frame.ip += int(offset)
            }
        case .Loop:
            offset := vm_read_short(vm)
            frame.ip -= int(offset)
        case .Call:
            arg_count := int(vm_read_byte(vm))
            if !vm_call_value(vm, vm_stack_peek(vm, arg_count), arg_count) {
                return .RuntimeError
            }

            frame = vm_current_frame(vm)
        case .Closure:
            function := value_as_function(vm_read_constant(vm))
            closure  := value_new_closure(function)
            vm_stack_push(vm, cast(^Obj) closure)
        case .Return:
            result := vm_stack_pop(vm)
            vm.frame_count -= 1
            if vm.frame_count == 0 {
                // TODO(daniel): this is a stack underflow:
                // vm_stack_pop(vm)
                return .Ok
            }

            vm.stack_top = frame.stack_index
            vm_stack_push(vm, result)
            frame = vm_current_frame(vm)
        }
    }
}

vm_call_closure :: proc(vm: ^VM, closure: ^ObjClosure, arg_count: int) -> bool {
    if arg_count != closure.function.arity {
        vm_runtime_error(vm, fmt.tprintf("Expected %d arguments but got %d.", 
            closure.function.arity, arg_count))
        return false
    }

    if vm.frame_count == FrameMax {
        vm_runtime_error(vm, "Stack overflow.")
        return false
    }

    vm.frame[vm.frame_count] = CallFrame{
        closure     = closure,
        ip          = 0,
        // function stack includes function value ("slot zero") and arguments!
        stack_index = vm.stack_top - arg_count - 1,
    }

    vm.frame_count += 1

    return true
}

vm_call_native :: proc(vm: ^VM, native: ^ObjNative, arg_count: int) -> bool {
    result := native.function(vm.stack[vm.stack_top - arg_count:vm.stack_top])
    vm.stack_top -= arg_count + 1
    vm_stack_push(vm, result)

    return true
}

vm_call_value :: proc(vm: ^VM, callee: Value, arg_count: int) -> bool {
    switch {
    case value_is_function(callee):
        panic("unreachable")
    case value_is_closure(callee):
        return vm_call_closure(vm, value_as_closure(callee), arg_count)
    case value_is_native(callee):
        return vm_call_native(vm, value_as_native(callee), arg_count)
    }

    vm_runtime_error(vm, "Can only call functions and classes.")

    return false
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

vm_current_frame :: proc(vm: ^VM) -> ^CallFrame {
    return &vm.frame[vm.frame_count - 1]
}

vm_current_chunk :: proc(vm: ^VM) -> ^Chunk {
    return vm_current_frame(vm).closure.function.chunk
}

vm_read_byte :: proc(vm: ^VM) -> u8 {
    frame := vm_current_frame(vm)

    defer frame.ip += 1

    return frame.closure.function.chunk.code[frame.ip]
}

vm_read_short :: proc(vm: ^VM) -> u16 {
    frame := vm_current_frame(vm)
    chunk := frame.closure.function.chunk

    defer frame.ip += 2

    // TODO(daniel): order?
    return (u16(chunk.code[frame.ip]) << 8) | u16(chunk.code[frame.ip + 1])
}

vm_read_constant :: proc(vm: ^VM) -> Value {
    index := vm_read_byte(vm)

    return vm_current_chunk(vm).constants.values[index]
}

vm_read_string :: proc(vm: ^VM) -> string {
    return value_as_string(vm_read_constant(vm)).chars
}

