--!nocheck
--[[
	Jeolhwa_GateProbe.luau — 2026-09-27. 절화 문을 사람이 지나갈 수 있는지 잰다.

	문 모델(Gate_Palace, Gate_Hall, Wall_GateTile)마다 통로 가운데 줄을 따라 사람 크기 상자
	(폭 2.4, 높이 4.6, 바닥에서 1 띄움)를 1 스터드씩 밀며 충돌이 켜진 파트에 걸리는지 본다.
	통로 자리는 블렌더 모델 치수(0.5 배)로 적었다. 로블록스 로컬 x 는 블렌더 x 의 부호를 뒤집은 것이다.
	걸린 파트는 이름·재질 조각·충돌 방식(CollisionFidelity)으로 모아 보고한다.
]]

local OPENINGS = {
	-- { 로컬 x, 로컬 z 시작, 끝, 바닥 찾는 광선 시작 높이(없으면 4.5) }
	Gate_Hall = { { 10, -20, 20 }, { 0, -20, 20 }, { -10, -20, 20 } },
	Gate_Palace = { { 0, -13, 13 }, { 17, -13, 13 }, { -17, -13, 13 } },
	Wall_GateTile = { { 0, -6, 6 } },
	-- 건물 앞문. 바깥 댓돌에서 문턱을 넘어 방 안 한두 걸음까지 (블렌더 치수 0.5 배, x 부호 뒤집음).
	-- 더 들어가면 안살림 가구에 닿는다(막힘이 아니라 가구)
	Building_House = { { 0, -11, -5 } },
	Building_Cottage = { { 0, -10, -4 } },
	Annex_Tile = { { 2.6, -8, -3.5 } }, -- 계단(x ±2.75)으로 올라 문(x 1.26..7.74)으로 든다
	Annex_Thatch = { { 4, -8, -2 } },
	Building_HouseL = { { 0, -10.5, -4 }, { -9, -28, -22 } },
	Building_HouseLM = { { 0, -10.5, -4 }, { 9, -28, -22 } },
	Shop_Row5 = { { 0, -9, -3 } }, -- 트인 칸 안 계산대(z -1.6..0) 앞까지
	Shop_Row3 = { { 0, -9, -3 } },
	Granary = { { 0, -10, -4, 6 } },
	Building_Hall = { { 0, -16, -10, 8 } },
	Palace_Main = { { 0, -21, -15, 10 } },
	Palace_Chimjeon = { { 0, -13, -7, 8 } },
}

local report = {}
local function say(f, ...)
	report[#report + 1] = string.format(f, ...)
end

local probe
local ok, err = pcall(function()
	local root = assert(workspace:FindFirstChild("Jeolhwa"), "Workspace.Jeolhwa 가 없다")
	local op = OverlapParams.new()
	op.RespectCanCollide = true
	local rp = RaycastParams.new()
	rp.RespectCanCollide = true
	local nGate = 0
	-- 사람 크기 재개 상자. 스스로는 어디에도 걸리지 않게 한다
	probe = Instance.new("Part")
	probe.Name = "GateProbe"
	probe.Anchored, probe.CanCollide, probe.CanQuery, probe.Transparency = true, false, false, 1
	probe.Size = Vector3.new(2.4, 4.6, 0.8)
	probe.Parent = workspace
	for _, m in ipairs(root:GetDescendants()) do
		local spec = m:IsA("Model") and OPENINGS[m.Name]
		if spec then
			nGate += 1
			local pv = m:GetPivot()
			for _, o in ipairs(spec) do
				local blockers, blockedAt = {}, {}
				for z = o[2], o[3], 1 do
					-- 바닥은 문 바닥 조금 위(로컬 y 4.5)에서 아래로 찾는다. 위에서 쏘면 지붕에 먼저 맞는다
					local top = pv:PointToWorldSpace(Vector3.new(o[1], o[4] or 4.5, z))
					local hit = workspace:Raycast(top, Vector3.new(0, -12, 0), rp)
					local floorY = hit and hit.Position.Y or pv.Y
					local c = CFrame.new(Vector3.new(top.X, floorY + 3.3, top.Z)) * pv.Rotation
					probe.CFrame = c
					local parts = workspace:GetPartsInPart(probe, op)
					for _, p in ipairs(parts) do
						local key = p:GetFullName():gsub("^Workspace%.Jeolhwa%.", "")
						if p:IsA("MeshPart") then
							key = key .. " [" .. p.CollisionFidelity.Name .. "]"
						end
						if not blockers[key] then
							blockers[key] = true
							blockedAt[#blockedAt + 1] = string.format("%s @z%d", key, z)
						end
					end
				end
				say("%s #%d %s  통로 x %.0f: %s", m.Name, nGate, (tostring(pv.Position):gsub("%.%d+", "")), o[1],
					#blockedAt == 0 and "지나감" or ("막힘 " .. table.concat(blockedAt, " | ")))
			end
		end
	end
	say("문 %d 개", nGate)
end)
if probe then
	probe:Destroy()
end
if not ok then
	say("ERR %s", tostring(err))
end
local HS = game:GetService("HttpService")
local was = HS.HttpEnabled
HS.HttpEnabled = true
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/gateprobe", table.concat(report, "\n"))
end)
HS.HttpEnabled = was
print("gateprobe", #report, ok)
