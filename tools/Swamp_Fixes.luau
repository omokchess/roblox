--!nocheck
--[[
	Swamp_Fixes.luau — 늪 눈높이 점검에서 나온 것 고치기(2026-09-29 사용자: "우물엔 구멍이 나 있고" 등).
	다시 돌려도 된다(앞서 넣은 것을 지우고 다시 넣는다).

	1. 우물 셋: 돌 고리 윗단에 돌이 빠진 틈으로 속이 비치고, 물판이 얇은 반투명이라 바로 밑 땅이 보여 "구멍"처럼 보였다.
	   → 고리 안쪽에 돌 고리 한 겹(16 토막, 윗면은 원래 돌 윗면보다 조금 낮게)과 물 밑 어두운 물기둥을 넣는다(폴더 WellFix).
	2. 수상가옥 B2 1층 앞벽 그물의 부표 셋이 벽 바깥(-0.33)에 달려 집 밖에 떠 보였다
	   → 그물 판을 거울삼아 방 쪽으로 뒤집어 옮긴다(원본 tools/swamp_interior_design.py 도 yaw 180 으로 고쳤다).
	보고: /swamp_fixes
]]
local HS = game:GetService("HttpService")
local S = workspace.Surface["Swamp2_늪지대"]
local report = {}
local function say(f, ...)
	report[#report + 1] = string.format(f, ...)
end

local ok, err = pcall(function()
	-- 1. 우물
	local nWell = 0
	for _, w in S:GetDescendants() do
		if w:IsA("Model") and w.Name == "Well" then
			local old = w:FindFirstChild("WellFix")
			if old then
				old:Destroy()
			end
			local stone = w:FindFirstChild("Well__stone")
			local f = Instance.new("Folder")
			f.Name = "WellFix"
			f.Parent = w
			local pv = w:GetPivot()
			local function P(name, cf, size, color, mat, shape)
				local p = Instance.new("Part")
				p.Name = name
				p.Anchored = true
				p.CFrame = cf
				p.Size = size
				p.Color = color
				p.Material = mat
				p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
				if shape then
					p.Shape = shape
				end
				p.Parent = f
				return p
			end
			-- 돌 고리: 반지름 2.75, 두께 0.9, 높이 0.1..3.15 (물판 2.65 보다 높고 돌 윗면 3.4 보다 낮다)
			local col = stone and stone.Color or Color3.fromRGB(110, 112, 108)
			local R, n = 2.75, 16
			local L = 2 * R * math.sin(math.pi / n) + 0.12
			for i = 0, n - 1 do
				local a = (i + 0.5) / n * 2 * math.pi
				P("InnerRing", pv * CFrame.new(R * math.sin(a), 1.625, R * math.cos(a)) * CFrame.Angles(0, a, 0), Vector3.new(L, 3.05, 0.9), col, Enum.Material.Slate)
			end
			-- 물 밑 어두운 물기둥(물판 바로 아래까지, 부딪히지 않음)
			local deep = P("DeepWater", pv * CFrame.new(0, 1.4, 0) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(2.4, 4.7, 4.7), Color3.fromRGB(16, 36, 40), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
			deep.CanCollide = false
			nWell += 1
		end
	end
	say("우물 %d", nWell)

	-- 2. B2 그물 부표
	local nFloat = 0
	for _, m in S["건물"]:GetChildren() do
		if m.Name ~= "StiltHouseB2" then
			continue
		end
		local it = m:FindFirstChild("Interior2")
		if not it then
			continue
		end
		local center = m:GetBoundingBox().Position
		for _, net in it:GetDescendants() do
			if not (net:IsA("BasePart") and net.Name == "net") then
				continue
			end
			local s = net.Size
			-- 얇은 축(가장 작은 크기)의 법선
			local normal = if s.X <= s.Y and s.X <= s.Z then net.CFrame.RightVector elseif s.Y <= s.Z then net.CFrame.UpVector else net.CFrame.LookVector
			local toRoom = (center - net.Position):Dot(normal) >= 0 and normal or -normal
			for _, b in it:GetDescendants() do
				if b:IsA("BasePart") and b ~= net and (b.Position - net.Position).Magnitude < 2.4 and math.max(b.Size.X, b.Size.Y, b.Size.Z) < 0.8 then
					local d = (b.Position - net.Position):Dot(toRoom)
					if d < 0 then
						-- 방 반대쪽(벽 밖)에 있다 → 그물 판을 거울삼아 방 쪽으로
						b.CFrame = b.CFrame + toRoom * (-2 * d)
						nFloat += 1
					end
				end
			end
		end
	end
	say("B2 그물 부표 옮김 %d", nFloat)

	-- 3. 마녀 오두막 계단 발치(z 825.8, 높이 ≈ 0)가 물 위에 매달리고 첫 징검돌(z 827.9~)까지 2 가 비었다 → 발치 밑 받침 돌
	local path = S:FindFirstChild("길")
	local ref = path and path:FindFirstChild("Stone_0")
	if ref then
		local old = path:FindFirstChild("Stone_Landing")
		if old then
			old:Destroy()
		end
		local st = ref:Clone()
		st.Name = "Stone_Landing"
		-- 윗면은 징검돌과 같은 0.05, 첫 돌과 0.1 띄워 윗면이 겹쳐 깜빡이지 않게
		st.Size = Vector3.new(5.2, ref.Size.Y, 3.6)
		st.CFrame = CFrame.new(ref.Position.X, ref.Position.Y, 826.0) * CFrame.Angles(0, math.rad(4), 0)
		st.Parent = path
		say("마녀 오두막 계단 받침 돌 놓음")
	end
end)
if not ok then
	say("ERR %s", tostring(err))
end
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/swamp_fixes", table.concat(report, "\n"))
end)
