package main

import "core:time"

NativeFn :: proc(args: []Value) -> Value

native_clock :: proc(args: []Value) -> Value {
    return f64(time.time_to_unix(time.now()))
}
