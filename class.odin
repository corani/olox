package main

import "core:fmt"

LoxClass :: struct{
    name: string,
}

new_lox_class :: proc(name: string) -> Value {
    class : Value = LoxClass{
        name=name,
    }

    return class
}

Instance :: struct{
    class: ^Class,
    fields: map[string]Value,
}

new_lox_instance :: proc(class: ^Class) -> Value {
    instance := new(Instance)
    instance.class = class

    return Value(instance)
}

instance_get :: proc(instance: ^Instance, name: Token) -> Value {
    if v, ok := instance.fields[name.text]; ok {
        return v
    }

    runtime_error(name, fmt.tprintf("Undefined property '%s'.", name.text))

    return Nil{}
}

instance_set :: proc(instance: ^Instance, name: Token, value: Value) {
    instance.fields[name.text] = value
}
