------------------------------------------------------------------------------
-- DynASM x64 module.
--
-- Copyright (C) 2005-2014 Mike Pall. All rights reserved.
-- See dynasm.lua for full copyright notice.
------------------------------------------------------------------------------
-- This module just sets 64 bit mode for the combined x86/x64 module.
-- All the interesting stuff is there.
------------------------------------------------------------------------------

assert(package.loaded.dasm_x86 == nil) --can't have it both loaded

x64 = true -- Using a global is an ugly, but effective solution.
return require("dasm_x86")
