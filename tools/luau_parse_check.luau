local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
for _, path in process.args do
	local ok, err = pcall(luau.compile, fs.readFile(path))
	print(path, ok and "OK" or ("FAIL " .. tostring(err)))
end
