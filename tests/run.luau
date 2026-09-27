--!nocheck
-- 모든 테스트 실행:  lune run tests/run.luau
-- (Lune 의 비동기 파일 읽기는 pcall 경계를 넘어 yield 할 수 없으므로 테스트는 순차 직접 호출)
local process = require("@lune/process")
local fs = require("@lune/fs")
local H = require("./harness")
local files = {}
for _, f in fs.readDir("tests") do
	if string.match(f, "^test_.*%.luau$") then
		table.insert(files, f)
	end
end
table.sort(files)
for _, f in files do
	print("▶ " .. f)
	local mod = require("./" .. string.gsub(f, "%.luau$", ""))
	mod(H)
end
process.exit(H.summary() > 0 and 1 or 0)
