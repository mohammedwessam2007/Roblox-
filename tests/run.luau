--!nocheck
-- Test runner: lune run tests/run.luau
local fs = require("@lune/fs")
local process = require("@lune/process")
local Loader = require("./loader")

local T = { passed = 0, failed = 0, failures = {} }
local current = ""

function T.test(name, fn)
	current = name
	local ok, err = pcall(fn)
	if ok then
		T.passed += 1
		print("  PASS " .. name)
	else
		T.failed += 1
		table.insert(T.failures, name .. " :: " .. tostring(err))
		print("  FAIL " .. name .. " :: " .. tostring(err))
	end
end
function T.eq(a, b, msg)
	if a ~= b then
		error(string.format("%s: expected %s, got %s", msg or "eq", tostring(b), tostring(a)), 2)
	end
end
function T.ok(v, msg)
	if not v then
		error(msg or "expected truthy", 2)
	end
end
function T.mod(name)
	return Loader.require("src/shared/" .. name .. ".luau")
end
T.helper = function(name)
	return Loader.require("tests/" .. name .. ".luau")
end
T.fixture = function(name)
	return Loader.require("tests/fixtures/" .. name .. ".luau")
end

local files = {}
for _, f in fs.readDir("tests") do
	if string.match(f, "%.spec%.luau$") then
		table.insert(files, f)
	end
end
table.sort(files)
for _, f in files do
	print("== " .. f)
	local suite = Loader.require("tests/" .. f)
	suite(T)
end
print(string.format("\nRESULT: %d passed, %d failed", T.passed, T.failed))
for _, f in T.failures do
	print("  - " .. f)
end
process.exit(if T.failed == 0 then 0 else 1)
