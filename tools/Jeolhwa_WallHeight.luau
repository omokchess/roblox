--!nocheck
--[[
	Jeolhwa_WallHeight.luau — 절화 담장을 키운다(2026-09-29 사용자: "절화의 경우 담장이 플레이어 크기랑 비슷함").
	잰 높이: 궁·마을 담(Wall_Segment) 8.6, 돌담(Wall_Stone) 6.5, 싸리 울타리(Fence_Brush) 4.8, 담 문(Wall_GateTile) 12.6.
	캐릭터가 약 5 라 돌담·울타리는 정말 사람 키였다. 세로만 배율대로 늘린다(가로·두께 그대로).
	기준은 그 담의 바닥선(기단 Foundation 을 뺀 가장 낮은 면) — 비탈의 기단은 그대로 두고 그 위만 자란다.
	놓인 것(Workspace.Jeolhwa)과 틀(ServerStorage.JeolhwaKit) 둘 다 늘린다 — 틀도 늘려야 Jeolhwa_City3 로 다시 지어도 유지된다.
	한 번 늘린 모델엔 속성 HeightScaled 가 붙어 다시 돌려도 두 번 늘지 않는다. 보고: /jwall_height
]]
local HS = game:GetService("HttpService")
local SCALE = { Wall_Segment = 1.55, Wall_Stone = 1.5, Fence_Brush = 1.35, Wall_GateTile = 1.5 }

local report = {}
local function say(f, ...)
	report[#report + 1] = string.format(f, ...)
end

-- 파트의 세로 반높이(월드)
local function halfY(p)
	local cf, s = p.CFrame, p.Size / 2
	return math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z
end

local function grow(m, f)
	local parts = {}
	local base = math.huge
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "Foundation" then
			parts[#parts + 1] = p
			base = math.min(base, p.Position.Y - halfY(p))
		end
	end
	for _, p in ipairs(parts) do
		local cf = p.CFrame
		-- 월드 위(Y)와 가장 나란한 로컬 축의 크기를 늘린다
		local ay = { math.abs(cf.RightVector.Y), math.abs(cf.UpVector.Y), math.abs(cf.LookVector.Y) }
		local s = p.Size
		if ay[1] >= ay[2] and ay[1] >= ay[3] then
			s = Vector3.new(s.X * f, s.Y, s.Z)
		elseif ay[2] >= ay[3] then
			s = Vector3.new(s.X, s.Y * f, s.Z)
		else
			s = Vector3.new(s.X, s.Y, s.Z * f)
		end
		local pos = p.Position
		p.Size = s
		p.CFrame = CFrame.new(pos.X, base + (pos.Y - base) * f, pos.Z) * cf.Rotation
	end
	m:SetAttribute("HeightScaled", f)
	return #parts
end

local ok, err = pcall(function()
	local counts = {}
	local function walk(root, label)
		for _, m in ipairs(root:GetDescendants()) do
			if m:IsA("Model") then
				local kind = string.gsub(m.Name, "_%d+_%d+$", "")
				local f = SCALE[kind]
				if f and not m:GetAttribute("HeightScaled") then
					grow(m, f)
					counts[label .. " " .. kind] = (counts[label .. " " .. kind] or 0) + 1
				end
			end
		end
	end
	walk(workspace.Jeolhwa, "놓인")
	local kit = game:GetService("ServerStorage"):FindFirstChild("JeolhwaKit")
	if kit then
		walk(kit, "틀")
	end
	local keys = {}
	for k in pairs(counts) do
		keys[#keys + 1] = k
	end
	table.sort(keys)
	for _, k in ipairs(keys) do
		say("%s %d", k, counts[k])
	end
end)
if not ok then
	say("ERR %s", tostring(err))
end
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/jwall_height", table.concat(report, "\n"))
end)
