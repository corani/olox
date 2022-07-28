package main 

import "core:fmt"
import "core:os"

DebugTraceExecution :: true
StackMax            :: 1024

main :: proc() {
    vm_init(&vm)

    switch len(os.args) {
    case 1:
        repl(&vm)
    case 2:
        run_file(&vm, os.args[1])
    case:
        fmt.eprintf("Usage: %s [path]\n", os.args[0])
        os.exit(64)
    }

    vm_free(&vm)
}

repl :: proc(vm: ^VM) {
    data: [1024]byte;

    for {
        fmt.print("> ")

        if n, _ := os.read(os.stdin, data[:]); n < 0 {
            fmt.println()

            break
        } else {
            _ = vm_interpret(vm, string(data[:n]))
        }
    }
}

run_file :: proc(vm: ^VM, path: string) {
    bytes, ok := os.read_entire_file_from_filename(path)
    if !ok {
        fmt.eprintf("ERROR: Could not read file: %s.\n", path)
        os.exit(74)
    }

    switch vm_interpret(vm, string(bytes)) {
    case .CompileError:
        os.exit(65)
    case .RuntimeError:
        os.exit(70)
    case .Ok:
        return
    }
}
