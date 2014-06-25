---
project: dynasm
tagline: DynASM with Lua mode
---

## `local dynasm = require'dynasm'`

This is a [modified] version of [DynASM](http://luajit.org/dynasm.html) that allows generating, compiling, and running
x86 and x86-64 assembly code directly from Lua. It also exposes the DynASM translator and linker to be used as Lua modules.

> If you want to learn more about DynASM, look [below](#dynasm-reference-tutorials) for some fine material.

## Features

  * translate, compile and run Lua/ASM code from Lua (no C glue)
  * load Lua/ASM (.dasl) files with `require()`
  * translate from file/string/stream inputs to file/string/stream outputs

## Before you start

  * the `dynasm` module is the dynasm translator and it's written in Lua.
  * the `dasm` module is the encoder/linker and it's a binding to the C part of DynASM.
  * `.dasl` files refer to Lua/ASM files, `.dasc` files refer to Lua/C files.

## Changes made to DynASM

The

  * `-l, --lang C|Lua` option was added to the command-line interface.

## DynASM + Lua HOWTO

### Load and run a program from a string:

~~~{.lua}
local dynasm = require'dynasm'         --load the translator

local program = [[
local ffi = require'ffi'               --load the ffi as `ffi`: the generated code references it
local dasm = require'dasm'             --load the linker/encoder as `dasm`: the generated code references it

|.arch x86                             --must be the first instruction
|.actionlist actions                   --make an action list for emmitting code

local Dst, globals = dasm.new(actions) --create a new dynasm state using actions per `.actionlist` directive

|->main:
|  mov eax, [esp+4]
|  imul dword [esp+8]
|  ret

local buf, size = Dst:build()          --check, link and encode the code
local main = globals[0]                --`main` is the first and only global label, here the same as `buf`
local func = ffi.cast('int32_t __cdecl (*) (int32_t x, int32_t y)', main) --get a callable pointer to it
return buf, size, func                 --return the code, its size and the callable pointer
]]

local chunk = dynasm.loadstring(program)  --like Lua's loadstring()
local code, codesize, multiply = chunk()  --run the Lua chunk
assert(multiply(-7, 5) == -35)            --call into the built program
~~~

### Load and run the same program from a file:

#### `multiply.dasl:`

~~~{.lua}
local ffi = require'ffi'
local dasm = require'dasm'

|.arch x86
|.actionlist actions

local Dst = dasm.new(actions)

|  mov eax, [esp+4]
|  imul dword [esp+8]
|  ret

local buf, size = Dst:build()
local func = ffi.cast('int32_t __cdecl (*) (int32_t x, int32_t y)', buf)
return {call = func, code = buf, codesize = size}
~~~

#### `main.lua`:

~~~{.lua}
require'dynasm'                           --register the `require` loader for .dasl files
local multiply = require'multiply'        --load, translate and run `multiply.dasl`
assert(multiply.call(-7, 5) == -35)       --call into the built program
~~~

### Translate to stdout from Lua:

~~~{.lua}
local require'dynasm'
print(dynasm.translate_tostring'multiply.dasl')
~~~

### Translate to stdout from the command-line:

	luajit dynasm.lua multiply.dasl

## Gotchas and Limitations

1. All dynamic values are sent to the linker/encoder as int32 values, which means that uint32
values need to be normalized to int32 using `bit.tobit()`.

2. Once you called `.arch` with some value, you can't call `.arch` again with a different value,
not even on separate invocations of the translator.


## DynASM (aka translator) API

## `local dynasm = require'dynasm'`

----------------------------------------------------- --------------------------------------------------
__hi-level__

dynasm.loadfile(infile[, opt]) -> chunk					load a dasl file and return it as a Lua chunk

dynasm.loadstring(s[, opt]) -> chunk						load a dasl string and return it as a Lua chunk

__low-level__

dynasm.translate(infile, outfile[, opt])					ranslate a dasc or dasl file

dynasm.string_infile(s) -> infile							use a string as an infile to translate()

dynasm.func_outfile(func) -> outfile						make an outfile that calls func(s) for each piece

dynasm.table_outfile(t) -> outfile							make an outfile that writes pieces to a table

dynasm.translate_tostring(infile[, opt]) -> s			translate to a string

dynasm.translate_toiter(infile[, opt]) -> iter() -> s	translate to an iterator of string pieces
----------------------------------------------------- --------------------------------------------------

## DASM (aka linker/encoder) API

## `local dasm = require'dasm'`

----------------------------------------------------- --------------------------------------------------
__hi-level__

dasm.new(actionlist, [externnames], \						make a dasm state to be used as `Dst`
   [sectioncount], [globalcount], [externget], \
	[globals]) -> state, globals

local buf, size = state:build()								check, link and encode the code

__low-level__

state:init()

state:free()

state:setupglobal()

state:growpc()

state:setup()

state:put(state, ...)											the translator generates these calls

state:link() -> size												link the code

state:encode()

state:getpclabel()

state:checkstep()

state:setupextern()
----------------------------------------------------- --------------------------------------------------


## DynASM Reference & Tutorials

Peter Cawley > [Intro](http://corsix.github.io/dynasm-doc/index.html),
[Tutorial](http://corsix.github.io/dynasm-doc/tutorial.html),
[Reference](http://corsix.github.io/dynasm-doc/reference.html),
[Instructions](http://corsix.github.io/dynasm-doc/instructions.html) \
Josh Haberman > [Tutorial](http://blog.reverberate.org/2012/12/hello-jit-world-joy-of-simple-jits.html) \
Mike Pall > [Intro](http://luajit.org/dynasm.html), [Features](http://luajit.org/dynasm_features.html),
[Examples](http://luajit.org/dynasm_examples.html)

[modified]: https://github.com/luapower/dynasm/commit/7b00676a717eaf1199c5acc69698b0259ec5c7b6

