io.stdout:setvbuf'no'
io.stderr:setvbuf'no'

local dynasm = require'dynasm'
local dasm = require'dasm'

--set the globals returned from the dasl module

local demo, demos, actions, externnames, globalnames, DASM_MAXSECTION, DASM_MAXGLOBAL
local function set_vars(t)
	demo, demos, actions, externnames, globalnames, DASM_MAXSECTION, DASM_MAXGLOBAL = unpack(t)
end

--load dasl files via loadfile() and via require().

--load and run the dasl file from the current directory.
function load_via_loadfile()
	set_vars(assert(dynasm.loadfile'dynasm_demo_x86.dasl')())
end

--load the same file via require() from package.path.
function load_via_require()
	set_vars(require'dynasm_demo_x86')
end

--helpers

local function hr() return ('-'):rep(60) end
local function printf(...) print(string.format(...)) end

--assemble a demo from the dasl file, dump it and run it
local function run_demo(name)
	collectgarbage() --clean up from the last session

	local gencode = demo[name]

	--make a new dasm state
	local state, globals = dasm.new(actions, externnames, DASM_MAXSECTION, DASM_MAXGLOBAL)

	--generate the code and get the test function for that code
	local runcode = gencode(state)

	--build the code
	local buf, size = state:build()

	--show code and size
	printf('%-16s %-10s %s', 'code address', '', tostring(buf))
	printf('%-16s %-10d %s', 'code size', size, 'bytes')

	--show the labels from this code
	for i = 0, #globalnames do --from .globalnames directive
		if globals[i] ~= nil then
			printf('%-16s %-10s %s', 'global', globalnames[i], globals[i])
		end
	end

	--dump the code
	print(hr())
	dasm.dump(buf, size)

	--run the code
	if runcode then
		runcode(buf)
	end
end

--run all demos
local function run_all_demos()
	for i,name in ipairs(demos) do
		print()
		print(name)
		print(hr())
		run_demo(name)
	end
end

local function default()
	load_via_loadfile()
	run_all_demos()
	--we're loading the same file again to test the reusability of dynasm.
	--there's a lot of global state in dynasm which needs to be reset between runs.
	load_via_require()
	run_all_demos()
end

if not ... then
	default()
else
	load_via_require()
	run_demo((...))
end
