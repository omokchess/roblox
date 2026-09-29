--!nocheck
--[[
	Hill_ClearTrees.luau — 2026-09-27. 거목 언덕 새 계단(Surface.Ramps)을 막는 숲 나무를 길 옆으로 비켜 세운다 → recv/hillclear.txt

	계단 디딤면 위 0.2~7 높이를 막는 부딪히는 파트 중 R_숲.Flora 의 나무만 고른다(이름 앞머리 For_P431 같은 것이 한 그루).
	한 그루의 파트를 모두 모아, 길 가운데(x -1600)에서 먼 쪽으로 길 반폭 13 + 2 + 나무 반폭만큼 밀고
	새 자리 땅높이에 맞춰 올리거나 내린다. 거목(For_Elder)은 건드리지 않는다.
	되돌리기: _G.HillTreeUndo[p] = 원래 CFrame
]]
local S = workspace.Surface
local LANE_X, HALF = -1600, 13
local flora = S["R_숲"].Flora
local rpG = RaycastParams.new()
rpG.FilterType = Enum.RaycastFilterType.Include
rpG.FilterDescendantsInstances = { S.World, S.Mountains }
local function groundY(x, z)
	local h = workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -900, 0), rpG)
	return h and h.Position.Y
end

local op = OverlapParams.new()
op.FilterType = Enum.RaycastFilterType.Include
op.FilterDescendantsInstances = { flora }
local prefixes = {}
for _, p in ipairs(S.Ramps:GetDescendants()) do
	if p:IsA("BasePart") then
		local top = p.Position.Y + p.Size.Y / 2
		for _, q in ipairs(workspace:GetPartBoundsInBox(CFrame.new(p.Position.X, top + 3.6, p.Position.Z), Vector3.new(p.Size.X, 6.8, p.Size.Z), op)) do
			local pre = q.Name:match("^(For_%w+)_")
			if pre and not pre:match("Elder") and q.CanCollide then
				prefixes[pre] = true
			end
		end
	end
end
-- 앞머리별 파트
local byPre = {}
for _, q in ipairs(flora:GetDescendants()) do
	if q:IsA("BasePart") then
		local pre = q.Name:match("^(For_%w+)_")
		if pre and prefixes[pre] then
			byPre[pre] = byPre[pre] or {}
			table.insert(byPre[pre], q)
		end
	end
end
_G.HillTreeUndo = _G.HillTreeUndo or {}
local out, n = {}, 0
for pre, parts in pairs(byPre) do
	local mn, mx = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
	for _, q in ipairs(parts) do
		mn = mn:Min(q.Position - q.Size / 2)
		mx = mx:Max(q.Position + q.Size / 2)
	end
	local cx, cz = (mn.X + mx.X) / 2, (mn.Z + mx.Z) / 2
	-- 밑동 자리: 가장 낮은 파트
	local base = parts[1]
	for _, q in ipairs(parts) do
		if q.Position.Y < base.Position.Y then
			base = q
		end
	end
	local side = (base.Position.X >= LANE_X) and 1 or -1
	local r = (mx.X - mn.X) / 2
	local newX = LANE_X + side * (HALF + 2 + r) + (cx - base.Position.X)
	local dx = newX - cx
	local g0, g1 = groundY(base.Position.X, base.Position.Z), groundY(base.Position.X + dx, base.Position.Z)
	local dy = (g0 and g1) and (g1 - g0) or 0
	for _, q in ipairs(parts) do
		if not _G.HillTreeUndo[q] then
			_G.HillTreeUndo[q] = q.CFrame
		end
		q.CFrame = q.CFrame + Vector3.new(dx, dy, 0)
		if q:GetAttribute("GY") and g1 then
			q:SetAttribute("GY", g1)
		end
	end
	n += 1
	out[#out + 1] = string.format("%s 파트 %d: x %.0f → %.0f, 높이 %+.1f", pre, #parts, cx, cx + dx, dy)
end
table.insert(out, 1, "옮긴 나무 " .. n)
game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/hillclear", table.concat(out, "\n"))
print("hillclear", n)
