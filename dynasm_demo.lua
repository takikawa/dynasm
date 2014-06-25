io.stdout:setvbuf'no'
io.stderr:setvbuf'no'

local dynasm = require'dynasm'

--load a file manually
local chunk = assert(dynasm.loadfile('dynasm_demo_x86.dasl'))

--run it twice to test the reusability of the dynasm encoder.
chunk()
chunk()

--load the same file as a module, via require()
--dynasm was already used, so we test the reusability of the dynasm parser.
require'dynasm_demo_x86'

--load and run a minimal program from a string
local program = [[

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
ffi.gc(func, function() local _ = buf end) --stick buf to func
return func

]]

local chunk = dynasm.loadstring(program)
local multiply = chunk()
assert(multiply(-7, 5) == -35)


--another example showing how code generation and building could be separated.
local program = [[

local ffi = require'ffi'
local dasm = require'dasm'

|.arch x86
|.section code
|.globals GLOB_
|.actionlist my_actionlist

ffi.cdef[=[
typedef struct {
	int field1;
	int field2;
} foo_t;
]=]

|.type FOO, foo_t, edx

local function gencode(Dst)
	local i = 0
  |->start:
  |  mov esi, [eax+4]
  |  mov esi, FOO->field2
  |  mov esi, FOO:ecx->field2
  for i = 125, 129 do
    |  add esi, [ebx+i]
    |  sub esi, [esp+i]
  end
end

return gencode, my_actionlist

]]

print'-----------------------------------------'
print(dynasm.translate_tostring(dynasm.string_infile(program), {lang = 'lua'}))

print'-----------------------------------------'
local chunk = dynasm.loadstring(program)
local gencode, my_actionlist = chunk()
local dasm = require'dasm'
local Dst = dasm.new(my_actionlist)
gencode(Dst)
local buf, size = Dst:build()
dasm.dump(buf, size)
print''

