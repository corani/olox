package main

import "core:fmt"

Environment :: struct{
    enclosing: ^Environment,
    values: map[string]Value,
}

new_environment :: proc(enclosing: ^Environment = nil) -> ^Environment{
    environment := new(Environment)
    environment.enclosing = enclosing

    return environment
}

environment_define :: proc(environment: ^Environment, name: Token, value: Value) {
    environment.values[name.text] = value
}

environment_assign :: proc(environment: ^Environment, name: Token, value: Value) -> Value {
    if _, ok := environment.values[name.text]; ok {
        environment.values[name.text] = value

        return value
    }

    if environment.enclosing != nil {
        return environment_assign(environment.enclosing, name, value)
    }

    runtime_error(name, fmt.tprintf("Undefined variable '%s'.", name.text))

    return Nil{}
}

environment_get :: proc(environment: ^Environment, name: Token) -> Value {
    value, ok := environment.values[name.text]
    if ok {
        return value
    }

    if environment.enclosing != nil {
        return environment_get(environment.enclosing, name)
    }

    runtime_error(name, fmt.tprintf("Undefined variable '%s'.", name.text))

    return Nil{}
}
