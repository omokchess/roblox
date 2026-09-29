--!nocheck
--[[
	Jeolhwa_City.luau — 평원의 도성 절화를 짓는다. (2판: 굽은 길과 필지)

	1판은 똑같은 집을 바둑판으로 줄 세워서, 캐릭터 눈높이에서 어디를 봐도 같은 장면이었다.
	2판은 이렇게 짠다.
	  * 길. 광장에서 궁으로 가는 큰길만 곧고, 마을 길 넷은 휘어 나간다.
	    모퉁이를 돌면 새 장면이 나오게 한다
	  * 필지. 집 한 채가 아니라 담으로 두른 마당 하나를 단위로 앉힌다.
	    본채, 곁채, 장독대, 우물, 텃밭, 짚가리를 필지 종류마다 다르게 짰다
	      Yangban  ㄱ자 기와집 + 기와 곁채 + 장독대 + 우물. 기와 담과 기와 대문
	      Giwa     곧은 기와집 + 기와 곁채 + 장독대 + 텃밭. 돌담, 대문 없이 트인 입구
	      Choga    초가 + 초가 곁채 + 짚가리 + 텃밭. 싸리 울타리와 싸리문
	      Choga2   초가 + 초가 곁채 + 짚가리 + 텃밭. 울타리 없이 트인 마당
	    필지는 저마다 제 앞 길 한 점을 바라보게 돌려 앉힌다. 그래서 길을 따라 방향이 조금씩 틀어진다
	  * 높낮이. 궁궐 전체를 돌 축대 위로 4 올리고 대문 앞에 계단을 둔다
	  * 사이. 마을 어귀에 정자와 우물, 길가에 큰 나무

	배치는 모두 표에 손으로 적었다. 필지 자리는 길 한 점에서 길의 법선으로 물린 곳이고,
	그 계산은 표를 적을 때 했다. 스크립트는 표를 그대로 앉히고 겹침만 검사한다.

	하는 일
	  1. 가져온 모델에 색과 충돌을 입혀 ServerStorage.JeolhwaKit 에 틀로 넣는다
	  2. 궁궐 축대, 길, 필지, 어귀 시설, 나무를 Workspace.Jeolhwa 에 앉힌다
	  3. 자리에 걸린 원래 나무는 ServerStorage.Jeolhwa_ClearedFlora 로 옮긴다(그루 단위)
	  4. 필지·길·시설끼리 돌린 사각형으로 겹침을 검사해 로컬 수신기로 보고한다

	다시 돌리면 Workspace.Jeolhwa 만 새로 짓는다.
]]

local report = {}
local function say(fmt, ...)
	report[#report + 1] = string.format(fmt, ...)
end

local RGB = Color3.fromRGB
local M = Enum.Material

-- 블렌더 hanok_lib.PALETTE 와 같은 값이다. 한쪽만 고치면 어긋난다
local SKIN = {
	Stylobate = { RGB(193, 190, 176), M.Limestone },
	Stairs = { RGB(197, 194, 179), M.Limestone },
	Plinth = { RGB(169, 165, 151), M.Limestone },
	Column = { RGB(138, 90, 69), M.Wood },
	Beam = { RGB(126, 83, 64), M.Wood },
	Bracket = { RGB(110, 71, 54), M.Wood },
	Wall = { RGB(219, 212, 193), M.SmoothPlastic },
	Lattice = { RGB(154, 106, 78), M.Wood },
	Paper = { RGB(228, 220, 198), M.SmoothPlastic },
	Roof = { RGB(85, 88, 79), M.Slate },
	RoofEdge = { RGB(71, 74, 67), M.Slate },
	Eave = { RGB(94, 64, 51), M.Wood },
	Trim = { RGB(78, 111, 99), M.SmoothPlastic },
	Ochre = { RGB(180, 136, 74), M.SmoothPlastic },
	Masonry = { RGB(157, 153, 139), M.Slate },
	Thatch = { RGB(156, 134, 96), M.Fabric },
	Onggi = { RGB(92, 64, 50), M.SmoothPlastic },
	Soil = { RGB(122, 100, 73), M.Ground },
	Leaf = { RGB(94, 113, 71), M.Grass },
	Brush = { RGB(142, 125, 102), M.Wood },
}
local PRECISE = {
	Wall = true, Lattice = true, Stairs = true, Column = true, Plinth = true,
	Beam = true, Bracket = true, Stylobate = true, Masonry = true, Brush = true,
}
local HULL = { Roof = true, RoofEdge = true, Eave = true, Thatch = true, Onggi = true }
local NOCOLLIDE = { Trim = true, Ochre = true, Paper = true, Leaf = true }

local KIT_NAMES = {
	"Palace_Main", "Building_House", "Building_Cottage", "Pavilion_Jeongja", "Gate_Main", "Wall_Segment",
	"Building_HouseL", "Annex_Tile", "Annex_Thatch",
	"Wall_Stone", "Fence_Brush", "Wall_GateTile", "Fence_Gate",
	"Prop_Well", "Prop_Jangdok", "Prop_Haystack", "Prop_Garden",
}
local SEG_LEN = 20 -- 담·울타리 한 토막 길이

--==================================================================== 궁궐
-- { 틀, x, z, 방향 }. 방향 0 은 -Z(남쪽)를 본다. 180 북쪽, 90 서쪽, -90 동쪽
local PALACE = {
	{ "Gate_Main", 225, 650, 0 },
	{ "Palace_Main", 225, 800, 0 },
	{ "Building_Hall", 145, 715, -90 },
	{ "Building_Hall", 305, 715, 90 },
	{ "Pavilion_Jeongja", 150, 865, 0 },
	{ "Pavilion_Jeongja", 300, 865, 0 },
}
local PALACE_WALLS = {
	{ 105, 650, 211, 650 },
	{ 239, 650, 345, 650 },
	{ 105, 900, 345, 900 },
	{ 105, 650, 105, 900 },
	{ 345, 650, 345, 900 },
}
-- 궁궐 축대. 대문 앞면(z 641)까지 온전히 받치도록 앞을 638 로 둔다
local TERRACE = { x0 = 100, x1 = 350, z0 = 638, z1 = 905, h = 4 }

--==================================================================== 길
-- 점을 이은 굽은 길. { 이름, 폭, 재질, 점들 }
local LANES = {
	{ "서촌길", 14, "dirt", { { 165, 520 }, { 100, 548 }, { 30, 585 }, { -40, 605 }, { -110, 640 }, { -165, 695 }, { -205, 760 }, { -230, 840 } } },
	{ "동촌길", 14, "dirt", { { 285, 520 }, { 350, 540 }, { 420, 548 }, { 490, 575 }, { 550, 620 }, { 595, 685 }, { 620, 760 } } },
	{ "남서길", 12, "dirt", { { 165, 430 }, { 110, 400 }, { 50, 350 }, { -20, 320 }, { -100, 300 }, { -180, 300 }, { -250, 320 } } },
	{ "남동길", 12, "dirt", { { 285, 430 }, { 340, 395 }, { 400, 350 }, { 470, 320 }, { 550, 310 }, { 620, 330 } } },
	{ "남산길", 8, "dirt", { { 340, 395 }, { 335, 330 }, { 320, 230 }, { 300, 130 }, { 288, 58 } } },
	{ "동산길", 8, "dirt", { { 620, 330 }, { 655, 300 }, { 686, 262 } } },
	{ "어도", 16, "stone", { { 225, 598 }, { 225, 630 } } },
	{ "관아앞", 16, "stone", { { 225, 425 }, { 225, 386 } } },
}

--==================================================================== 필지
-- 필지 종류. 로컬 좌표는 스터드이고 필지 앞(길 쪽)이 -Z 다.
-- pieces { 틀, x, z, 방향 }. 크기와 자리는 모델 실측 크기로 서로, 담과 겹치지 않게 적었다
local PLOT_TYPES = {
	Yangban = {
		W = 64, D = 60,
		pieces = {
			{ "Building_HouseL", -4, 16, 0 },
			{ "Annex_Tile", -21.5, -12, -90 }, -- 왼쪽에서 마당을 본다
			{ "Prop_Jangdok", 22, 20, 0 },
			{ "Prop_Well", 20, -14, 0 },
		},
		fence = "Wall_Segment", gate = "Wall_GateTile",
	},
	Giwa = {
		W = 56, D = 56,
		pieces = {
			{ "Building_House", 0, 13, 0 },
			{ "Annex_Tile", 17, -12, 90 }, -- 오른쪽에서 마당을 본다
			{ "Prop_Jangdok", -18, -18, 0 },
			{ "Prop_Garden", -14, -8, 0 },
		},
		fence = "Wall_Stone", opening = 14, -- 돌담 입구는 문 없이 트였다
	},
	Choga = {
		W = 60, D = 50,
		pieces = {
			{ "Building_Cottage", -6, 10, 0 },
			{ "Annex_Thatch", -19, -13, -90 },
			{ "Prop_Haystack", 18, 14, 0 },
			{ "Prop_Garden", 16, -12, 0 },
		},
		fence = "Fence_Brush", gate = "Fence_Gate",
	},
	Choga2 = {
		W = 68, D = 52,
		pieces = {
			{ "Building_Cottage", 0, 6, 0 },
			{ "Annex_Thatch", 24, -4, 90 },
			{ "Prop_Haystack", -22, 8, 0 },
			{ "Prop_Garden", -6, -20, 0 },
		},
	},
}

-- { 종류, x, z, 바라볼 길 위 한 점 x, z }
local PLOTS = {
	-- 서촌길 남쪽
	{ "Giwa", 116.7, 497.4, 132.5, 534 },
	{ "Yangban", 45.3, 529.4, 65, 566.5 },
	{ "Giwa", -16.0, 556.5, -5, 595 },
	{ "Yangban", -93.8, 585.0, -75, 622.5 },
	{ "Giwa", -165.8, 639.2, -137.5, 667.5 },
	{ "Choga", -219.1, 706.5, -185, 727.5 },
	{ "Choga2", -254.3, 788.7, -217.5, 800 },
	-- 서촌길 북쪽
	{ "Yangban", 10.0, 636.5, -2, 594 },
	{ "Yangban", -55.3, 661.8, -75, 622.5 },
	{ "Giwa", -149.2, 749.5, -185, 727.5 },
	{ "Choga", -179.3, 811.9, -217.5, 800 },
	-- 동촌길 북쪽
	{ "Yangban", 380.0, 587.7, 385, 544 },
	{ "Giwa", 469.8, 611.5, 490, 575 },
	{ "Giwa", 538.0, 676.4, 572.5, 652.5 },
	{ "Choga", 582.0, 772.6, 620, 760 },
	-- 동촌길 남쪽
	{ "Giwa", 329.3, 491.8, 317.5, 530 },
	{ "Choga", 392.2, 507.6, 388, 544.3 },
	{ "Yangban", 470.1, 522.3, 455, 561.5 },
	{ "Giwa", 545.2, 563.9, 520, 597.5 },
	{ "Choga", 605.4, 629.7, 572.5, 652.5 },
	{ "Choga2", 643.6, 710.5, 607.5, 722.5 },
	-- 남서길. 초가 마을
	{ "Choga2", 55.7, 404.2, 80, 375 },
	{ "Choga", -69.2, 346.9, -60, 310 },
	{ "Choga2", -174.7, 337.6, -180, 300 },
	{ "Choga", 155.2, 382.5, 137.5, 415 },
	{ "Choga", 101.4, 344.7, 77.7, 373.1 },
	{ "Choga", 29.6, 301.0, 15, 335 },
	{ "Choga2", -50.8, 273.1, -60, 310 },
	{ "Choga", -140.0, 263.0, -140, 300 },
	{ "Choga2", -260.0, 284.0, -250, 320 },
	-- 남동길
	{ "Choga", 392.2, 402.1, 370, 372.5 },
	{ "Choga2", 514.7, 352.7, 510, 315 },
	{ "Choga", 609.8, 365.6, 620, 330 },
	{ "Choga2", 420.0, 300.0, 435, 335 },
	{ "Choga", 505.4, 278.3, 510, 315 },
	{ "Choga", 595.2, 284.4, 585, 320 },
}

--==================================================================== 어귀
-- { 틀, x, z, 바라볼 곳 x, z } 또는 방향을 숫자로
local FEATURES = {
	{ "Pavilion_Jeongja", 125, 605, 100, 548 }, -- 서촌 어귀 정자. 길을 내려다본다
	{ "Prop_Well", 150, 560, 0 },
	{ "Prop_Well", 305, 575, 0 },
	{ "Prop_Well", -112, 690, 0 }, -- 서촌 굽이 우물터
	{ "Pavilion_Jeongja", 285, 30, 180 }, -- 남쪽 언덕
	{ "Pavilion_Jeongja", 705, 250, 90 }, -- 동쪽 언덕
}
-- 큰 나무. 평원에 원래 있던 나무를 그루째 복제해 옮겨 심는다
local TREES = { { 154, 596 }, { -105, 715 }, { 430, 650 }, { -120, 385 }, { 455, 425 } }

-- 겹치면 안 되는 고정 자리. { 이름, 가운데 x, z, 가로, 세로 }
local KEEP = {
	{ "스폰광장", 225, 510, 120, 180 },
	{ "궁궐축대", 225, 771.5, 250, 267 },
	{ "관아", 225, 360, 50, 42 },
}

--==================================================================== 도구
local function skinModel(model)
	local unknown = {}
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			local key = p.Name:match("^[^_]+_(.+)$")
			local skin = key and SKIN[key]
			if skin then
				p.Color = skin[1]
				p.Material = skin[2]
			else
				unknown[#unknown + 1] = p.Name
			end
			p.Anchored = true
			p.CanCollide = not (key and NOCOLLIDE[key])
			p.CastShadow = true
			if p:IsA("MeshPart") then
				if key and PRECISE[key] then
					p.CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition
				elseif key and HULL[key] then
					p.CollisionFidelity = Enum.CollisionFidelity.Hull
				else
					p.CollisionFidelity = Enum.CollisionFidelity.Box
				end
				p.RenderFidelity = Enum.RenderFidelity.Precise
			end
		end
	end
	assert(#unknown == 0, model.Name .. " 에서 이름을 못 알아본 파트: " .. table.concat(unknown, " "))
end

-- 파트가 frame 축으로 차지하는 반너비. 파트가 어느 쪽으로 돌아 있어도 맞게 잰다
local function halfExtents(part, frame)
	local r = frame:ToObjectSpace(part.CFrame)
	local s = part.Size / 2
	local R, U, L = r.RightVector, r.UpVector, r.LookVector
	return Vector3.new(
		math.abs(R.X) * s.X + math.abs(U.X) * s.Y + math.abs(L.X) * s.Z,
		math.abs(R.Y) * s.X + math.abs(U.Y) * s.Y + math.abs(L.Y) * s.Z,
		math.abs(R.Z) * s.X + math.abs(U.Z) * s.Y + math.abs(L.Z) * s.Z
	), r.Position
end

-- 모델을 피벗 x 축으로만 늘인다. 담 토막 길이를 모서리에 맞추려는 것이다
local function stretchX(model, f)
	local frame = model:GetPivot()
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			local r = frame:ToObjectSpace(p.CFrame)
			local R, U, L = r.RightVector, r.UpVector, r.LookVector
			local ax = { math.abs(R.X), math.abs(U.X), math.abs(L.X) }
			local s = p.Size
			if ax[1] >= ax[2] and ax[1] >= ax[3] then
				s = Vector3.new(s.X * f, s.Y, s.Z)
			elseif ax[2] >= ax[3] then
				s = Vector3.new(s.X, s.Y * f, s.Z)
			else
				s = Vector3.new(s.X, s.Y, s.Z * f)
			end
			p.Size = s
			p.CFrame = frame * CFrame.new(r.X * f, r.Y, r.Z) * r.Rotation
		end
	end
end

-- 바라볼 점으로 방향(도)을 구한다. 0 이 -Z 를 보는 것과 같은 약속이다
local function yawToward(x, z, fx, fz)
	return math.deg(math.atan2(-(fx - x), -(fz - z)))
end

-- 돌린 사각형 둘이 겹치는지. 두 사각형의 네 축으로 가른다
local function obbOverlap(a, b)
	local function axes(o)
		local r = math.rad(o.yaw)
		-- 방향 yaw 일 때 로컬 +X 와 +Z 가 월드에서 가리키는 쪽
		return { { math.cos(r), -math.sin(r) }, { math.sin(r), math.cos(r) } }
	end
	local function project(o, ax)
		local oa = axes(o)
		local c = o.x * ax[1] + o.z * ax[2]
		local e = math.abs(oa[1][1] * ax[1] + oa[1][2] * ax[2]) * o.hw
			+ math.abs(oa[2][1] * ax[1] + oa[2][2] * ax[2]) * o.hd
		return c - e, c + e
	end
	for _, o in ipairs({ a, b }) do
		for _, ax in ipairs(axes(o)) do
			local a0, a1 = project(a, ax)
			local b0, b1 = project(b, ax)
			if a1 <= b0 or b1 <= a0 then
				return false
			end
		end
	end
	return true
end

local okRun, errRun = pcall(function()
	--==================================================================== 1. 틀
	local SS = game:GetService("ServerStorage")
	local kit = SS:FindFirstChild("JeolhwaKit")
	if not kit then
		kit = Instance.new("Folder")
		kit.Name = "JeolhwaKit"
		kit.Parent = SS
	end
	for _, n in ipairs(KIT_NAMES) do
		local w = workspace:FindFirstChild(n)
		if w and w:IsA("Model") then
			skinModel(w)
			local old = kit:FindFirstChild(n)
			if old then
				old.Parent = nil -- 옛 틀은 버린다. 방금 가져온 것이 새 판이다
			end
			w:PivotTo(CFrame.new())
			w.Parent = kit
		end
		assert(kit:FindFirstChild(n), n .. " 틀이 없다. FBX 를 가져와라")
	end
	if not kit:FindFirstChild("Building_Hall") then
		local hall = workspace:FindFirstChild("Building_Hall")
		assert(hall, "Building_Hall 이 없다")
		local c = hall:Clone()
		c:PivotTo(CFrame.new())
		c.Parent = kit
	end

	--==================================================================== 2. 판 깔기
	local old = workspace:FindFirstChild("Jeolhwa")
	if old then
		old:Destroy()
	end
	local city = Instance.new("Folder")
	city.Name = "Jeolhwa"
	city.Parent = workspace
	local function sub(name, parent)
		local f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent or city
		return f
	end
	local F = {
		Terrace = sub("Terrace"), Palace = sub("Palace"), Roads = sub("Roads"),
		Plots = sub("Plots"), Features = sub("Features"), Trees = sub("Trees"),
	}

	local G = workspace.Surface.World["G_평원"]
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { G, F.Terrace }
	local function groundY(x, z)
		local h = workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -1200, 0), rp)
		return h and h.Position.Y
	end

	local function stonePart(name, cf, size, color, mat, parent)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = mat
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = parent
		return p
	end

	-- 궁궐 축대. 땅에서 가장 높은 데를 재어 그 위로 h 만큼 올린다
	do
		local t = TERRACE
		local hi = -math.huge
		for _, u in ipairs({ 0, 0.25, 0.5, 0.75, 1 }) do
			for _, v in ipairs({ 0, 0.25, 0.5, 0.75, 1 }) do
				local gy = groundY(t.x0 + (t.x1 - t.x0) * u, t.z0 + (t.z1 - t.z0) * v)
				assert(gy, "궁궐 축대 자리에 땅이 없다")
				hi = math.max(hi, gy)
			end
		end
		local top = hi + t.h
		local cx, cz = (t.x0 + t.x1) / 2, (t.z0 + t.z1) / 2
		stonePart("Terrace", CFrame.new(cx, (top + hi - 2) / 2, cz), Vector3.new(t.x1 - t.x0, top - hi + 2, t.z1 - t.z0),
			SKIN.Masonry[1], M.Slate, F.Terrace)
		-- 축대 윗면 갓돌. 가장자리에 한 켜 밝은 돌을 둘러 켜가 보이게 한다
		local rim = SKIN.Stylobate[1]
		stonePart("Rim_S", CFrame.new(cx, top - 0.3, t.z0 + 1), Vector3.new(t.x1 - t.x0 + 1, 0.8, 2.2), rim, M.Limestone, F.Terrace)
		stonePart("Rim_N", CFrame.new(cx, top - 0.3, t.z1 - 1), Vector3.new(t.x1 - t.x0 + 1, 0.8, 2.2), rim, M.Limestone, F.Terrace)
		stonePart("Rim_W", CFrame.new(t.x0 + 1, top - 0.3, cz), Vector3.new(2.2, 0.8, t.z1 - t.z0 + 1), rim, M.Limestone, F.Terrace)
		stonePart("Rim_E", CFrame.new(t.x1 - 1, top - 0.3, cz), Vector3.new(2.2, 0.8, t.z1 - t.z0 + 1), rim, M.Limestone, F.Terrace)
		-- 대문 앞 계단. 축대 앞에서 멀어질수록 한 단씩 낮아진다. 단 높이는 h/(단수+1)
		local steps = math.ceil(t.h) - 1
		for k = 1, steps do
			local stepTop = hi + t.h * (steps - k + 1) / (steps + 1)
			local z = t.z0 - 2.6 * (k - 0.5)
			local bot = hi - 1
			stonePart("Step_" .. k, CFrame.new(225, (stepTop + bot) / 2, z), Vector3.new(24, stepTop - bot, 2.7),
				SKIN.Stairs[1], M.Limestone, F.Terrace)
		end
		say("축대 윗면 %.1f", top)
	end

	local placed = {}
	local foundations, maxGap = 0, 0

	local function place(kind, x, z, yaw, parent, stretch)
		local m = kit[kind]:Clone()
		if stretch then
			stretchX(m, stretch)
		end
		m:PivotTo(CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(yaw), 0))
		m.Parent = parent
		local frame = m:GetPivot()

		-- 땅에 닿는 조각(가장 낮은 켜)의 발자국을 모은다. 처마까지 넣으면 너무 넓게 잰다
		local minY = math.huge
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then
				local e, c = halfExtents(p, frame)
				minY = math.min(minY, c.Y - e.Y)
			end
		end
		local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") then
				local e, c = halfExtents(p, frame)
				if c.Y - e.Y < minY + 0.3 then
					x0, x1 = math.min(x0, c.X - e.X), math.max(x1, c.X + e.X)
					z0, z1 = math.min(z0, c.Z - e.Z), math.max(z1, c.Z + e.Z)
				end
			end
		end

		local lo, hi = math.huge, -math.huge
		for _, u in ipairs({ 0.02, 0.5, 0.98 }) do
			for _, v in ipairs({ 0.02, 0.5, 0.98 }) do
				local wp = frame:PointToWorldSpace(Vector3.new(x0 + (x1 - x0) * u, 0, z0 + (z1 - z0) * v))
				local gy = groundY(wp.X, wp.Z)
				assert(gy, string.format("%s (%.0f,%.0f) 발자국 (%.0f,%.0f) 아래에 땅이 없다", kind, x, z, wp.X, wp.Z))
				lo, hi = math.min(lo, gy), math.max(hi, gy)
			end
		end
		local bottom = frame.Y + minY
		m:PivotTo(m:GetPivot() + Vector3.new(0, hi - bottom, 0))

		-- 낮은 쪽이 뜨면 돌 축대를 받친다. 땅속으로 1 더 박는다
		if hi - lo > 0.25 then
			local f = Instance.new("Part")
			f.Name = "Foundation"
			f.Anchored = true
			f.Size = Vector3.new(x1 - x0 + 1.0, hi - lo + 1.0, z1 - z0 + 1.0)
			f.CFrame = CFrame.new(frame:PointToWorldSpace(Vector3.new((x0 + x1) / 2, 0, (z0 + z1) / 2)))
					* frame.Rotation
				+ Vector3.new(0, (lo - 1.0 + hi) / 2 - frame.Y, 0)
			f.Color = SKIN.Masonry[1]
			f.Material = M.Slate
			f.TopSurface = Enum.SurfaceType.Smooth
			f.BottomSurface = Enum.SurfaceType.Smooth
			f.Parent = m
			foundations = foundations + 1
			maxGap = math.max(maxGap, hi - lo)
		end

		placed[#placed + 1] = { m = m, kind = kind }
		return m
	end

	-- 담 한 줄. 두 점 사이를 토막으로 고르게 나눠 늘여 붙인다
	local function wallRun(kind, ax, az, bx, bz, parent, label)
		local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
		if len < 4 then
			return
		end
		local n = math.max(1, math.floor(len / SEG_LEN + 0.5))
		local seg = len / n
		-- 토막의 긴 쪽(로컬 X)이 a→b 를 따르게 돌린다
		local yaw = math.deg(math.atan2(-(bz - az), bx - ax))
		for k = 1, n do
			local t = (k - 0.5) / n
			local m = place(kind, ax + (bx - ax) * t, az + (bz - az) * t, yaw, parent, seg / SEG_LEN)
			m.Name = string.format("%s_%02d", label, k)
		end
	end

	local footprints = {}
	local function addFoot(name, group, x, z, w, d, yaw)
		footprints[#footprints + 1] = { name = name, group = group, x = x, z = z, hw = w / 2, hd = d / 2, yaw = yaw or 0 }
	end

	--==================================================================== 3. 궁궐
	for i, e in ipairs(PALACE) do
		local m = place(e[1], e[2], e[3], e[4], F.Palace)
		m.Name = string.format("%s_%02d", e[1], i)
	end
	for wi, w in ipairs(PALACE_WALLS) do
		wallRun("Wall_Segment", w[1], w[2], w[3], w[4], F.Palace, "PalaceWall_" .. wi)
	end
	task.wait()

	--==================================================================== 4. 길
	local FLOOR = {
		stone = { RGB(176, 172, 158), M.Limestone },
		dirt = { RGB(150, 128, 96), M.Ground },
	}
	local function floorPiece(name, cx, cz, len, width, yaw, kind, parent)
		-- 조각 위 여섯 점을 재어 윗면은 가장 높은 땅 0.3 위, 밑면은 가장 낮은 땅 0.9 아래
		local cf = CFrame.new(cx, 0, cz) * CFrame.Angles(0, math.rad(yaw), 0)
		local lo, hi = math.huge, -math.huge
		for _, u in ipairs({ -0.5, 0, 0.5 }) do
			for _, v in ipairs({ -0.5, 0.5 }) do
				local wp = cf:PointToWorldSpace(Vector3.new(len * u, 0, width * v))
				local gy = groundY(wp.X, wp.Z)
				assert(gy, string.format("%s 자리 (%.0f,%.0f) 에 땅이 없다", name, wp.X, wp.Z))
				lo, hi = math.min(lo, gy), math.max(hi, gy)
			end
		end
		local top, bot = hi + 0.3, lo - 0.9
		return stonePart(name, CFrame.new(cx, (top + bot) / 2, cz) * CFrame.Angles(0, math.rad(yaw), 0),
			Vector3.new(len, top - bot, width), FLOOR[kind][1], FLOOR[kind][2], parent)
	end

	for li, lane in ipairs(LANES) do
		local name, width, kind, pts = lane[1], lane[2], lane[3], lane[4]
		local folder = sub(name, F.Roads)
		for i = 1, #pts - 1 do
			local ax, az = pts[i][1], pts[i][2]
			local bx, bz = pts[i + 1][1], pts[i + 1][2]
			local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
			local yaw = math.deg(math.atan2(-(bz - az), bx - ax))
			local n = math.max(1, math.ceil(len / 40))
			for k = 1, n do
				local t = (k - 0.5) / n
				-- 조각끼리 1 겹쳐 틈을 없앤다
				floorPiece(string.format("Road_%d_%d", i, k), ax + (bx - ax) * t, az + (bz - az) * t, len / n + 1, width, yaw, kind, folder)
			end
			addFoot(name .. "#" .. i, "road", (ax + bx) / 2, (az + bz) / 2, len, width, yaw)
			-- 굽이 이음. 꺾인 자리의 빈 삼각형을 둥근 판으로 메운다
			if i > 1 then
				local gy = groundY(ax, az)
				-- 윗면을 길보다 0.02 낮춰 겹친 면이 깜빡이지 않게 한다
				local c = stonePart("Joint_" .. i, CFrame.new(ax, gy + 0.28 - 0.6, az) * CFrame.Angles(0, 0, math.rad(90)),
					Vector3.new(1.2, width, width), FLOOR[kind][1], FLOOR[kind][2], folder)
				c.Shape = Enum.PartType.Cylinder
			end
		end
	end
	task.wait()

	--==================================================================== 5. 필지
	local plotCount = {}
	for pi, p in ipairs(PLOTS) do
		local T = assert(PLOT_TYPES[p[1]], "필지 종류 " .. tostring(p[1]))
		local yaw = yawToward(p[2], p[3], p[4], p[5])
		local cf = CFrame.new(p[2], 0, p[3]) * CFrame.Angles(0, math.rad(yaw), 0)
		local folder = sub(string.format("%02d_%s", pi, p[1]), F.Plots)
		for _, e in ipairs(T.pieces) do
			local wp = cf:PointToWorldSpace(Vector3.new(e[2], 0, e[3]))
			local m = place(e[1], wp.X, wp.Z, yaw + e[4], folder)
			m.Name = e[1]
		end
		-- 담. 앞(-Z) 가운데를 대문이나 트인 입구로 비우고 네 변을 두른다
		if T.fence then
			local hw, hd = T.W / 2, T.D / 2
			local gap = T.gate and SEG_LEN or (T.opening or 0)
			local function run(lx0, lz0, lx1, lz1, label)
				local a = cf:PointToWorldSpace(Vector3.new(lx0, 0, lz0))
				local b = cf:PointToWorldSpace(Vector3.new(lx1, 0, lz1))
				wallRun(T.fence, a.X, a.Z, b.X, b.Z, folder, label)
			end
			run(-hw, -hd, -gap / 2, -hd, "FrontL")
			run(gap / 2, -hd, hw, -hd, "FrontR")
			run(hw, -hd, hw, hd, "Right")
			run(hw, hd, -hw, hd, "Back")
			run(-hw, hd, -hw, -hd, "Left")
			if T.gate then
				local g = cf:PointToWorldSpace(Vector3.new(0, 0, -hd))
				local m = place(T.gate, g.X, g.Z, yaw, folder)
				m.Name = T.gate
			end
		end
		addFoot(string.format("필지%02d_%s", pi, p[1]), "plot", p[2], p[3], T.W, T.D, yaw)
		plotCount[p[1]] = (plotCount[p[1]] or 0) + 1
		if pi % 4 == 0 then
			task.wait()
		end
	end

	--==================================================================== 6. 어귀 시설
	local FEATURE_SIZE = { Pavilion_Jeongja = { 28, 31 }, Prop_Well = { 8, 8 } }
	for i, e in ipairs(FEATURES) do
		local yaw = e[5] and yawToward(e[2], e[3], e[4], e[5]) or e[4]
		local m = place(e[1], e[2], e[3], yaw, F.Features)
		m.Name = string.format("%s_%d", e[1], i)
		local s = FEATURE_SIZE[e[1]]
		-- 언덕 정자는 오르는 길이 계단 앞에서 끝나므로 길과의 겹침에서 뺀다
		addFoot(m.Name, (i >= 5) and "hill" or "feature", e[2], e[3], s[1], s[2], yaw)
	end

	--==================================================================== 7. 나무
	local cleared = SS:FindFirstChild("Jeolhwa_ClearedFlora")
	if not cleared then
		cleared = Instance.new("Folder")
		cleared.Name = "Jeolhwa_ClearedFlora"
		cleared.Parent = SS
	end
	local floraRoots = {}
	for _, r in ipairs({ "R_평원", "R_숲" }) do
		local f = workspace.Surface:FindFirstChild(r)
		if f and f:FindFirstChild("Flora") then
			floraRoots[#floraRoots + 1] = f.Flora
		end
	end
	-- 앞서 옮긴 것을 먼저 제자리로 돌린다. 다시 돌려도 나무가 쌓여 사라지지 않게 한다
	local byPath = {}
	for _, r in ipairs(floraRoots) do
		byPath[r:GetFullName()] = r
	end
	for _, c in ipairs(cleared:GetChildren()) do
		local home = byPath[c:GetAttribute("OriginalParent") or ""]
		if home then
			c.Parent = home
		end
	end
	-- **나무 한 그루는 이름 앞머리로 묶인다.** Pln_Tree_9_B1t_L2 처럼 파트가 낱개로 들어 있다
	local function treeKey(p)
		return p.Parent:GetFullName() .. "/" .. (p.Name:match("^(.-_%d+)_") or p.Name)
	end
	local trees, plainKeys = {}, {}
	for _, r in ipairs(floraRoots) do
		for _, p in ipairs(r:GetDescendants()) do
			if p:IsA("BasePart") then
				local k = treeKey(p)
				if not trees[k] then
					trees[k] = {}
					if r.Parent.Name == "R_평원" then
						plainKeys[#plainKeys + 1] = k
					end
				end
				table.insert(trees[k], p)
			end
		end
	end
	table.sort(plainKeys)

	-- 옮겨 심을 나무. 원래 나무를 복제해 뿌리 밑을 땅에 0.5 묻는다
	for i, t in ipairs(TREES) do
		local src = trees[plainKeys[((i * 3) % #plainKeys) + 1]]
		local model = Instance.new("Model")
		model.Name = "Tree_" .. i
		local minY, rx, rz = math.huge, 0, 0
		for _, p in ipairs(src) do
			local c = p:Clone()
			c.Parent = model
			if c.Position.Y - c.Size.Y / 2 < minY then
				minY = c.Position.Y - c.Size.Y / 2
			end
			if c.Name:match("_Root$") then
				rx, rz = c.Position.X, c.Position.Z
			end
		end
		if rx == 0 and rz == 0 then
			local cf0 = model:GetBoundingBox()
			rx, rz = cf0.X, cf0.Z
		end
		model.Parent = F.Trees
		local gy = assert(groundY(t[1], t[2]), "나무 자리에 땅이 없다")
		model:PivotTo(model:GetPivot() + Vector3.new(t[1] - rx, gy - 0.5 - minY, t[2] - rz))
		addFoot(model.Name, "feature", t[1], t[2], 22, 22, 0)
	end

	-- 원래 나무 비키기. 앉힌 것에 걸린 나무를 그루째 옮긴다
	local op = OverlapParams.new()
	op.FilterType = Enum.RaycastFilterType.Include
	op.FilterDescendantsInstances = floraRoots
	local movedFlora, movedTrees = 0, 0
	local function clearArea(cf, size)
		for _, part in ipairs(workspace:GetPartBoundsInBox(cf, size, op)) do
			if part.Parent ~= cleared then
				for _, p in ipairs(trees[treeKey(part)] or { part }) do
					if p.Parent ~= cleared then
						p:SetAttribute("OriginalParent", p.Parent:GetFullName())
						p.Parent = cleared
						movedFlora = movedFlora + 1
					end
				end
				movedTrees = movedTrees + 1
			end
		end
	end
	for _, e in ipairs(placed) do
		local cf, size = e.m:GetBoundingBox()
		clearArea(cf, size + Vector3.new(6, 60, 6))
	end
	for _, d in ipairs(F.Roads:GetDescendants()) do
		if d:IsA("BasePart") then
			clearArea(d.CFrame, d.Size + Vector3.new(4, 60, 4))
		end
	end
	for _, d in ipairs(F.Terrace:GetChildren()) do
		clearArea(d.CFrame, d.Size + Vector3.new(4, 60, 4))
	end

	--==================================================================== 8. 검사
	local counts = {}
	for _, e in ipairs(placed) do
		counts[e.kind] = (counts[e.kind] or 0) + 1
	end
	local keys = {}
	for k in pairs(counts) do
		keys[#keys + 1] = k
	end
	table.sort(keys)
	for _, k in ipairs(keys) do
		say("%s x%d", k, counts[k])
	end
	for k, n in pairs(plotCount) do
		say("필지 %s x%d", k, n)
	end
	say("축대 %d개, 가장 큰 땅 높이차 %.2f", foundations, maxGap)
	say("옮긴 나무 %d그루 / 파트 %d", movedTrees, movedFlora)

	for _, k in ipairs(KEEP) do
		addFoot(k[1], "keep", k[2], k[3], k[4], k[5], 0)
	end
	-- 무엇과 무엇을 견주는가. 길끼리, 고정 자리끼리는 맞닿는 게 정상이다
	local RULE = {
		plot = { plot = true, road = true, feature = true, hill = true, keep = true },
		feature = { road = true, feature = true, keep = true, hill = true },
		hill = { keep = true },
		road = { keep = false },
	}
	local overlaps = 0
	for i = 1, #footprints do
		for j = i + 1, #footprints do
			local a, b = footprints[i], footprints[j]
			local ra, rb = RULE[a.group], RULE[b.group]
			if (ra and ra[b.group]) or (rb and rb[a.group]) then
				if obbOverlap(a, b) then
					overlaps = overlaps + 1
					if overlaps <= 40 then
						say("겹침 %s <-> %s", a.name, b.name)
					end
				end
			end
		end
	end
	say("겹침 %d쌍", overlaps)

	local n = 0
	for _, d in ipairs(city:GetDescendants()) do
		if d:IsA("BasePart") then
			n = n + 1
		end
	end
	say("파트 합계 %d", n)
end)
if not okRun then
	say("ERR %s", tostring(errRun))
end
print(table.concat(report, "\n"))
local HS = game:GetService("HttpService")
local was = HS.HttpEnabled
HS.HttpEnabled = true
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/city", table.concat(report, "\n"))
end)
HS.HttpEnabled = was
