--!nocheck
--[[
	Swamp_OpenJunctions.luau — 늪 판자길 갈림목을 막던 난간을 치운다(2026-09-29 사용자: "울타리가 길막을 하고 있어").
	갈림목(BoardwalkJunction) 에서 뻗는 가지의 첫 곧은 판(BoardwalkStraight, 길이 16)이 갈림목 위로 5 쯤 겹쳐 놓여,
	그 판의 밧줄 난간·말뚝이 **본길을 가로질렀다**(보이는 밧줄 + 보이지 않는 Collider_Rail 벽).
	난간 메시는 판 하나에 한 덩어리라 잘라낼 수 없어, 갈림목과 겹치는 곧은 판을 같은 자리의 난간 없는 판(BoardwalkOpen)으로 바꾼다.
	원래 판은 ServerStorage.Swamp_Swapped 로 옮긴다(되돌리기: 그것을 제자리로, 새 판 지우기). 다시 돌려도 된다.
	보고: /open_junctions
]]
local HS = game:GetService("HttpService")
local SS = game:GetService("ServerStorage")
local report = {}

local ok, err = pcall(function()
	local S = workspace.Surface["Swamp2_늪지대"]["판자길"]
	local template
	for _, m in S:GetChildren() do
		if m.Name == "BoardwalkOpen" and not m:GetAttribute("FromStraight") then
			template = m
			break
		end
	end
	assert(template, "난간 없는 판(BoardwalkOpen)이 없다")
	local function floorOf(m)
		for _, p in m:GetChildren() do
			if p:IsA("BasePart") and p.Name == "Collider_Floor" then
				return p
			end
		end
	end
	local junctions = {}
	for _, m in S:GetChildren() do
		if m.Name == "BoardwalkJunction" then
			table.insert(junctions, floorOf(m))
		end
	end
	local keep = SS:FindFirstChild("Swamp_Swapped") or Instance.new("Folder")
	keep.Name = "Swamp_Swapped"
	keep.Parent = SS
	local n = 0
	for _, m in S:GetChildren() do
		if m.Name ~= "BoardwalkStraight" then
			continue
		end
		local f = floorOf(m)
		if not f then
			continue
		end
		-- 갈림목 바닥과 xz 로 1 넘게 겹치면 바꾼다
		local hit = false
		for _, j in junctions do
			local d = (f.Position - j.Position) * Vector3.new(1, 0, 1)
			local ax = f.Size.X / 2 + j.Size.X / 2
			local az = f.Size.Z / 2 + j.Size.Z / 2
			-- 두 판 모두 y 축으로만 돌아 있다: 돌림을 반영한 월드 반폭
			local function half(p)
				local r, l = p.CFrame.RightVector, p.CFrame.LookVector
				return Vector3.new(math.abs(r.X) * p.Size.X / 2 + math.abs(l.X) * p.Size.Z / 2, 0, math.abs(r.Z) * p.Size.X / 2 + math.abs(l.Z) * p.Size.Z / 2)
			end
			local hf, hj = half(f), half(j)
			if math.abs(d.X) < hf.X + hj.X - 1 and math.abs(d.Z) < hf.Z + hj.Z - 1 then
				hit = true
				break
			end
			local _ = ax + az
		end
		if hit then
			local new = template:Clone()
			new:PivotTo(m:GetPivot())
			new:SetAttribute("FromStraight", true)
			new.Parent = S
			local nf = floorOf(new)
			table.insert(report, string.format("바꿈 (%.0f,%.0f) 바닥 %.2f → %.2f", f.Position.X, f.Position.Z, f.Position.Y, nf and nf.Position.Y or -1))
			m.Parent = keep
			n += 1
		end
	end
	table.insert(report, 1, "갈림목 곧은 판 → 난간 없는 판 " .. n)
end)
if not ok then
	table.insert(report, "ERR " .. tostring(err))
end
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/open_junctions", table.concat(report, "\n"))
end)
