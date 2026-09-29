--!nocheck
--[[
	Sanctuary_Kit.luau — 2026-09-27. 블렌더 합본 SanctuaryKit.fbx 를 탑의 성역 모델 틀로 가른다.

	Workspace.SanctuaryKit 의 메시를 이름 앞머리로 모델별로 나누고, 원점 표지(SancOrigin_Marker)를 빼서
	블렌더 원점(바닥 가운데)을 피벗으로 되찾는다. 재질은 SKIN 표대로. 틀은 ServerStorage.SanctuaryKit.
	충돌: 탑 토막은 끈다(복잡한 메시라 껍질 충돌이 계단을 막는다. 계단·기둥은 Sanctuary_Build 가 보이지 않는 파트로 잡는다).
	      걸어 들어가거나 올라서는 것(기단, 사당, 정자, 큰 문, 무더기)은 정밀 분해, 나머지는 껍질.
	      빛·잎·꽃은 부딪히지 않는다. 도는 파편도.
	LampPt 는 보이지 않게 하고 푸른 점광원을 단다.
	소스: models/build_sanctuary.py, 합본 models/build_kit_sanctuary.py
]]

local RGB = Color3.fromRGB
local M = Enum.Material
local SKIN = {
	Marble = { RGB(233, 230, 220), M.Marble },
	Shade = { RGB(196, 192, 179), M.Limestone },
	Cobalt = { RGB(36, 71, 143), M.SmoothPlastic },
	Gold = { RGB(201, 162, 74), M.Metal },
	Rune = { RGB(122, 202, 255), M.Neon },
	Stone = { RGB(142, 138, 128), M.Slate },
	Bronze = { RGB(107, 86, 53), M.Metal },
	Leaf = { RGB(47, 90, 60), M.Grass },
	LeafLight = { RGB(110, 154, 90), M.Grass },
	Bark = { RGB(107, 90, 74), M.Wood },
	Blossom = { RGB(243, 231, 235), M.SmoothPlastic },
	LampPt = { RGB(255, 255, 255), M.SmoothPlastic },
}
local NOCOLLIDE = { Rune = true, LampPt = true, Leaf = true, LeafLight = true, Blossom = true }
local NOCOLLIDE_MODEL = {
	Tower_S1 = true, Tower_S2 = true, Tower_S3 = true, Tower_S4 = true, Tower_S5 = true, Tower_S6 = true,
	Debris_Rib = true, Debris_Step = true, Debris_Drum = true,
}
local PRECISE = {
	Tower_Plinth = true, Tholos = true, Pavilion = true, Great_Gate = true, Chunk_Rib = true, Chunk_Block = true,
	Col_Fallen = true, Statue_Broken = true,
}
-- 여럿 놓이는 작은 것은 멀리서 줄여 그린다
local AUTO_LOD = {
	Balustrade = true, Cypress = true, Cypress_Tall = true, Blossom = true, Blossom_B = true, Lantern_Blue = true,
}
local PREFIX = {
	TwPl = "Tower_Plinth", ColI = "Col_Intact", ColA = "Col_BrokenA", ColB = "Col_BrokenB", ColF = "Col_Fallen",
	Lint = "Lintel", GGate = "Great_Gate", Tholos = "Tholos", Pavil = "Pavilion", Guard = "Guardian",
	LantB = "Lantern_Blue", Obel = "Obelisk", Bench = "Bench", Cyp = "Cypress", CypT = "Cypress_Tall",
	Blos = "Blossom", BlosB = "Blossom_B", ChRib = "Chunk_Rib", ChBlk = "Chunk_Block", DebR = "Debris_Rib",
	DebS = "Debris_Step", DebD = "Debris_Drum", Balu = "Balustrade", StatB = "Statue_Broken",
	Tw1 = "Tower_S1", Tw2 = "Tower_S2", Tw3 = "Tower_S3", Tw4 = "Tower_S4", Tw5 = "Tower_S5", Tw6 = "Tower_S6",
}

local report = {}
local function say(f, ...)
	report[#report + 1] = string.format(f, ...)
end

local function skin(p, key, modelName)
	local s = assert(SKIN[key], "모르는 재질 이름 " .. p.Name)
	p.Color = s[1]
	p.Material = s[2]
	p.Anchored = true
	p.CanCollide = not NOCOLLIDE[key] and not NOCOLLIDE_MODEL[modelName]
	p.CastShadow = key ~= "Rune" and key ~= "LampPt"
	p.CollisionFidelity = PRECISE[modelName] and Enum.CollisionFidelity.PreciseConvexDecomposition
		or Enum.CollisionFidelity.Hull
	p.RenderFidelity = AUTO_LOD[modelName] and Enum.RenderFidelity.Automatic or Enum.RenderFidelity.Precise
	if key == "LampPt" then
		p.Transparency = 1
		p.CanQuery = false
		p.CanTouch = false
		local l = Instance.new("PointLight")
		l.Color = RGB(140, 205, 255)
		l.Brightness = 1.3
		l.Range = 16
		l.Shadows = false
		l.Parent = p
	end
end

local ok, err = pcall(function()
	local SS = game:GetService("ServerStorage")
	local kit = SS:FindFirstChild("SanctuaryKit")
	if not kit then
		kit = Instance.new("Folder")
		kit.Name = "SanctuaryKit"
		kit.Parent = SS
	end
	local imp = workspace:FindFirstChild("SanctuaryKit")
	if imp then
		local marker = assert(imp:FindFirstChild("SancOrigin_Marker", true), "원점 표지가 없다")
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
		local cf, size = kit[name]:GetBoundingBox()
		say("%-14s 가운데 %.1f %.1f %.1f  크기 %.1f %.1f %.1f", name, cf.X, cf.Y, cf.Z, size.X, size.Y, size.Z)
	end
end)
if not ok then
	say("ERR %s", tostring(err))
end
local HS = game:GetService("HttpService")
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/sanckit", table.concat(report, "\n"))
end)
print("sanckit", #report, ok)
