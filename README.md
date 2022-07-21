# Olox

The [Lox](https://craftinginterpreters.com/) interpreter in [Odin](https://odin-lang.org/).

Disclaimer: I started on this knowing absolutely nothing about Odin and am using this project
as a way to get to know the language.

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

## TODO

Look at subtype polymorphism and vtables
