package main

import "core:fmt"
import "core:os"

main :: proc() {
    if len(os.args) > 2 {
        fmt.println("Usage: olox [script]")
        os.exit(64)
    } else if len(os.args) == 2 {
        runFile(os.args[1])
    } else {
        runPrompt()
    }
}

runFile :: proc(path: string) {
    bytes, ok := os.read_entire_file_from_filename(path)
    if !ok {
        fmt.println("ERROR: reading file:", path)

        return
    }

    run(string(bytes))

    if hadError {
        os.exit(65)
    }
    if hadRuntimeError {
        os.exit(70)
    }
}

runPrompt :: proc() {
    data: [1024]byte;

    for {
        fmt.print("> ")

        if n, _ := os.read(os.stdin, data[:]); n < 0 {
            fmt.println("ERROR: reading input")

            return
        } else {
            run(string(data[:n]))
            hadError = false
        }
    }
}

run :: proc(data: string) {
    scanner := new_scanner(data)

    tokens := scanner_tokens(scanner)
    parser := new_parser(tokens)
    stmts := parser_parse(parser)

    if hadError {
        return
    }

    fmt.println("tokens    :", tokens)
    fmt.println("statements:", stmts)
    interpret(stmts)
}

hadError := false
hadRuntimeError := false

report :: proc(text: string, line := 0, file := "") {
    fmt.fprintf(os.stderr, "ERROR: %s:%d: %s\n", file, line, text)
    hadError = true
}

error :: proc(token: Token, msg: string) {
    if token.type == TokenType.EOF {
        report(line=token.line, file="at end", text=msg)
    } else {
        report(line=token.line, file=fmt.tprintf("at '%s'", token.text), text=msg)
    }
}

runtime_error :: proc(token: Token, msg: string) {
    fmt.fprintf(os.stderr, "ERROR: %d: %s\n", token.line, msg)
    hadRuntimeError = true
}
