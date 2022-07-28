package main

compile :: proc(source: string) {
    scanner: Scanner

    scanner_init(&scanner, source)
    scanner_dump(&scanner)
}
