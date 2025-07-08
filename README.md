### Introduction
This project is a compiler to compile C language to 64-bit RISC-V assemble code.

This compiler support following feature:
- use `void codegen()` as main.
- two special functions:
  - `digitalWrite(pin, value)`
    - `pin`: an integer
    - `value`: `HIGH` (1) or `LOW` (0)
  - `delay(ms)`
    - `ms`: an integer
    - Sleep for the specified time
  - arguments follow RISC-V calling convention (in a0, a1 registers)
- Arithmetic Expression: `+`, `-`,`*`, `/`
- single-level pointer
- branching/loop statements:
  - IF / IF-ELSE Statement
  - SWITCH Statement
  - WHILE Statement
  - FOR Statement
- 1D array
- generic function invocations with the RISC-V calling convention

### How to use
- **Setup**: `make codegen`
- **compile code**: `./codegen < {code}`
