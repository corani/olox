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

environment_delete :: proc(environment: ^Environment) {
    delete(environment.values)
    free(environment)
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

environment_assign_at :: proc(environment: ^Environment, name: Token, depth: int, value: Value) -> Value {
    ancestor := environment_ancestor_at(environment, depth)

    if ancestor != nil {
        ancestor.values[name.text] = value
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

environment_get_at :: proc(environment: ^Environment, name: Token, depth: int) -> Value {
    ancestor := environment_ancestor_at(environment, depth)

    if ancestor != nil {
        if value, ok := ancestor.values[name.text]; ok {
            return value
        }
    }

    runtime_error(name, fmt.tprintf("Undefined variable '%s'.", name.text))

    return Nil{}
}

environment_ancestor_at :: proc(environment: ^Environment, depth: int) -> ^Environment {
    ancestor := environment

    for i := 0; i < depth; i += 1 {
        ancestor = ancestor.enclosing
    }

    return ancestor
}

environment_depth :: proc(environment: ^Environment) -> int {
    current := environment
    i := 0

    for i = 0; current != nil; i += 1 {
        current = current.enclosing
    }

    return i
}
