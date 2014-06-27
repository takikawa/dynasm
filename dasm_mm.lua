--wrappers around mmap to support dynamic code exection (Cosmin Apreutesei, public domain)
local ffi = require'ffi'
local C = ffi.C

local function checkh(ptr) return assert(ptr ~= nil and ptr) end
local function checkz(ret) assert(ret == 0) end
local function checknz(ret) assert(ret ~= 0) end

local new, free, protect

if ffi.os == 'Windows' then

	ffi.cdef[[
	void* VirtualAlloc(void* lpAddress, size_t dwSize, uint32_t flAllocationType, uint32_t flProtect);
	int VirtualFree(void* lpAddress, size_t dwSize, uint32_t dwFreeType);
	int VirtualProtect(void* lpAddress, size_t dwSize, uint32_t flNewProtect, uint32_t* lpflOldProtect);
	]]

	local PAGE_READWRITE    = 0x04
	local PAGE_EXECUTE_READ = 0x20
	local MEM_COMMIT  = 0x1000
	local MEM_RESERVE = 0x2000
	local MEM_RELEASE = 0x8000

	function new(size)
		return checkh(C.VirtualAlloc(nil, size, bit.bor(MEM_RESERVE, MEM_COMMIT), PAGE_READWRITE))
	end

	function protect(addr, size)
		local oldprotect = ffi.new'uint32_t[1]' --because null not accepted
		checknz(C.VirtualProtect(addr, size, PAGE_EXECUTE_READ, oldprotect))
	end

	function free(addr, size)
		assert(size, 'size required') --on other platforms
		checknz(C.VirtualFree(addr, 0, MEM_RELEASE))
	end

elseif ffi.os == 'Linux' or ffi.os == 'OSX' then

	ffi.cdef[[
	void* mmap(void *addr, size_t length, int prot, int flags, int fd, long int offset);
	int munmap(void *addr, size_t length);
	int mprotect(void *addr, size_t len, int prot);
	]]

	local PROT_READ  = 1
	local PROT_WRITE = 2
	local PROT_EXEC  = 4
	local MAP_PRIVATE   = 2
	local MAP_ANONYMOUS = 0x20

	function new(size)
		return checkh(C.mmap(nil, size, bit.bor(PROT_READ, PROT_WRITE), bit.bor(MAP_PRIVATE, MAP_ANONYMOUS), -1, 0))
	end

	function protect(addr, size)
		checkz(C.mprotect(addr, size, bit.bor(PROT_READ, PROT_EXEC)))
	end

	function free(addr, size)
		checkz(C.munmap(addr, size))
	end

end

local new = function(size) --override for hooking to gc
	local addr = new(size)
	ffi.gc(addr, function(addr)
		ffi.gc(addr, nil)
		free(addr, size)
	end)
	return addr
end

if not ... then
	local function test(size)
		local addr = new(size)
		print(addr)
		addr = ffi.cast('int32_t*', addr)
		assert(addr[0] == 0)
		addr[0] = 1234 --writable
		assert(addr[0] == 1234)
		protect(addr, size)
		--addr[0] = 4321 --uncomment this to get a crash (r/o memory); TODO: test if executable
		--addr = nil; collectgarbage() --enable this to fail the assertion below
		return addr
	end
	local a1 = test(64*1024*1000) --64MB
	local a2 = test(16) --16 bytes
	assert(a1 ~= a2) --different pages
	a1 = nil
	a2 = nil
	collectgarbage() --TODO: test if finalizer was called
end

return {new = new, free = free, protect = protect}

