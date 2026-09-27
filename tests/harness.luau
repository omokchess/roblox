--!nocheck
-- Lune 테스트 하네스: Roblox 스타일 모듈(script.Parent / WaitForChild / require)을 파일 경로로 흉내 내어 실행
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local H = {}

local SRC = "src"
local nodes = {}
local cache = {}

-- 메타메서드 안에서는 yield(비동기 fs)할 수 없으므로 파일 트리를 미리 스캔
local FILES, DIRS = {}, {}
local function scan(dir)
	DIRS[dir] = true
	for _, name in fs.readDir(dir) do
		local p = dir .. "/" .. name
		if fs.isDir(p) then
			scan(p)
		else
			FILES[p] = true
		end
	end
end
scan(SRC)

local function nodeFor(path: string, isFile: boolean)
	local key = path
	if nodes[key] then
		return nodes[key]
	end
	local node = { __path = path, __file = isFile }
	local name = string.match(path, "([^/]+)$") or path
	name = string.gsub(name, "%.luau$", "")
	name = string.gsub(name, "%.server$", "")
	name = string.gsub(name, "%.client$", "")
	node.Name = name
	setmetatable(node, {
		__index = function(self, k)
			if k == "Parent" then
				local parent = string.match(path, "^(.*)/[^/]+$")
				return parent and nodeFor(parent, false) or nil
			end
			local child = H.child(self, k)
			if child then
				return child
			end
			return nil
		end,
		__tostring = function()
			return "Node(" .. path .. ")"
		end,
	})
	node.WaitForChild = function(self, n)
		local c = H.child(self, n)
		assert(c, "WaitForChild failed: " .. path .. "/" .. n)
		return c
	end
	node.FindFirstChild = function(self, n)
		return H.child(self, n)
	end
	node.IsA = function()
		return false
	end
	node.GetAttribute = function()
		return nil
	end
	nodes[key] = node
	return node
end

function H.child(node, name)
	local base = node.__path
	if node.__file then
		return nil
	end
	for _, ext in { ".luau", ".lua" } do
		if FILES[base .. "/" .. name .. ext] then
			return nodeFor(base .. "/" .. name .. ext, true)
		end
	end
	if DIRS[base .. "/" .. name] then
		return nodeFor(base .. "/" .. name, false)
	end
	return nil
end

H.serverTime = 0

local services = {
	ReplicatedStorage = nodeFor(SRC .. "/ReplicatedStorage", false),
	ServerStorage = nodeFor(SRC .. "/ServerStorage", false),
	RunService = {
		IsServer = function()
			return true
		end,
		IsClient = function()
			return false
		end,
		IsRunning = function()
			return false
		end,
		IsStudio = function()
			return true
		end,
	},
	Workspace = {
		GetServerTimeNow = function()
			return H.serverTime
		end,
		GetAttribute = function()
			return nil
		end,
	},
}

local game = {
	GetService = function(_, n)
		return services[n] or error("service stub missing: " .. n)
	end,
}

local function makeEnv(scriptNode)
	local env = {
		script = scriptNode,
		game = game,
		workspace = services.Workspace,
		require = function(target)
			return H.require(target)
		end,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		Region3 = roblox.Region3,
		NumberRange = roblox.NumberRange,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		ColorSequence = roblox.ColorSequence,
		UDim2 = roblox.UDim2,
		UDim = roblox.UDim,
		Enum = roblox.Enum,
		Random = roblox.Random,
		task = task,
	}
	return env
end

function H.require(target)
	if type(target) == "string" then
		target = nodeFor(target, true)
	end
	local path = target.__path
	if cache[path] ~= nil then
		return cache[path]
	end
	local src = fs.readFile(path)
	local fn = luau.load(src, { debugName = path, environment = makeEnv(target) })
	local result = fn()
	cache[path] = result
	return result
end

function H.node(path)
	return nodeFor(path, FILES[path] == true)
end

-- 간단한 단언/리포트
local passed, failed = 0, 0
function H.check(name, cond, detail)
	if cond then
		passed += 1
		print("  ✔ " .. name)
	else
		failed += 1
		print("  ✘ " .. name .. (detail and ("  — " .. tostring(detail)) or ""))
	end
end
function H.near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-6)
end
function H.summary()
	print(string.format("\n결과: %d 통과, %d 실패", passed, failed))
	return failed
end

return H
