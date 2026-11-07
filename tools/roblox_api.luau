--[[
	roblox_api.luau — Lune 흉내 환경에 "로블록스 공식 API 목록" 검사를 얹는다. (2026-11-07)

	배경: @lune/roblox 는 오래된 반사 데이터라 ReadOnly 속성 쓰기·NumberRange(min>max)·새 클래스를 가려내지 못했다.
	초록불인데 게임이 깨지는 일(UIStroke.LineJoin, NumberRange 순서)을 막으려고 tools/roblox_api/API-Dump.json
	(공식, 없으면 tools/roblox_api/fetch.sh)과 대조한다. 실행 위치는 프로젝트 루트.

	쓰는 법(smoke_director 참고):
	  local ApiCheck = require("../roblox_api")           -- tools/combat 에서
	  ApiCheck.apply(env, roblox)                          -- 스크립트 환경에 Enum·NumberRange·키프레임 검사판을 끼움
	  Instance.new 안에서 ApiCheck.checkClass(class)
	  luau.compile(ApiCheck.rewrite(source))               -- `x.Prop = v` 줄 앞에 쓰기 검사를 끼운다(줄 번호 유지)
	  끝에 #ApiCheck.errors > 0 이면 실패 처리(pcall 이 삼킨 오류도 여기에 남는다)

	잡는 것: 없는 클래스·NotCreatable 클래스 / 없는·ReadOnly·NotScriptable·플러그인 전용 속성 쓰기 /
	         없는 Enum·항목 / NumberRange min>max / 키프레임 시간 0~1 밖 / Sequence 처음≠0·끝≠1·시간 거꾸로.
	못 잡는 것: `a.b.c = v` 같은 한 줄 쓰기 이외 패턴(표 생성자 등)은 정적 검사 tools/check_roblox_api.py 가 본다.
]]
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local ApiCheck = {}
ApiCheck.errors = {} :: { string }
ApiCheck.writes = 0 -- 검사한 Instance 속성 쓰기 수(검사가 실제로 돌았는지 확인용)

local classes: { [string]: any }
local enums: { [string]: { [string]: number } }

local function load()
	if classes then
		return
	end
	local dump = serde.decode("json", fs.readFile("tools/roblox_api/API-Dump.json"))
	classes = {}
	for _, c in dump.Classes do
		local info = { Super = c.Superclass, Props = {}, Other = {}, Tags = {} }
		for _, t in c.Tags or {} do
			info.Tags[t] = true
		end
		for _, m in c.Members do
			if m.MemberType == "Property" then
				local tags = {}
				for _, t in m.Tags or {} do
					tags[t] = true
				end
				info.Props[m.Name] = { ReadOnly = tags.ReadOnly, NotScriptable = tags.NotScriptable, Write = m.Security and m.Security.Write or "None" }
			else
				info.Other[m.Name] = m.MemberType
			end
		end
		classes[c.Name] = info
	end
	enums = {}
	for _, e in dump.Enums do
		local items = {}
		for _, it in e.Items do
			items[it.Name] = it.Value
		end
		enums[e.Name] = items
	end
	-- 덤프에 없지만 스튜디오에 있는 항목(extra.json)
	local extra = serde.decode("json", fs.readFile("tools/roblox_api/extra.json"))
	for enumName, list in extra.EnumItems or {} do
		enums[enumName] = enums[enumName] or {}
		for _, item in list do
			enums[enumName][item] = enums[enumName][item] or -1
		end
	end
end

-- 오류를 기록하고 던진다. level = 스크립트 줄이 있는 스택 층(report 를 부른 쪽 기준 +1)
local function report(msg: string, level: number)
	load()
	local src, line = debug.info(level + 1, "sl")
	local where = if src then string.format(" [%s:%s]", tostring(src), tostring(line)) else ""
	local full = msg .. where
	if not table.find(ApiCheck.errors, full) then
		table.insert(ApiCheck.errors, full)
	end
	error(full .. "\n" .. debug.traceback("", level + 1), 0)
end

local function findProp(class: string, prop: string): (any?, string?)
	local c = class
	while c do
		local info = classes[c]
		if not info then
			return nil, nil
		end
		if info.Props[prop] then
			return info.Props[prop], nil
		end
		if info.Other[prop] then
			return nil, info.Other[prop]
		end
		c = info.Super
	end
	return nil, nil
end

-- Instance.new 흉내 안에서 부른다(스크립트 줄이 한 층 위라 level 3)
function ApiCheck.checkClass(class: string)
	load()
	local info = classes[class]
	if not info then
		report("Instance.new: 로블록스에 없는 클래스 '" .. tostring(class) .. "'", 3)
	elseif info.Tags.NotCreatable then
		report("Instance.new: '" .. class .. "' 는 만들 수 없는 클래스(NotCreatable)", 3)
	end
end

-- 재작성된 `x.Prop = v` 줄 앞에서 불린다.
function ApiCheck.write(obj: any, prop: any)
	if typeof(obj) ~= "Instance" or type(prop) ~= "string" then
		return
	end
	load()
	ApiCheck.writes += 1
	local class = obj.ClassName
	local info, other = findProp(class, prop)
	if other then
		report(string.format("%s.%s 는 속성이 아니라 %s", class, prop, other), 2)
	elseif not info then
		if classes[class] then
			report(string.format("%s 에 없는 속성 '%s' 쓰기", class, prop), 2)
		end
	elseif info.ReadOnly then
		report(string.format("%s.%s 는 읽기 전용(ReadOnly)", class, prop), 2)
	elseif info.NotScriptable then
		report(string.format("%s.%s 는 스크립트에서 못 건드림(NotScriptable)", class, prop), 2)
	elseif info.Write ~= "None" then
		report(string.format("%s.%s 는 %s 전용이라 게임 스크립트가 못 씀", class, prop, info.Write), 2)
	end
end

--[[
	소스 재작성: 줄 맨 앞의 `a.b.Prop = v` · `a[key] = v` · `(a :: any)[key] = v` 앞에 ApiCheck.write 호출을 끼운다.
	한 줄 안에서만 끼우므로 줄 번호가 그대로다. 표(table)에 쓰는 줄도 걸리지만 write 가 Instance 만 본다.
]]
function ApiCheck.rewrite(source: string): string
	local out = {}
	for line in (source .. "\n"):gmatch("(.-)\n") do
		local indent, obj, prop, eq = line:match("^(%s*)([%a_][%w_%.]*)%.([%a_][%w_]*)%s*=(.?)")
		local keyExpr
		if indent and eq ~= "=" then
			keyExpr = string.format("%q", prop)
		else
			indent, obj, prop, eq = line:match("^(%s*)%(([%a_][%w_%.]*)%s*::%s*any%)%[([%a_][%w_]*)%]%s*=(.?)")
			if not indent then
				indent, obj, prop, eq = line:match("^(%s*)([%a_][%w_%.]*)%[([%a_][%w_]*)%]%s*=(.?)")
			end
			if indent and eq ~= "=" then
				keyExpr = prop
			else
				obj = nil
			end
		end
		if obj then
			line = indent .. "__apiw(" .. obj .. ", " .. keyExpr .. "); " .. line:sub(#indent + 1)
		end
		table.insert(out, line)
	end
	return table.concat(out, "\n")
end

--=== Enum ===--
local function makeEnum(roblox: any)
	local function enumItems(name: string)
		local real
		pcall(function()
			real = roblox.Enum[name]
		end)
		return setmetatable({}, {
			__index = function(_, item: string)
				if item == "GetEnumItems" or item == "Name" then
					return function(_, ...)
						return real[item](real, ...)
					end
				end
				local value = enums[name][item]
				if not value then
					report(string.format("Enum.%s.%s: 로블록스에 없는 항목", name, tostring(item)), 2)
				end
				local ok, found = pcall(function()
					return real[item]
				end)
				if ok then
					return found
				end
				return { Name = item, Value = value, EnumType = name } -- Lune 반사 데이터에 없는 새 항목의 자리표시
			end,
		})
	end
	local cache = {}
	return setmetatable({}, {
		__index = function(_, name: string)
			if not enums[name] then
				report("Enum." .. tostring(name) .. ": 로블록스에 없는 Enum", 2)
			end
			if not cache[name] then
				cache[name] = enumItems(name)
			end
			return cache[name]
		end,
	})
end

--=== 숫자·색 시퀀스 ===--
local function checkKeypoint(what: string, t: any)
	if type(t) ~= "number" or t < 0 or t > 1 then
		report(what .. ": 시간은 0~1 이어야 함 — " .. tostring(t), 3)
	end
end

local function checkSequence(what: string, points: any)
	if #points < 2 then
		report(what .. ": 키포인트가 2개 미만", 3)
	end
	local prev = -1
	for i, kp in points do
		if i == 1 and kp.Time ~= 0 then
			report(what .. ": 첫 키포인트 시간이 0이 아님 — " .. kp.Time, 3)
		end
		if kp.Time < prev then
			report(what .. ": 키포인트 시간이 거꾸로 — " .. prev .. " 다음 " .. kp.Time, 3)
		end
		prev = kp.Time
		if i == #points and kp.Time ~= 1 then
			report(what .. ": 마지막 키포인트 시간이 1이 아님 — " .. kp.Time, 3)
		end
	end
end

-- env 에 검사판을 끼운다. roblox = require("@lune/roblox")
function ApiCheck.apply(env: any, roblox: any)
	load()
	env.__apiw = ApiCheck.write
	env.Enum = makeEnum(roblox)
	env.NumberRange = {
		new = function(...)
			local n, a, b = select("#", ...), ...
			if n >= 2 and type(a) == "number" and type(b) == "number" and a > b then
				report(string.format("NumberRange.new(%s, %s): min 이 max 보다 큼", a, b), 2)
			end
			return roblox.NumberRange.new(...)
		end,
	}
	for _, kind in { "NumberSequence", "ColorSequence" } do
		local real = roblox[kind]
		local realKp = roblox[kind .. "Keypoint"]
		env[kind .. "Keypoint"] = {
			new = function(t, ...)
				checkKeypoint(kind .. "Keypoint.new", t)
				return realKp.new(t, ...)
			end,
		}
		env[kind] = {
			new = function(...)
				local first = ...
				if type(first) == "table" then
					checkSequence(kind .. ".new", first)
				end
				return real.new(...)
			end,
		}
	end
end

return ApiCheck
