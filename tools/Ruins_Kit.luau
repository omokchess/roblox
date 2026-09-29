--!nocheck
--[[
	Ruins_Kit.luau — 2026-09-27. 블렌더 합본 RuinsKit.fbx 를 탑의 성역 재작업 틀로 가른다 → ServerStorage.RuinsKit

	앞머리로 모델을 나누고 원점 표지(RuinsOrigin_Marker)로 블렌더 원점을 피벗으로 되찾는다.
	색은 기존 성역 그대로(회백 돌 206,202,186 ~ 풍화 118,120,112, Limestone/Slate, 따뜻한 불빛, 코어 푸른 빛, 검은 물).
	충돌: 탑 토막·도는 파편·떠 있는 바위 윗돌·불빛은 끈다(탑 계단·기둥은 Ruins_Build 가 보이지 않는 파트로 잡는다).
	      올라서거나 드나드는 큰 것은 정밀 분해, 나머지는 껍질.
	소스: models/build_ruins.py, 합본 models/build_kit_ruins.py
]]
local RGB = Color3.fromRGB
local M = Enum.Material
local SKIN = {
	Stone = { RGB(206, 202, 186), M.Limestone },
	Stone2 = { RGB(186, 182, 168), M.Limestone },
	Stone3 = { RGB(164, 162, 150), M.Limestone },
	Weather = { RGB(118, 120, 112), M.Slate },
	Joint = { RGB(128, 128, 120), M.Slate },
	Glow = { RGB(255, 214, 140), M.Neon },
	Blue = { RGB(122, 202, 255), M.Neon },
	Water = { RGB(30, 44, 58), M.SmoothPlastic },
	LampPt = { RGB(255, 255, 255), M.SmoothPlastic },
}
local NOCOLLIDE = { Glow = true, Blue = true, LampPt = true, Joint = true }
local NOCOLLIDE_MODEL = {
	Tower_S1 = true, Tower_S2 = true, Tower_S3 = true, Tower_S4 = true, Tower_S5 = true, Tower_S6 = true,
	Debris_A = true, Debris_B = true, Debris_C = true, Pave_Strip_A = true, Pave_Strip_B = true,
	Rubble_Field_A = true, Rubble_Field_B = true,
}
local PRECISE = {
	Tower_Podium = true, Gate_A = true, Gate_B = true, Arcade_A = true, Arcade_B = true, Arcade_C = true,
	Shrine_Pavilion = true, Shrine_Tower = true, Terrace_A = true, Terrace_B = true, Pool_Big = true, Pool_Mid = true,
	Colossus = true, Chunk_Tower_A = true, Chunk_Tower_B = true, Float_Rock_A = true, Float_Rock_B = true,
	Float_Rock_C = true, Edge_Wall_A = true, Edge_Wall_B = true, Edge_Tower = true, Ruin_Room_A = true, Ruin_Room_B = true,
	Rubble_Heap_A = true, Rubble_Heap_B = true, Col_Drums = true, Colossus_Head = true, Colossus_Hand = true,
}
local PREFIX = {
	RPod = "Tower_Podium", RColA = "Col_Big", RColB = "Col_Big_B", RColC = "Col_Big_C", RColD = "Col_Drums",
	RLint = "Lintel_Big", RGateA = "Gate_A", RGateB = "Gate_B", RArcA = "Arcade_A", RArcB = "Arcade_B",
	RArcC = "Arcade_C", RArcP = "Arcade_Pier", RShP = "Shrine_Pavilion", RShT = "Shrine_Tower", RTerA = "Terrace_A",
	RTerB = "Terrace_B", RPoolA = "Pool_Big", RPoolB = "Pool_Mid", RColo = "Colossus", RHead = "Colossus_Head",
	RHand = "Colossus_Hand", RStele = "Stele_Big", RAltar = "Altar_Big", RBraz = "Brazier_Big", RBeac = "Beacon_Base",
	RChA = "Chunk_Tower_A", RChB = "Chunk_Tower_B", RFlA = "Float_Rock_A", RFlB = "Float_Rock_B", RFlC = "Float_Rock_C",
	RDebA = "Debris_A", RDebB = "Debris_B", RDebC = "Debris_C", RWallA = "Edge_Wall_A", RWallB = "Edge_Wall_B",
	RWallT = "Edge_Tower", RRoomA = "Ruin_Room_A", RRoomB = "Ruin_Room_B", RRubA = "Rubble_Heap_A",
	RRubB = "Rubble_Heap_B", RFldA = "Rubble_Field_A", RFldB = "Rubble_Field_B", RPavA = "Pave_Strip_A",
	RPavB = "Pave_Strip_B", RTw1 = "Tower_S1", RTw2 = "Tower_S2", RTw3 = "Tower_S3", RTw4 = "Tower_S4", RTw5 = "Tower_S5",
	RTw6 = "Tower_S6",
}

local report = {}
local function skin(p, key, modelName)
	local s = assert(SKIN[key], "모르는 재질 이름 " .. p.Name)
	p.Color, p.Material = s[1], s[2]
	p.Anchored = true
	p.CanCollide = not NOCOLLIDE[key] and not NOCOLLIDE_MODEL[modelName]
	p.CastShadow = key ~= "Glow" and key ~= "LampPt" and key ~= "Blue"
	p.CollisionFidelity = PRECISE[modelName] and Enum.CollisionFidelity.PreciseConvexDecomposition
		or Enum.CollisionFidelity.Hull
	p.RenderFidelity = Enum.RenderFidelity.Automatic
	if key == "Water" then
		p.Reflectance = 0.12 -- 기존 반사지처럼 검은 물. 0.4 면 하늘을 비춰 파랗게 뜬다
	end
	if key == "LampPt" then
		p.Transparency = 1
		p.CanQuery = false
		p.CanTouch = false
		local l = Instance.new("PointLight")
		l.Color = RGB(255, 214, 140)
		l.Brightness = 1.4
		l.Range = 22
		l.Shadows = false
		l.Parent = p
	end
end

local ok, err = pcall(function()
	local SS = game:GetService("ServerStorage")
	local kit = SS:FindFirstChild("RuinsKit") or Instance.new("Folder")
	kit.Name = "RuinsKit"
	kit.Parent = SS
	local imp = workspace:FindFirstChild("RuinsKit")
	if imp then
		local marker = assert(imp:FindFirstChild("RuinsOrigin_Marker", true), "원점 표지가 없다")
		local o = marker.Position
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
		report[#report + 1] = string.format("새 틀 %d 종 (표지 %.1f %.1f %.1f)", n, o.X, o.Y, o.Z)
	end
	report[#report + 1] = "틀 " .. #kit:GetChildren()
end)
if not ok then
	report[#report + 1] = "ERR " .. tostring(err)
end
pcall(function()
	game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/ruinskit", table.concat(report, "\n"))
end)
print("ruinskit", table.concat(report, " / "))
