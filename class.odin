package main

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
}

new_lox_instance :: proc(class: ^Class) -> Value {
    instance : Value = Instance{
        class=class,
    }

    return instance
}
