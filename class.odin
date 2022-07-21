package main

import "core:fmt"

ClassType :: enum{
    None,
    Class,
}

LoxClass :: struct{
    class: ^Class,
    name: string,
    arity: int,
    methods: map[string]Callable,
}

new_lox_class :: proc(class: ^Class, methods: map[string]Callable) -> ^LoxClass {
    result := new(LoxClass)
    result.class = class
    result.name = fmt.tprintf("<class %s>", class.name.text)
    result.arity = 0
    result.methods = methods

    return result
}

class_find_method :: proc(class: ^LoxClass, name: Token) -> (Callable, bool) {
    if v, ok := class.methods[name.text]; ok {
        return v, true
    }

    return Callable{}, false
}

Instance :: struct{
    class: ^LoxClass,
    name: string,
    fields: map[string]Value,
}

new_lox_instance :: proc(class: ^LoxClass) -> Value {
    instance := new(Instance)
    instance.class = class
    instance.name = fmt.tprintf("<instance %v>", class.name)

    return Value(instance)
}

instance_get :: proc(instance: ^Instance, name: Token) -> Value {
    if v, ok := instance.fields[name.text]; ok {
        return v
    }

    method, ok := class_find_method(instance.class, name)
    if ok {
        return callable_bind(method, instance)
    }

    runtime_error(name, fmt.tprintf("Undefined property '%s'.", name.text))

    return Nil{}
}

instance_set :: proc(instance: ^Instance, name: Token, value: Value) {
    instance.fields[name.text] = value
}
