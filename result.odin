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

ReturnResult :: struct{
    value: Value,
}

