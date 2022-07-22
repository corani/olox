package main

Result :: union{
    OkResult,
    ErrorResult,
    ReturnResult,
}

OkResult :: struct{}

ErrorResult :: struct{
    text: string,
}

// Used to unwind the stack during early returns.
ReturnResult :: struct{
    value: Value,
}

