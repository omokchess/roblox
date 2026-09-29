--!nocheck
--[[
	Map_FloatAudit.luau — 온 맵에서 "떠 있는" 모델·파트 후보를 찾는다(2026-09-29, 눈높이 점검 보조).
	모델(파트를 직접 가진 것)마다 바닥면 아래로 광선 5 개(가운데 + 네 귀 35% 안쪽)를 쏴 가장 가까운 받침까지의 틈을 잰다.
	다섯 곳 모두 틈이 1.2 넘고 30 아래면 떠 있는 후보(틈이 더 크면 바다·절벽 위나 설계상 뜬 것). 매단 등·벽걸이처럼 옆으로 붙은 것도
	걸리므로 눈으로 확인할 목록이다. 설계상 뜬 것(성역 궤도 잔해·뜬 바위)과 숲 나무의 가지·잎 덩어리(For_*_B·C·t)는 뺀다.
	바닥면이 땅속에 묻혀 광선이 땅 속에서 출발한 것(위에서 쏘면 땅이 바닥면보다 위)도 뺀다.
	모델에 들지 않은 낱개 파트(길 조각·소품 블록)도 크기 12 아래만 같은 방식으로 본다.
	인자(전역 AUDIT_ROOT)가 있으면 그 폴더만. 보고: /float_audit (지역별 개수 + 틈 큰 순 80 개)
]]
local HS = game:GetService("HttpService")
local roots = {}
if _G.AUDIT_ROOT then
	roots = { _G.AUDIT_ROOT }
else
	for _, c in workspace.Surface:GetChildren() do
		if c.Name ~= "World" then
			table.insert(roots, c)
		end
	end
	table.insert(roots, workspace:FindFirstChild("Jeolhwa"))
	table.insert(roots, workspace:FindFirstChild("Schneereich"))
end
local SKIP_NAME = { Water = true, Glow = true, Lava = true, Crust = true, Heat = true, LavaLight = true }
local function designedFloat(inst)
	local n = inst.Name
	if n:find("^Debris") or n:find("^Float_") or n:find("^For_.-_[BC]%d") or n:find("_B%d+[tb]") then
		return true
	end
	local a = inst.Parent
	return a ~= nil and (a.Name == "Orbit" or a.Name == "Float")
end
local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Exclude

local found = {}
local perRoot = {}
local checked = 0

local op = OverlapParams.new()
op.FilterType = Enum.RaycastFilterType.Exclude
local function gapBelow(cf, size, exclude)
	rp.FilterDescendantsInstances = { exclude }
	op.FilterDescendantsInstances = { exclude }
	local bottom = cf.Y - size.Y / 2
	-- 1) 바닥면 바로 밑 얇은 판(발자국 70%, 두께 1.5)에 무엇이든 겹치면 받쳐진 것. 광선은 파트 속에서 출발하면 그 파트를 못 맞혀
	--    길에 박힌 연석·땅에 박힌 말뚝을 떠 있다고 잘못 봤다
	local probe = CFrame.new(cf.X, bottom - 0.6, cf.Z) * cf.Rotation
	local hits = workspace:GetPartBoundsInBox(probe, Vector3.new(math.max(size.X * 0.7, 0.3), 1.5, math.max(size.Z * 0.7, 0.3)), op)
	for _, h in hits do
		if h.CanCollide or h.Transparency < 1 then
			return 0
		end
	end
	-- 2) 안 받쳐졌으면 틈을 잰다(가운데 + 네 귀)
	local best = math.huge
	for _, o in { { 0, 0 }, { 0.35, 0.35 }, { -0.35, 0.35 }, { 0.35, -0.35 }, { -0.35, -0.35 } } do
		local p = cf:PointToWorldSpace(Vector3.new(size.X * o[1], 0, size.Z * o[2]))
		local hit = workspace:Raycast(Vector3.new(p.X, bottom - 0.05, p.Z), Vector3.new(0, -60, 0), rp)
		best = math.min(best, hit and (bottom - hit.Position.Y) or 60)
	end
	return best
end

for _, root in roots do
	if not root then
		continue
	end
	local n = 0
	for i, d in root:GetDescendants() do
		local target, cf, size
		if d:IsA("Model") then
			local direct = false
			for _, c in d:GetChildren() do
				if c:IsA("BasePart") then
					direct = true
					break
				end
			end
			if direct then
				local ok, a, b = pcall(d.GetBoundingBox, d)
				if ok then
					target, cf, size = d, a, b
				end
			end
		elseif d:IsA("BasePart") and not d:FindFirstAncestorOfClass("Model") and d.Transparency < 1 and not SKIP_NAME[d.Name]
			and math.max(d.Size.X, d.Size.Y, d.Size.Z) < 12 and d.Material ~= Enum.Material.Neon then
			local up = d.CFrame.UpVector
			target, cf = d, CFrame.new(d.Position) * CFrame.fromOrientation(0, select(2, d.CFrame:ToOrientation()), 0)
			local s = d.Size / 2
			local r, u, l = d.CFrame.RightVector, up, d.CFrame.LookVector
			size = Vector3.new(
				2 * (math.abs(r.X) * s.X + math.abs(u.X) * s.Y + math.abs(l.X) * s.Z),
				2 * (math.abs(r.Y) * s.X + math.abs(u.Y) * s.Y + math.abs(l.Y) * s.Z),
				2 * (math.abs(r.Z) * s.X + math.abs(u.Z) * s.Y + math.abs(l.Z) * s.Z)
			)
		end
		if target and designedFloat(target) then
			target = nil
		end
		if target then
			checked += 1
			local g = gapBelow(cf, size, target)
			if g > 1.2 and g < 30 then
				n += 1
				table.insert(found, { g = g, name = target:GetFullName(), p = cf.Position, s = size })
			end
		end
		if i % 400 == 0 then
			task.wait()
		end
	end
	perRoot[#perRoot + 1] = string.format("%s: 후보 %d", root:GetFullName(), n)
end
table.sort(found, function(a, b) return a.g > b.g end)
local out = { string.format("본 것 %d, 떠 있는 후보 %d", checked, #found) }
for _, l in perRoot do
	table.insert(out, "  " .. l)
end
for i = 1, math.min(#found, _G.AUDIT_LIMIT or 120) do
	local f = found[i]
	table.insert(out, string.format("%5.1f  %s  (%.0f,%.1f,%.0f) s(%.1f,%.1f,%.1f)", f.g, f.name:gsub("Workspace%.", ""), f.p.X, f.p.Y - f.s.Y / 2, f.p.Z, f.s.X, f.s.Y, f.s.Z))
end
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/float_audit", table.concat(out, "\n"))
end)
