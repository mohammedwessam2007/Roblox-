--!nocheck
-- Loads Roblox-style ModuleScripts (which use `require(script.Parent.X)`) under Lune by
-- giving each module a fake `script` whose Parent resolves sibling files on disk.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local cache = {}
local Loader = {}

local function dirRef(dir)
	-- built eagerly: Lune fs calls may yield, which is illegal inside metamethods
	local t = {}
	for _, name in fs.readDir(dir) do
		local p = dir .. "/" .. name
		if fs.isDir(p) then
			t[name] = dirRef(p)
		elseif string.match(name, "%.luau$") then
			t[string.gsub(name, "%.luau$", "")] = { __module = p }
		end
	end
	return t
end

function Loader.require(ref)
	local path = if type(ref) == "string" then ref else ref.__module
	if cache[path] ~= nil then
		return cache[path]
	end
	local dir = string.match(path, "^(.*)/[^/]+$")
	local env = { script = { Parent = dirRef(dir), Name = path }, require = Loader.require }
	local fn = luau.load(fs.readFile(path), { debugName = path, environment = env })
	local result = fn()
	cache[path] = result
	return result
end

function Loader.reset()
	table.clear(cache)
end

return Loader
