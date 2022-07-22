# Olox

The [Lox](https://craftinginterpreters.com/) interpreter in [Odin](https://odin-lang.org/).

The repo for the "Crafting Interpreters" book can be found here: https://github.com/munificent/craftinginterpreters

Disclaimer: I started on this knowing absolutely nothing about Odin and am using this project
as a way to get to know the language. The implementation therefor is definitely not idiomatic
Odin, and probably very inefficient and "ugly".

If you're an Odin expert, feel free to point out what could be done better!

## Setup

Make sure you have llvm and clang installed. I had to do the following to get it to work properly:

```bash
$ sudo apt install llvm-11 clang-11
$ sudo update-alternatives --install /usr/bin/clang clang /usr/bin/clang-11 100
$ sudo update-alternatives --install /usr/bin/llvm-config llvm-config /usr/bin/llvm-config-11 100
```

Install Odin from source:

```bash
$ git clone https://github.com/odin-lang/Odin
$ cd Odin
$ make
```

Make sure to add the `Odin` folder to your path (or *symlink* the Odin executable from a location
in your path).

## Compile and run

```bash
$ ./build.sh 
$ bin/olox examples/fix.lox
```

## TODO

Look at subtype polymorphism and vtables
