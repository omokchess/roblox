--!strict
--[[
	Callisto — 히든 보스 칼리스토의 몸(2026-10-31). 사람 모양이라 R6 관절을 그대로 쓴다(CombatRig·전투 모션·무기가 붙는다).

	사양: 큰곰자리 · 천문학자 · 시인, 슈네라이히 기물군의 비숍. 사용 무기 = 의체(손에서 칼날, 손목에서 카메라 —
	무기 정의 WeaponDefinitions.CallistoArms 가 오른손 칼날·왼손 카메라를 붙인다).
	  - 체스 비숍 실루엣: 갈라진 주교관(미트라) + 별 단추
	  - 남색 긴 코트(앞자락이 열려 크림색 안감), 등에 큰곰자리 일곱 별 자수(빛)
	  - 두 팔은 의체: 쇳빛 판 + 팔꿈치·손목 마디의 푸른 빛줄
	  - 은발 · 오른눈 외눈 렌즈(천문학자)
	맵 양식대로 블록으로 짓는다(Part 조립 — 블렌더판은 나중). 장식은 관절 부품에 용접해 모션을 따라간다.
	정면 = 모델 -Z(전투에서는 아군 쪽).
]]

local Callisto = {}

local C = Color3.fromRGB
local COAT = C(28, 34, 72)
local COAT_DK = C(18, 22, 48)
local LINING = C(226, 214, 188)
local GOLD = C(214, 178, 96)
local SKIN = C(238, 214, 196)
local HAIR = C(214, 220, 232)
local METAL = C(70, 76, 92)
local METAL_LT = C(132, 140, 160)
local GLOW = C(140, 190, 255)

local function part(name: string, size: Vector3, color: Color3, material: Enum.Material?, shape: string?): Part
	local p = Instance.new(if shape == "Wedge" then "WedgePart" else "Part") :: any
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape == "Ball" then
		p.Shape = Enum.PartType.Ball
	elseif shape == "Cylinder" then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Anchored = false
	p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	return p
end

local function motor(name: string, p0: BasePart, p1: BasePart, c0: CFrame, c1: CFrame)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0, m.Part1, m.C0, m.C1 = p0, p1, c0, c1
	m.Parent = p0
end

-- 장식 하나를 관절 부품에 붙인다. at = 그 부품 공간 자리(x,y,z, 도 rx,ry,rz)
local function deco(model: Model, host: BasePart, name: string, size: Vector3, at: { number }, color: Color3, material: Enum.Material?, shape: string?): Part
	local p = part(name, size, color, material, shape)
	local rad = math.pi / 180
	p.CFrame = host.CFrame * CFrame.new(at[1], at[2], at[3]) * CFrame.Angles((at[4] or 0) * rad, (at[5] or 0) * rad, (at[6] or 0) * rad)
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = host, p
	weld.Parent = p
	p.Parent = model
	return p
end

function Callisto.Build(name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), COAT)
	root.Transparency = 1
	root.Anchored = true
	local torso = part("Torso", Vector3.new(2, 2, 1), COAT)
	local head = part("Head", Vector3.new(2, 1, 1), SKIN)
	local rightArm = part("Right Arm", Vector3.new(1, 2, 1), METAL, Enum.Material.Metal)
	local leftArm = part("Left Arm", Vector3.new(1, 2, 1), METAL, Enum.Material.Metal)
	local rightLeg = part("Right Leg", Vector3.new(1, 2, 1), COAT_DK)
	local leftLeg = part("Left Leg", Vector3.new(1, 2, 1), COAT_DK)
	for _, p in { root, torso, head, rightArm, leftArm, rightLeg, leftLeg } do
		p.Parent = model
	end
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = head
	motor("RootJoint", root, torso, CFrame.new(), CFrame.new())
	motor("Neck", torso, head, CFrame.new(0, 1, 0), CFrame.new(0, -0.5, 0))
	motor("Right Shoulder", torso, rightArm, CFrame.new(1, 0.5, 0), CFrame.new(-0.5, 0.5, 0))
	motor("Left Shoulder", torso, leftArm, CFrame.new(-1, 0.5, 0), CFrame.new(0.5, 0.5, 0))
	motor("Right Hip", torso, rightLeg, CFrame.new(0.5, -1, 0), CFrame.new(0, 1, 0))
	motor("Left Hip", torso, leftLeg, CFrame.new(-0.5, -1, 0), CFrame.new(0, 1, 0))
	model.PrimaryPart = root
	-- 관절 자리에 부품을 놓은 뒤 장식을 용접한다(용접은 지금 자리 관계를 굳힌다)
	model:PivotTo(CFrame.new())
	torso.CFrame = root.CFrame
	head.CFrame = torso.CFrame * CFrame.new(0, 1.5, 0)
	rightArm.CFrame = torso.CFrame * CFrame.new(1.5, 0, 0)
	leftArm.CFrame = torso.CFrame * CFrame.new(-1.5, 0, 0)
	rightLeg.CFrame = torso.CFrame * CFrame.new(0.5, -2, 0)
	leftLeg.CFrame = torso.CFrame * CFrame.new(-0.5, -2, 0)

	-- 코트: 열린 앞자락 사이 크림 안감, 금 단추 셋, 높은 깃
	deco(model, torso, "Lining", Vector3.new(0.7, 1.9, 0.05), { 0, 0, -0.51 }, LINING)
	deco(model, torso, "LapelL", Vector3.new(0.18, 1.9, 0.06), { -0.42, 0, -0.53 }, GOLD, Enum.Material.Metal)
	deco(model, torso, "LapelR", Vector3.new(0.18, 1.9, 0.06), { 0.42, 0, -0.53 }, GOLD, Enum.Material.Metal)
	for i, y in { 0.55, 0.05, -0.45 } do
		deco(model, torso, "Button" .. i, Vector3.new(0.16, 0.16, 0.16), { 0, y, -0.55 }, GOLD, Enum.Material.Metal, "Ball")
	end
	deco(model, torso, "Collar", Vector3.new(2.15, 0.35, 1.15), { 0, 0.95, 0.02 }, COAT_DK)
	deco(model, torso, "Mantle", Vector3.new(2.4, 0.22, 1.25), { 0, 0.88, 0.02 }, COAT)
	-- 긴 코트 자락(뒤로 늘어진 두 폭 — 다리 뒤에 떠서 걸음을 막지 않게)
	deco(model, torso, "TailL", Vector3.new(0.95, 2.3, 0.14), { -0.5, -1.95, 0.56, 6, 0, -3 }, COAT)
	deco(model, torso, "TailR", Vector3.new(0.95, 2.3, 0.14), { 0.5, -1.95, 0.56, 6, 0, 3 }, COAT)
	deco(model, torso, "Hem", Vector3.new(2.05, 0.12, 0.16), { 0, -3.08, 0.68, 6, 0, 0 }, GOLD, Enum.Material.Metal)
	deco(model, torso, "Belt", Vector3.new(2.05, 0.2, 1.06), { 0, -0.82, 0 }, COAT_DK)
	deco(model, torso, "Buckle", Vector3.new(0.32, 0.26, 0.08), { 0, -0.82, -0.54 }, GOLD, Enum.Material.Metal)
	-- 등의 큰곰자리(국자 넷 + 손잡이 셋) 자수 — 빛나는 점
	for i, p in { { -0.62, 0.55 }, { -0.18, 0.62 }, { -0.12, 0.2 }, { -0.6, 0.12 }, { 0.22, 0.05 }, { 0.5, -0.2 }, { 0.78, -0.5 } } do
		deco(model, torso, "Star" .. i, Vector3.new(0.12, 0.12, 0.05), { p[1], p[2], 0.53 }, GLOW, Enum.Material.Neon)
	end
	-- 가슴의 별 브로치
	deco(model, torso, "Brooch", Vector3.new(0.26, 0.26, 0.08), { -0.62, 0.55, -0.56, 0, 0, 45 }, C(200, 225, 255), Enum.Material.Neon)

	-- 머리: 은발(뒤·옆), 주교관(갈라진 두 쐐기 + 금테 + 별), 외눈 렌즈
	deco(model, head, "HairBack", Vector3.new(1.3, 1.5, 0.45), { 0, -0.3, 0.42 }, HAIR)
	deco(model, head, "HairL", Vector3.new(0.22, 1.1, 1.0), { -0.66, -0.15, 0.05 }, HAIR)
	deco(model, head, "HairR", Vector3.new(0.22, 1.1, 1.0), { 0.66, -0.15, 0.05 }, HAIR)
	deco(model, head, "Fringe", Vector3.new(1.32, 0.2, 0.25), { 0, 0.5, -0.5 }, HAIR)
	deco(model, head, "MitreBand", Vector3.new(1.34, 0.22, 1.34), { 0, 0.62, 0 }, GOLD, Enum.Material.Metal)
	-- 쐐기는 높은 면이 +Z: 앞 반쪽은 그대로(높은 면이 가운데), 뒤 반쪽은 돌려서 — 가운데가 솟은 갈라진 관
	deco(model, head, "MitreF", Vector3.new(1.2, 1.25, 0.6), { 0, 1.32, -0.3 }, LINING, nil, "Wedge")
	deco(model, head, "MitreB", Vector3.new(1.2, 1.25, 0.6), { 0, 1.32, 0.3, 0, 180, 0 }, LINING, nil, "Wedge")
	deco(model, head, "MitreStripe", Vector3.new(0.16, 1.3, 1.24), { 0, 1.3, 0 }, GOLD, Enum.Material.Metal)
	deco(model, head, "MitreStar", Vector3.new(0.24, 0.24, 0.06), { 0, 1.15, -0.62, 0, 0, 45 }, GLOW, Enum.Material.Neon)
	deco(model, head, "MonocleRim", Vector3.new(0.05, 0.36, 0.36), { 0.24, 0.12, -0.62, 0, 90, 0 }, GOLD, Enum.Material.Metal, "Cylinder")
	deco(model, head, "MonocleLens", Vector3.new(0.03, 0.28, 0.28), { 0.24, 0.12, -0.64, 0, 90, 0 }, C(170, 220, 255), Enum.Material.Glass, "Cylinder").Transparency = 0.4
	deco(model, head, "MonocleChain", Vector3.new(0.04, 0.6, 0.04), { 0.44, -0.2, -0.6, 0, 0, 25 }, GOLD, Enum.Material.Metal)

	-- 의체 팔: 어깨 덮개 · 팔꿈치 고리 · 손목 고리(푸른 빛줄) · 판 이음선
	for _, arm in { rightArm, leftArm } do
		local side = if arm == rightArm then 1 else -1
		deco(model, arm, "Pauldron", Vector3.new(1.25, 0.5, 1.2), { 0.05 * side, 0.85, 0 }, METAL_LT, Enum.Material.Metal)
		deco(model, arm, "PauldronGlow", Vector3.new(1.27, 0.06, 1.22), { 0.05 * side, 0.62, 0 }, GLOW, Enum.Material.Neon)
		deco(model, arm, "Elbow", Vector3.new(1.06, 0.22, 1.06), { 0, -0.05, 0 }, METAL_LT, Enum.Material.Metal)
		deco(model, arm, "ElbowGlow", Vector3.new(1.08, 0.05, 1.08), { 0, -0.05, 0 }, GLOW, Enum.Material.Neon)
		deco(model, arm, "Wrist", Vector3.new(1.05, 0.16, 1.05), { 0, -0.72, 0 }, METAL_LT, Enum.Material.Metal)
		deco(model, arm, "WristGlow", Vector3.new(1.07, 0.04, 1.07), { 0, -0.72, 0 }, GLOW, Enum.Material.Neon)
		deco(model, arm, "Seam", Vector3.new(0.04, 1.3, 0.04), { 0.51 * side, -0.35, -0.3 }, C(30, 32, 40), Enum.Material.Metal)
		deco(model, arm, "Hand", Vector3.new(0.9, 0.36, 0.9), { 0, -0.98, 0 }, C(56, 60, 74), Enum.Material.Metal)
	end
	-- 다리: 긴 부츠
	for _, leg in { rightLeg, leftLeg } do
		deco(model, leg, "Boot", Vector3.new(1.06, 0.9, 1.1), { 0, -0.58, -0.03 }, C(30, 24, 26))
		deco(model, leg, "BootCuff", Vector3.new(1.1, 0.14, 1.12), { 0, -0.1, -0.03 }, GOLD, Enum.Material.Metal)
	end
	return model
end

return Callisto
