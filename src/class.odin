package main

import "core:fmt"

ClassType :: enum{
    None,
    Class,
    Subclass,
}

LoxClass :: struct{
    class   : ^Class,
    super   : ^LoxClass,
    name    : string,
    arity   : int,
    methods : map[string]Callable,
}

new_lox_class :: proc(class: ^Class, super: ^LoxClass, methods: map[string]Callable) -> ^LoxClass {
    result := new(LoxClass)
    result.class   = class
    result.super   = super
    result.name    = fmt.tprintf("<class %s>", class.name.text)
    result.arity   = 0
    result.methods = methods

    init, ok := class_find_initializer(result)
    if ok {
        result.arity = callable_get_arity(init)
    }

    return result
}

class_find_initializer :: proc(class: ^LoxClass) -> (Callable, bool) {
    initToken := Token{
        type = .Identifier,
        text = "init",
    }

    return class_find_method(class, initToken)
}

class_find_method :: proc(class: ^LoxClass, name: Token) -> (Callable, bool) {
    if v, ok := class.methods[name.text]; ok {
        return v, true
    }

    if class.super != nil {
        return class_find_method(class.super, name)
    }

    return Callable{}, false
}

class_new_instance :: proc(class: ^LoxClass, interp: ^Interpreter, arguments: []Value) -> Result{
    instance := new_lox_instance(class)
    init, ok := class_find_initializer(class)
    if ok {
        init = callable_bind(init, instance)
        token := callable_get_token(init)

        callable_call(interp, token, init, arguments)
    }

    return ReturnResult{value=instance}
}

class_get_token :: proc(class: ^LoxClass) -> Token {
    return class.class.name
}

Instance :: struct{
    class  : ^LoxClass,
    name   : string,
    fields : map[string]Value,
}

new_lox_instance :: proc(class: ^LoxClass) -> ^Instance {
    instance := new(Instance)
    instance.class = class
    instance.name  = fmt.tprintf("<instance %v>", class.name)

    return instance
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
