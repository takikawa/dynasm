---
project: dynasm
tagline: DynASM with Lua mode
---

## `local dynasm = require'dynasm'`

Jump To: [Features](#features) | [Examples](#examples) | [DynASM API](#dynasm-api) |
	[DASM API](#dasm-api) | [Changes to DynASM](#changes-to-dynasm) | [DynASM Reference](#dynasm-reference-tutorials)


This is a modified version of [DynASM](http://luajit.org/dynasm.html) that allows generating,
compiling, and running x86 and x86-64 assembly code directly from Lua. It also exposes the DynASM translator
and linker to be used as Lua modules.

> If you want to learn more about DynASM, look [below](#dynasm-reference-tutorials) for some fine learning material. \
> If you want to know how this differs from the original DynASM, look [below](#changes-to-dynasm) for the list of changes.

## Features

  * translate, compile and run Lua/ASM code from Lua (no C glue)
  * load Lua/ASM (.dasl) files with `require()`
  * translate from file/string/stream inputs to file/string/stream outputs

## Examples

Before you start:

  * `dynasm.lua` is the Lua part of dynasm (the translator).
  * `dasm.lua` is the binding to the C part of DynASM (the linker/encoder).
  * `.dasl` files refer to Lua/ASM files, `.dasc` files refer to Lua/C files.

Ok, let's see some samples.

### 1. Self-contained module:

#### `multiply_x86.dasl:`

~~~{.lua}
local ffi = require'ffi'               --required
local dasm = require'dasm'             --required

|.arch x86                             --must be the first instruction
|.actionlist actions                   --make an action list called `actions`

local Dst = dasm.new(actions)          --make a dasm state; next chunk will generate `dasm.put(Dst, ...)`

|  mov eax, [esp+4]
|  imul dword [esp+8]
|  ret

local code = Dst:build()               --check, link and encode the code
local fptr = ffi.cast('int32_t __cdecl (*) (int32_t x, int32_t y)', code) --take a callable pointer to it

return function(x, y)
	local _ = code                      --pin the code buffer so it doesn't get collected
	return fptr(x, y)
end
~~~

#### `main.lua`:

~~~{.lua}
require'dynasm'                           --hook in the `require` loader for .dasl files
local multiply = require'multiply_x86'    --load, translate and run `multiply_x86.dasl`
assert(multiply(-7, 5) == -35)
~~~

### 2. Code gen / build split:

Here's an idea on how you can keep your asm code separated from the plumbing required to build it,
and also how you can make separate functions out of different asm chunks from the same dasl file.

#### `funcs_x86.dasl`:

~~~{.lua}
local ffi = require'ffi'
local dasm = require'dasm'

|.arch x86
|.actionlist actions
|.globalnames globalnames

local gen = {}

function gen.mul(Dst)                  --function which generates code into the dynasm state called `Dst`
   |->mul:                             --and returns a "make" function which gets a dasm.globals() map
   |  mov eax, [esp+4]                 --and returns a function that knows how to call into its code.
   |  imul dword [esp+8]
   |  ret
   return function(globals)
     return ffi.cast('int32_t __cdecl (*) (int32_t x, int32_t y)', globals.mul)
   end
end

function gen.add(Dst)
   |->add:
   |  mov eax, [esp+4]
   |  add eax, dword [esp+8]
   |  ret
   return function(globals)
     return ffi.cast('int32_t __cdecl (*) (int32_t x, int32_t y)', globals.add)
   end
end

return {gen = gen, actions = actions, globalnames = globalnames}
]]
~~~

#### `funcs.lua`:

~~~{.lua}
local dynasm = require'dynasm'
local dasm   = require'dasm'
local funcs  = require'funcs_x86'

local state, globals = dasm.new(funcs.actions)     --create a dynasm state with the generated action list

local M = {}                                       --generate the code, collecting the make functions
for name, gen in pairs(funcs.gen) do
   M[name] = gen(state)
end

local buf, size = state:build()                    --check, link and encode the code
local globals = dasm.globals(globals, funcs.globalnames)   --get the map of global_name -> global_addr

for name, make in pairs(M) do                      --make the callable functions
   M[name] = make(globals)
end

M.__buf = buf                                      --pin buf so it doesn't get collected

return M
~~~

#### `main.lua`

~~~{.lua}
local funcs = require'funcs'

assert(funcs.mul(-7, 5) == -35)
assert(funcs.add(-7, 5) == -2)
~~~

### 3. Translate to stdout from Lua:

~~~{.lua}
local dynasm = require'dynasm'
print(dynasm.translate_tostring'multiply_x86.dasl')
~~~

The above is equivalent to the command line

	> lua dynasm.lua multilpy_x86.dasl

### 4. Load from string:

~~~{.lua}
local dynasm = require'dynasm'

local gencode, actions = dynasm.loadstring([[
local ffi  = require'ffi'
local dasm = require'dasm'

|.arch x86
|.actionlist actions

local function gencode(Dst)
	|  mov ax, bx
end

return gencode, actions
]])()
~~~

### 5. Included demo/tutorial

Check out the included [dynasm_demo_x86.dasl] and [dynasm_demo.lua] files for more in-depth knowledge
about DynASM/Lua interaction.

[dynasm_demo.lua]:      https://github.com/luapower/dynasm/blob/master/dynasm_demo.lua
[dynasm_demo_x86.dasl]: https://github.com/luapower/dynasm/blob/master/dynasm_demo_x86.dasl


## DynASM API

----------------------------------------------------- --------------------------------------------------
__hi-level__

dynasm.loadfile(infile[, opt]) -> chunk					load a dasl file and return it as a Lua chunk

dynasm.loadstring(s[, opt]) -> chunk						load a dasl string and return it as a Lua chunk

__low-level__

dynasm.translate(infile, outfile[, opt])					translate a dasc or dasl file

dynasm.string_infile(s) -> infile							use a string as an infile to translate()

dynasm.func_outfile(func) -> outfile						make an outfile that calls func(s) for each piece

dynasm.table_outfile(t) -> outfile							make an outfile that writes pieces to a table

dynasm.translate_tostring(infile[, opt]) -> s			translate to a string

dynasm.translate_toiter(infile[, opt]) -> iter() -> s	translate to an iterator of string pieces
----------------------------------------------------- --------------------------------------------------


## DASM API

----------------------------------------------------- --------------------------------------------------
__hi-level__

dasm.new(\                                            make a dasm state for an action list. \
	actionlist, \                                      -> per `.actionlist` directive. \
	[externnames], \												-> per `.externnames` directive. \
   [sectioncount], \												-> DASM_MAXSECTION from `.sections` directive. \
 	[globalcount],	\												-> DASM_MAXGLOBAL from `.globals` directive. \
	[externget], \													-> `func(externname) -> addr`, for solving `extern`s \
	[globals]) -> state, globals								-> `void*[DASM_MAXGLOBAL]`, to hold globals

local buf, size = state:build()								check, link, alloc, encode and mprotect the code

__low-level__

state:init(maxsection)											init a state

state:free()														free the state

state:setupglobal(globals, globalcount)					set up the globals buffer

state:growpc(maxpc)												grow the number of available pc labels

state:setup(actionlist)											set up the state with an action list

state:put(state, ...)											the translator generates these calls

state:link() -> size												link the code and get its size

state:encode(buf)													encode the code into a buffer

state:getpclabel(pclabel)										get pc label offset

state:checkstep(secmatch)										check code before encoding

state:setupextern(externnames, getter)						set up a new `extern` handler
----------------------------------------------------- --------------------------------------------------


## Changes to DynASM

The [source code changes] made to DynASM were kept to a minimum to preserve DynASM semantics,
and to make it easy to add the Lua mode to other architectures supported by DynASM.
As for the user-facing changes, the list is again small:

  * added `-l, --lang C|Lua` command line option (set automatically for dasl and dasc files).
  * comments in asm lines can start with both `--` and `//` in Lua mode.
  * defines ARCH, OS, X86, X64, WINDOWS, LINUX, OSX are predefined in Lua mode.
  * the `.globals` directive also generates DASM_MAXGLOBAL.

[source code changes]: https://github.com/luapower/dynasm/compare/7d7e130...master


## DynASM Reference & Tutorials

Peter Cawley > [Intro](http://corsix.github.io/dynasm-doc/index.html),
[Tutorial](http://corsix.github.io/dynasm-doc/tutorial.html),
[Reference](http://corsix.github.io/dynasm-doc/reference.html),
[Instructions](http://corsix.github.io/dynasm-doc/instructions.html) \
Josh Haberman > [Tutorial](http://blog.reverberate.org/2012/12/hello-jit-world-joy-of-simple-jits.html) \
Mike Pall > [Intro](http://luajit.org/dynasm.html), [Features](http://luajit.org/dynasm_features.html),
[Examples](http://luajit.org/dynasm_examples.html)

