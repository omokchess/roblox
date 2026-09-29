--!nocheck
--[[
	Jeolhwa_Props.luau — 2026-09-27. 블렌더 합본 JeolhwaProps.fbx 를 절화 안살림 소품 틀로 가른다.

	Workspace.JeolhwaProps 의 메시를 이름 앞머리로 모델별로 나누고, 원점 표지(HanokOrigin_Marker)를
	빼서 블렌더 원점(바닥 가운데)을 피벗으로 되찾는다. 재질은 아래 SKIN 표대로 입힌다.
	  LampPt  보이지 않게 하고 따뜻한 작은 점광원을 단다 (방 안이라 반경을 줄였다)
	  Glass   반투명
	충돌: 가구는 껍질(Hull)로 잡고, 불빛·금박·한지·먹처럼 얇은 꾸밈과 머리 위에 매다는 초롱·닫집은 부딪히지 않는다.
	틀은 ServerStorage.JeolhwaProps 에 넣는다. 끝에 모든 틀의 로컬 발자국을 잰다.
	소품 소스는 models/build_hanok_props.py (치수는 스터드, 배율 1).
]]

local RGB = Color3.fromRGB
local M = Enum.Material
local SKIN = {
	Wood = { RGB(154, 107, 69), M.Wood },
	WoodDark = { RGB(78, 51, 37), M.Wood },
	Lacquer = { RGB(142, 43, 34), M.SmoothPlastic },
	Gold = { RGB(201, 162, 74), M.Metal },
	Brass = { RGB(184, 145, 63), M.Metal },
	Iron = { RGB(58, 60, 66), M.Metal },
	Paper = { RGB(232, 223, 200), M.SmoothPlastic },
	Ink = { RGB(30, 27, 26), M.SmoothPlastic },
	SilkBlue = { RGB(60, 92, 140), M.Fabric },
	SilkRed = { RGB(163, 58, 58), M.Fabric },
	SilkGreen = { RGB(79, 122, 88), M.Fabric },
	SilkYellow = { RGB(216, 180, 90), M.Fabric },
	Celadon = { RGB(143, 181, 165), M.SmoothPlastic },
	Porcelain = { RGB(237, 235, 227), M.SmoothPlastic },
	Onggi = { RGB(92, 63, 49), M.SmoothPlastic },
	Straw = { RGB(191, 164, 106), M.Fabric },
	Stone = { RGB(142, 138, 128), M.Slate },
	Clay = { RGB(138, 106, 78), M.Concrete },
	Sky = { RGB(34, 70, 150), M.SmoothPlastic }, -- 따뜻한 등불 아래서도 푸르게 보이게 짙고 맑게
	Peak = { RGB(47, 109, 76), M.SmoothPlastic },
	Glow = { RGB(255, 198, 107), M.Neon },
	Bone = { RGB(224, 214, 190), M.SmoothPlastic },
	Hide = { RGB(138, 101, 70), M.Fabric },
	Glass = { RGB(200, 225, 235), M.Glass },
	Tile = { RGB(72, 74, 72), M.Slate },
	Soil = { RGB(110, 86, 62), M.Ground },
	Fruit = { RGB(224, 124, 48), M.SmoothPlastic },
	LampPt = { RGB(255, 255, 255), M.SmoothPlastic },
	Granite = { RGB(193, 190, 176), M.Limestone }, -- 궁 갓돌·다리 돌과 같은 빛
	Leaf = { RGB(108, 132, 66), M.Grass },
	Napa = { RGB(156, 192, 99), M.SmoothPlastic },
	NapaPale = { RGB(220, 228, 180), M.SmoothPlastic },
	CabbLeaf = { RGB(76, 138, 60), M.SmoothPlastic },
	Barley = { RGB(201, 190, 114), M.Fabric },
	Chili = { RGB(179, 38, 30), M.SmoothPlastic },
	Jeon1 = { RGB(124, 119, 107), M.Slate }, -- 정전 전돌
	Jeon2 = { RGB(135, 129, 115), M.Slate },
	Jeon3 = { RGB(112, 107, 96), M.Slate },
	DanGreen = { RGB(47, 123, 105), M.SmoothPlastic }, -- 단청
	DanBlue = { RGB(44, 90, 116), M.SmoothPlastic },
	Bronze = { RGB(107, 86, 53), M.Metal },
	SilkWhite = { RGB(233, 228, 214), M.Fabric },
	LanternSilk = { RGB(200, 80, 58), M.Neon }, -- 불 켠 궁등 비단
}
local NOCOLLIDE = { Glow = true, LampPt = true, Gold = true, Paper = true, Ink = true }
-- 좌판 진열품은 좌판 위에 얹는 꾸밈이라 부딪히지 않는다(좌판이 막는다)
local NOCOLLIDE_MODEL = {
	Chorong = true, Datjip = true,
	Stall_Cloth = true, Stall_Jars = true, Stall_Crates = true, Stall_Baskets = true,
	-- 밭 이랑은 밟고 지나간다
	Crop_Barley = true, Crop_Cabbage = true, Crop_Bean = true, Crop_Radish = true, Crop_Pepper = true,
	-- 정전 바닥 전돌은 방바닥보다 0.03 높을 뿐이라 방바닥이 받친다. 천장·궁등은 머리 위
	Jeondol_Hall = true, Ceiling_Hall = true, Gungdeung = true, Gungdeung_Short = true,
}

local PREFIX = {
	TDais = "Throne_Dais", Throne = "Throne_Chair", Ilwol = "Irworobongdo", Datjip = "Datjip",
	Hyang = "Hyangro", Chot = "Chotdae", Byeong = "Byeongpung", Boryo = "Boryo",
	Seoan = "Seoan", Mungap = "Mungap", Bandaji = "Bandaji", Jang = "Ijeongjang",
	Deung = "Deungjan", Gyeong = "Gyeongdae", Takja = "Sabang_Takja", Hwaro = "Hwaro",
	Buttu = "Buttumak", Chan = "Chanjang", Soban = "Soban", Pyeong = "Pyeongsang",
	Suldok = "Suldok", Chorong = "Chorong", Counter = "Counter", Sirung = "Sirung",
	Spec = "Specimen_Shelf", Yak = "Yakjang", Haebu = "Haebudae", Malim = "Malim",
	Gwe = "Gwe", Gamani = "Gamani", Duiju = "Duiju", Meong = "Meongseok",
	SCloth = "Stall_Cloth", SJars = "Stall_Jars", SCrate = "Stall_Crates", SBasket = "Stall_Baskets",
	YJang = "Yard_Jangdok", YWell = "Yard_Well", YHay = "Yard_Haystack", YGard = "Yard_Garden",
	Pumgye = "Pumgye", CBarley = "Crop_Barley", CCabb = "Crop_Cabbage", CBean = "Crop_Bean",
	CRadish = "Crop_Radish", CPepper = "Crop_Pepper",
	BRail13 = "Bridge_Rail_13", BRail15 = "Bridge_Rail_15", BRail21 = "Bridge_Rail_21", BRail25 = "Bridge_Rail_25",
	Jeondol = "Jeondol_Hall", Ceil = "Ceiling_Hall", GiBlue = "Uijang_GiBlue", GiRed = "Uijang_GiRed",
	GiYel = "Uijang_GiYellow", GiWhite = "Uijang_GiWhite", IlsanR = "Uijang_IlsanRed", IlsanB = "Uijang_IlsanBlue",
	Seon = "Uijang_Seon", Jong = "Pyeonjong", Gyeong2 = "Pyeongyeong", Geongo = "Geongo", Deung2 = "Gungdeung",
	DeungS = "Gungdeung_Short", Deumeu = "Deumeu", Jeong = "Jeong", Seosu = "Seosu", Bang = "Bangseok", Akgi = "Akgi_Set",
}

local report = {}
local function say(f, ...)
	report[#report + 1] = string.format(f, ...)
end

local function skin(p, key, modelName)
	local s = assert(SKIN[key], "모르는 재질 이름 " .. p.Name)
	p.Color = s[1]
	p.Material = s[2]
	-- 궁 의장(깃·일산·봉선)의 비단은 공단처럼 매끈하게. 올 무늬 재질은 등불 아래서 짚바구니처럼 보인다
	if modelName:match("^Uijang_") and key:match("^Silk") then
		p.Material = M.SmoothPlastic
	end
	p.Anchored = true
	p.CanCollide = not NOCOLLIDE[key] and not NOCOLLIDE_MODEL[modelName]
	p.CastShadow = key ~= "Glow" and key ~= "LampPt"
	p.CollisionFidelity = Enum.CollisionFidelity.Hull
	-- 밭 이랑 토막은 수백 개라 멀리서는 줄여 그린다
	p.RenderFidelity = modelName:match("^Crop_") and Enum.RenderFidelity.Automatic or Enum.RenderFidelity.Precise
	if key == "Glass" then
		p.Transparency = 0.55
		p.CastShadow = false
	end
	if key == "LampPt" then
		p.Transparency = 1
		p.CanQuery = false
		p.CanTouch = false
		local l = Instance.new("PointLight")
		l.Color = RGB(255, 190, 120)
		-- 경회루 궁등은 좁은 마루에 아홉이 모여 한데 겹치면 온통 주황이 된다
		l.Brightness = modelName == "Gungdeung_Short" and 0.55 or 1.2
		l.Range = modelName == "Gungdeung_Short" and 12 or 14
		l.Shadows = false
		l.Parent = p
	end
end

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

local ok, err = pcall(function()
	local SS = game:GetService("ServerStorage")
	local kit = SS:FindFirstChild("JeolhwaProps")
	if not kit then
		kit = Instance.new("Folder")
		kit.Name = "JeolhwaProps"
		kit.Parent = SS
	end
	local imp = workspace:FindFirstChild("JeolhwaProps")
	if imp then
		local marker = assert(imp:FindFirstChild("HanokOrigin_Marker", true), "원점 표지가 없다")
		local o = marker.Position
		say("표지 %.2f %.2f %.2f", o.X, o.Y, o.Z)
		local groups = {}
		for _, p in ipairs(imp:GetDescendants()) do
			if p:IsA("BasePart") and p ~= marker then
				local pre, key = p.Name:match("^([^_]+)_(.+)$")
				local name = assert(PREFIX[pre], "모르는 앞머리 " .. p.Name)
				groups[name] = groups[name] or {}
				table.insert(groups[name], { p = p, key = key })
			end
		end
		local n = 0
		for name, list in pairs(groups) do
			local old = kit:FindFirstChild(name)
			if old then
				old:Destroy()
			end
			local m = Instance.new("Model")
			m.Name = name
			for _, e in ipairs(list) do
				e.p.CFrame = e.p.CFrame - o
				skin(e.p, e.key, name)
				e.p.Parent = m
			end
			m.WorldPivot = CFrame.new()
			m.Parent = kit
			n += 1
		end
		imp:Destroy()
		say("새 틀 %d 종", n)
	end
	local names = {}
	for _, m in ipairs(kit:GetChildren()) do
		names[#names + 1] = m.Name
	end
	table.sort(names)
	for _, name in ipairs(names) do
		local m = kit[name]
		local frame = m:GetPivot()
		local minY = math.huge
		local parts = {}
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") and p.Transparency < 1 then
				local e, c = halfExtents(p, frame)
				parts[#parts + 1] = { e = e, c = c }
				minY = math.min(minY, c.Y - e.Y)
			end
		end
		local b = { math.huge, -math.huge, math.huge, -math.huge }
		local a = { math.huge, -math.huge, math.huge, -math.huge, -math.huge }
		for _, q in ipairs(parts) do
			local e, c = q.e, q.c
			a[1], a[2] = math.min(a[1], c.X - e.X), math.max(a[2], c.X + e.X)
			a[3], a[4] = math.min(a[3], c.Z - e.Z), math.max(a[4], c.Z + e.Z)
			a[5] = math.max(a[5], c.Y + e.Y)
			if c.Y - e.Y < minY + 0.3 then
				b[1], b[2] = math.min(b[1], c.X - e.X), math.max(b[2], c.X + e.X)
				b[3], b[4] = math.min(b[3], c.Z - e.Z), math.max(b[4], c.Z + e.Z)
			end
		end
		say("%s base %.1f %.1f %.1f %.1f all %.1f %.1f %.1f %.1f h %.1f minY %.2f n %d",
			name, b[1], b[2], b[3], b[4], a[1], a[2], a[3], a[4], a[5], minY, #parts)
	end
end)
if not ok then
	say("ERR %s", tostring(err))
end
local HS = game:GetService("HttpService")
local was = HS.HttpEnabled
HS.HttpEnabled = true
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/hanokprops", table.concat(report, "\n"))
end)
HS.HttpEnabled = was
print("hanokprops", #report, ok)
