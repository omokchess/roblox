--!nocheck
--[[
	Snow_BurntRoom.luau — 불탄 설 공방 방을 채운다(2026-09-29 사용자: "실내 장식물이 너무 디테일한 것도 좋지 않으니 적당히 보기 좋게 밀도 있는 느낌").
	방은 원래 부품 47 개로 휑했다(변환장치 시제품·무너진 들보·긴 의자·종이 몇 장). 잔손 소품 대신 큼직한 덩어리로
	"불타고 남은 공방"의 밀도를 낸다: 무너진 선반, 그을린 상자 더미, 재 더미, 흩어진 탄 판자, 쓰러진 통, 그을음 자국, 떨어진 관·벽돌.
	자리는 전부 손 좌표(방 원점 O = 바닥 가운데, 앞 문 = -Z). 폴더 Densify 에 넣는다 — 지우면 되돌린다. 다시 돌려도 된다.
	보고: /burnt_room
]]
local HS = game:GetService("HttpService")
local RGB = Color3.fromRGB
local M = Enum.Material

local CHAR = { RGB(34, 29, 26), M.Wood }
local CHAR2 = { RGB(52, 40, 32), M.WoodPlanks }
local ASH = { RGB(74, 71, 68), M.Sand }
local SOOT = { RGB(14, 12, 12), M.SmoothPlastic }
local IRON = { RGB(58, 60, 66), M.CorrodedMetal }
local COPPER = { RGB(96, 62, 44), M.CorrodedMetal }
local BRICK = { RGB(92, 58, 48), M.Brick }

local report = {}
local ok, err = pcall(function()
	local room = workspace.Schneereich["안쪽방"]["설공방"]
	local old = room:FindFirstChild("Densify")
	if old then
		old:Destroy()
	end
	-- 방 원점: 바닥 가운데(방 파트들의 x·z 가운데, 바닥 높이 400)
	local lo, hi = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
	for _, p in room:GetDescendants() do
		if p:IsA("BasePart") then
			lo = lo:Min(p.Position - p.Size / 2)
			hi = hi:Max(p.Position + p.Size / 2)
		end
	end
	local O = Vector3.new((lo.X + hi.X) / 2, 400, (lo.Z + hi.Z) / 2)
	local f = Instance.new("Folder")
	f.Name = "Densify"
	f.Parent = room
	local n = 0
	local function P(name, x, y, z, sx, sy, sz, look, rot, shape, solid)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = Vector3.new(sx, sy, sz)
		local cf = CFrame.new(O + Vector3.new(x, y, z))
		if rot then
			cf *= CFrame.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
		end
		if shape == "cyl" then
			p.Shape = Enum.PartType.Cylinder
		elseif shape == "ball" then
			p.Shape = Enum.PartType.Ball
		end
		p.CFrame = cf
		p.Color = look[1]
		p.Material = look[2]
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.CanCollide = solid == true
		p.Parent = f
		n += 1
		return p
	end

	-- 뒷벽(z +13.5) 오른쪽: 무너진 선반. 기둥 둘은 서 있고 판 셋이 한쪽으로 주저앉았다
	P("ShelfPost", 7.5, 3.5, 13.4, 0.5, 7, 0.5, CHAR, nil, nil, true)
	P("ShelfPost", 13.5, 2.6, 13.4, 0.5, 5.2, 0.5, CHAR, { 0, 0, -9 }, nil, true)
	P("ShelfBoard", 10.5, 5.6, 13.1, 6.6, 0.3, 1.4, CHAR2, { 0, 0, 6 })
	P("ShelfBoard", 10.8, 2.4, 12.9, 6.6, 0.3, 1.4, CHAR2, { 0, 0, 24 })
	P("ShelfBoard", 11.2, 0.35, 12.2, 6.4, 0.3, 1.4, CHAR2, { 0, 18, 4 })
	P("ShelfJunk", 12.4, 0.9, 11.6, 1.2, 0.9, 1.0, IRON, { 10, 30, 0 })
	-- 왼쪽 뒤 구석: 그을린 상자 더미(둘은 쌓이고 하나는 깨졌다)
	P("Crate", -13.5, 1.2, 11.2, 2.4, 2.4, 2.4, CHAR2, { 0, 12, 0 }, nil, true)
	P("Crate", -13.3, 3.3, 11.4, 1.9, 1.9, 1.9, CHAR2, { 0, -10, 4 }, nil, true)
	P("Crate", -10.4, 1.0, 12.4, 2.0, 2.0, 2.0, CHAR, { 0, 33, 0 }, nil, true)
	P("CrateLid", -9.8, 0.2, 10.2, 2.2, 0.25, 1.9, CHAR, { 0, 58, 6 })
	-- 재 더미(납작한 공) — 불이 가장 셌던 가운데와 들보 밑
	for _, a in ipairs({ { -3.5, 5.5, 4.2, 1.1 }, { 4.5, -2.5, 3.2, 0.8 }, { 9.0, 6.5, 3.6, 0.9 }, { -9.5, -4.0, 2.8, 0.7 }, { 0.5, 10.5, 3.0, 0.8 } }) do
		P("Ash", a[1], a[4] * 0.3, a[2], a[3], a[4], a[3] * 0.85, ASH, { 0, a[1] * 7, 0 }, "ball")
	end
	-- 흩어진 탄 판자
	for _, b in ipairs({ { -6, 2, 30, 4.2 }, { -2, -6, -48, 3.6 }, { 6, 2.5, 75, 4.6 }, { 12, -1, 12, 3.2 }, { -12, 3, -20, 3.8 }, { 2, 7.5, 95, 3.4 } }) do
		P("Plank", b[1], 0.13, b[2], b[4], 0.25, 0.7, CHAR2, { 0, b[3], 2 })
	end
	-- 오른쪽 앞: 쓰러진 통 + 떨어진 테 하나
	P("Barrel", 14.0, 1.1, -8.0, 3.0, 2.2, 2.2, CHAR2, { 0, 25, 0 }, "cyl", true)
	P("BarrelHoop", 11.8, 0.1, -6.4, 0.2, 2.3, 2.3, IRON, { 0, 0, 90 }, "cyl")
	-- 떨어진 관(천장 김관이 녹아 떨어졌다)과 벽돌 몇 장(지붕 구멍 밑)
	P("FallenPipe", 2.0, 0.4, 11.0, 7.0, 0.8, 0.8, COPPER, { 0, 28, 0 }, "cyl")
	for _, b in ipairs({ { -1.5, -1.0, 10 }, { 0.8, 0.5, 60 }, { -0.4, 1.8, 130 }, { 1.9, -1.8, 35 } }) do
		P("Brick", b[1], 0.35, b[2], 1.6, 0.7, 0.8, BRICK, { 0, b[3], 6 })
	end
	-- 벽 그을음(얇은 판, 벽에 붙임). 왼벽·뒷벽·오른벽
	for _, s in ipairs({ { -17.9, 5.5, 2, 0.1, 7, 9 }, { -4, 6.5, 14.3, 10, 7, 0.1 }, { 17.9, 5, -5, 0.1, 6, 7 } }) do
		local p = P("Soot", s[1], s[2], s[3], s[4], s[5], s[6], SOOT)
		p.Transparency = 0.35
		p.CastShadow = false
	end
	report[#report + 1] = string.format("불탄 방 채움: 부품 %d, 원점 %.0f %.0f %.0f", n, O.X, O.Y, O.Z)
	workspace.CurrentCamera.CFrame = CFrame.lookAt(O + Vector3.new(-6, 6, -13), O + Vector3.new(3, 2, 8))
end)
if not ok then
	report[#report + 1] = "ERR " .. tostring(err)
end
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/burnt_room", table.concat(report, "\n"))
end)
