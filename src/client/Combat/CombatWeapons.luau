--!strict
--[[
	CombatWeapons — WeaponDefinitions 표로 무기를 **지어서 손에 붙인다**. (2026-09-28)

	무기 하나 = 손(오른손 W / 왼손 O)마다 조각(Piece) 하나. 조각은 보이지 않는 "Grip" 부품을
	중심으로 부품을 용접해 만들고, 팔과 Grip 을 Motor6D 로 잇는다. 모션의 W·O 값이 이
	모터의 Transform 이 된다(CombatRig:SetWeaponMotor).
	  모터 C0 = 팔 끝 (0,-1,0) · X -90°  (팔을 내리면 무기가 앞을 본다)
	떠 있는 무기(Hand = "Float", 펄서 오브)는 손에 안 붙이고 매 프레임 자리를 옮긴다(`Update`).
	등에 멘 무기(Hand = "Back", 청의 검사 검집)는 몸통에 붙인다 — 모터 C0 = 몸통 가운데, 모션의 O 값이 몸통 공간 자리·회전.

	새 무기를 표에 더하면 여기는 손대지 않아도 된다 — 모양·쥐는 점·궤적 점이 모두 표에 있다.

	블렌더 메시(2026-10-02): ReplicatedStorage.WeaponMeshes.<무기Id>.<Main|Off> 에 MeshPart 들이 있으면(tools/WeaponMeshes.luau 가 정리,
	각 MeshPart 의 속성 Offset = 쥐는 점 기준 자리) 그것을 복제해 Grip 에 용접하고 묶음 이름으로 Skins 의 색·재질을 입힌다.
	없으면 Parts 정의로 짓는다.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WeaponDefinitions = require(ReplicatedStorage.Shared.Combat.WeaponDefinitions)

local CombatWeapons = {}
CombatWeapons.__index = CombatWeapons

local RAD = math.pi / 180
local GRIP_C0 = CFrame.new(0, -1, 0) * CFrame.Angles(-math.pi / 2, 0, 0)

--[[
	사용자가 고친 쥐는 모양(2026-09-29 요청: "무기 잡고있는거 직접 변경할 수 있게").
	스튜디오 모션 무대(Workspace.MotionStudio.<직업>)의 인형 무기 모터(CombatWeapon/W/GripW 안의 CombatGripW)
	C0 를 속성 창에서 바꾸면, 플레이 때 MotionStudioService 가 ReplicatedStorage.MotionStudio.<직업> 속성
	GripW·GripO 로 넘긴다. R6 팔에 쥘 때만 쓴다(R15 손은 쥐는 점이 달라 기본값).
]]
local function gripOverride(classId: string?, slot: string): CFrame?
	local studio = if classId then ReplicatedStorage:FindFirstChild("MotionStudio") else nil
	local folder = studio and studio:FindFirstChild(classId :: string)
	local v = folder and folder:GetAttribute("Grip" .. slot)
	return if typeof(v) == "CFrame" then v else nil
end

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function at(v: { number }): CFrame
	return CFrame.new(v[1], v[2], v[3]) * CFrame.fromOrientation((v[4] or 0) * RAD, (v[5] or 0) * RAD, (v[6] or 0) * RAD)
end

local SHAPES = {
	Block = Enum.PartType.Block,
	Ball = Enum.PartType.Ball,
	Cylinder = Enum.PartType.Cylinder,
}

-- 블렌더 메시 묶음(없으면 nil)
local function meshSource(weaponId: string, pieceName: string): Instance?
	local root = ReplicatedStorage:FindFirstChild("WeaponMeshes")
	local weapon = root and root:FindFirstChild(weaponId)
	local source = weapon and weapon:FindFirstChild(pieceName)
	return if source and source:FindFirstChildWhichIsA("MeshPart") then source else nil
end

local function weldTo(grip: BasePart, p: BasePart, offset: CFrame)
	p.CFrame = offset
	local weld = Instance.new("Weld")
	weld.Part0 = grip
	weld.Part1 = p
	weld.C0 = offset
	weld.Parent = p
end

-- 조각 하나를 짓는다. 돌려주는 모델의 PrimaryPart = Grip(쥐는 점). meshes = 블렌더 메시 묶음(있으면 Parts 대신)
local function buildPiece(piece: WeaponDefinitions.Piece, name: string, anchored: boolean, meshes: Instance?): Model
	local model = Instance.new("Model")
	model.Name = name
	local grip = Instance.new("Part")
	grip.Name = "Grip"
	grip.Size = Vector3.new(0.2, 0.2, 0.2)
	grip.Transparency = 1
	grip.CanCollide, grip.CanQuery, grip.CanTouch = false, false, false
	grip.Massless = true
	grip.Anchored = anchored
	grip.Parent = model
	model.PrimaryPart = grip
	for _, src in (if meshes then meshes:GetChildren() else {}) do
		if not src:IsA("MeshPart") then
			continue
		end
		local p = src:Clone()
		local skin = piece.Skins and piece.Skins[src.Name]
		if skin then
			p.Color = rgb(skin.Color)
			p.Material = (Enum.Material :: any)[skin.Material] or Enum.Material.SmoothPlastic
			p.Transparency = skin.Transparency or 0
		end
		p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
		p.CastShadow = p.Material ~= Enum.Material.Neon
		p.Massless = true
		p.Anchored = false
		weldTo(grip, p, (src:GetAttribute("Offset") :: CFrame?) or CFrame.identity)
		p.Parent = model
	end
	-- Turn: 조각 전체를 무기 축(+Y) 둘레로 돌린다(Part 정의만 — 블렌더 메시는 이미 돌려 지었다)
	local turn = CFrame.fromOrientation(0, (piece.Turn or 0) * RAD, 0)
	for _, spec in (if meshes then {} else piece.Parts) do
		local p: BasePart
		if spec.Shape == "Wedge" then
			p = Instance.new("WedgePart")
		else
			local part = Instance.new("Part")
			part.Shape = SHAPES[spec.Shape] or Enum.PartType.Block
			p = part
		end
		p.Name = spec.Name
		p.Size = Vector3.new(spec.Size[1], spec.Size[2], spec.Size[3])
		p.Color = rgb(spec.Color)
		p.Material = (Enum.Material :: any)[spec.Material] or Enum.Material.SmoothPlastic
		p.Transparency = spec.Transparency or 0
		p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
		p.CastShadow = spec.Material ~= "Neon"
		p.Massless = true
		p.Anchored = false
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		weldTo(grip, p, turn * at(spec.At))
		p.Parent = model
	end
	-- 궤적·이펙트 점
	for socket, v in piece.Sockets do
		local a = Instance.new("Attachment")
		a.Name = socket
		a.Position = Vector3.new(v[1], v[2], v[3])
		a.Parent = grip
	end
	if piece.Trail and grip:FindFirstChild("Base") and grip:FindFirstChild("Tip") then
		local trail = Instance.new("Trail")
		trail.Name = "Trail"
		trail.Attachment0 = grip:FindFirstChild("Base") :: Attachment
		trail.Attachment1 = grip:FindFirstChild("Tip") :: Attachment
		trail.Color = ColorSequence.new(rgb(piece.Trail), Color3.new(1, 1, 1))
		trail.LightEmission = 1
		trail.LightInfluence = 0
		trail.Lifetime = 0.16
		trail.MinLength = 0.05
		trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
		trail.WidthScale = NumberSequence.new(1, 0.3)
		trail.Enabled = false
		trail.Parent = grip
	end
	return model
end

export type OrbMode = "Orbit" | "Gather" | "Shield" | "Spread" | "Crown" | "Sky" | "Whirl"

--[[
	별 빛무리(조율자 별자리 — 2026-10-30 사용자 참고 그림: 검은 하늘에 파란 빛무리를 두른 작은 흰 별, 옅은 고리).
	카메라를 늘 보는 BillboardGui(크기 = 스터드) 안에 가운데 맞춘 동그라미를 겹친다: 넓고 옅은 파랑 → 좁고 진한 파랑 → 흰 속점, 옅은 고리 하나.
	Layers = { 동그라미, 켜졌을 때 투명도 } — 켜짐 정도에 따라 Update 가 투명도를 맞춘다.
]]
export type Glow = { Gui: BillboardGui, Size: UDim2, Layers: { { Frame: Frame, Alpha: number } }, Ring: UIStroke, Dot: Frame, Light: PointLight }
local GLOW_SIZE = 1.5 -- 가장 밝은 별 빛무리 지름(스터드)
local function makeGlow(core: BasePart, scale: number): Glow
	local gui = Instance.new("BillboardGui")
	gui.Name = "StarGlow"
	gui.Size = UDim2.fromScale(GLOW_SIZE * scale, GLOW_SIZE * scale)
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.AlwaysOnTop = false
	gui.Parent = core
	local z = 0
	local function disc(size: number, color: Color3, alpha: number): Frame
		z += 1
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.5)
		f.Size = UDim2.fromScale(size, size)
		f.BackgroundColor3 = color
		f.BackgroundTransparency = alpha
		f.BorderSizePixel = 0
		f.ZIndex = z
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = f
		f.Parent = gui
		return f
	end
	local layers = {}
	for _, l in { { 1, Color3.fromRGB(40, 120, 255), 0.9 }, { 0.62, Color3.fromRGB(70, 150, 255), 0.78 }, { 0.36, Color3.fromRGB(130, 195, 255), 0.5 } } do
		table.insert(layers, { Frame = disc(l[1], l[2], l[3]), Alpha = l[3] })
	end
	local ringFrame = disc(0.74, Color3.new(0, 0, 0), 1)
	local ring = Instance.new("UIStroke")
	ring.Color = Color3.fromRGB(150, 205, 255)
	ring.Thickness = 1.2
	ring.Transparency = 0.65
	ring.Parent = ringFrame
	local dot = disc(0.15, Color3.fromRGB(240, 248, 255), 0)
	local light = Instance.new("PointLight")
	light.Range, light.Brightness, light.Shadows, light.Color = 7, 0, false, Color3.fromRGB(90, 160, 255)
	light.Parent = core
	return { Gui = gui, Size = gui.Size, Layers = layers, Ring = ring, Dot = dot, Light = light }
end

--[[
	character 에 weaponId(없으면 직업 기본 무기)를 붙인다. rig 에 모터를 등록한다.
]]
function CombatWeapons.Attach(character: Model, rig: any, weaponId: string?, classId: string?)
	local def = (weaponId and WeaponDefinitions.Get(weaponId)) or WeaponDefinitions.ForClass(classId or "")
	local self = setmetatable({}, CombatWeapons)
	self.Def = def
	self.Type = def.Type
	self.Character = character
	self.Pieces = {} :: { [string]: Model }
	self.Motors = {} :: { [string]: Motor6D }
	self.Orbs = {} :: { Model }
	self.OrbMode = "Orbit" :: OrbMode
	self.OrbT = 0
	self.OrbPos = {} :: { Vector3 }
	self.OrbAim = nil :: Vector3?
	-- 별자리(조율자): 별마다 부품·켜짐(Lit — nil 이면 켜짐)·켜짐 정도(0~1)·막 켜진 빛 부풂, 별자리 선, 도는 각
	self.Stars = {} :: { Glow } 
	self.Lit = {} :: { boolean }
	self.LitK = {} :: { number }
	self.Pop = {} :: { number? }
	self.Lines = {} :: { { A: number, B: number, Part: BasePart, Alpha: number } }
	self.SpinT = 0
	self.Center = nil :: Vector3?
	self.WhirlT = 0
	self.WhirlFrom = {} :: { number }

	local folder = Instance.new("Folder")
	folder.Name = "CombatWeapon"
	folder.Parent = character
	self.Folder = folder

	for slot, piece in { W = def.Main, O = def.Off } :: { [string]: WeaponDefinitions.Piece? } do
		if not piece then
			continue
		end
		if piece.Hand == "Float" then
			local orbit = def.Orbit or { Count = 3, Radius = 2.6, Height = 1.6, Speed = 1 }
			-- 별자리(Points)는 블렌더 메시 대신 표의 구(Core·Halo)로 짓는다(2026-10-30 사용자: "구 형태의 진짜 별")
			local meshes = if orbit.Points then nil else meshSource(def.Id, "Main")
			for i = 1, orbit.Count do
				local orb = buildPiece(piece, "Orb" .. i, true, meshes)
				-- 떠 있는 조각은 용접 대신 통째로 옮긴다
				for _, d in orb:GetDescendants() do
					if d:IsA("BasePart") then
						d.Anchored = true
					end
				end
				if orbit.Points then
					self.Stars[i] = makeGlow(orb:FindFirstChild("Core") or orb.PrimaryPart, (orbit.Sizes and orbit.Sizes[i]) or 1)
				end
				orb.Parent = folder
				table.insert(self.Orbs, orb)
			end
			if orbit.Points then
				local sum = Vector3.zero
				for _, p in orbit.Points do
					sum += Vector3.new(p[1], p[2], p[3])
				end
				self.Center = sum / #orbit.Points
			end
			-- 별자리 선: 두 별이 다 켜지면 잇는다(Update 가 자리·투명도를 맞춘다)
			for _, pair in orbit.Lines or {} do
				local line = Instance.new("Part")
				line.Name = "StarLine"
				line.Anchored, line.CanCollide, line.CanQuery, line.CanTouch, line.CastShadow = true, false, false, false, false
				line.Material = Enum.Material.Neon
				line.Color = Color3.fromRGB(150, 205, 255)
				line.Size = Vector3.new(0.04, 0.04, 0.04)
				line.Transparency = 1
				line.Parent = folder
				table.insert(self.Lines, { A = pair[1], B = pair[2], Part = line, Alpha = 1 })
			end
			continue
		end
		local armName = if piece.Hand == "Left" then "Left Arm" elseif piece.Hand == "Back" then "Torso" else "Right Arm"
		local arm = character:FindFirstChild(armName)
			or character:FindFirstChild(if piece.Hand == "Left" then "LeftHand" elseif piece.Hand == "Back" then "UpperTorso" else "RightHand")
		if not arm or not arm:IsA("BasePart") then
			continue
		end
		local model = buildPiece(piece, slot, false, meshSource(def.Id, if slot == "O" then "Off" else "Main"))
		local motor = Instance.new("Motor6D")
		motor.Name = "CombatGrip" .. slot
		motor.Part0 = arm
		motor.Part1 = model.PrimaryPart
		-- R15 는 손 부품 끝에서 쥔다. 등에 멘 것(Hand = Back, 청의 검사 검집)은 몸통 가운데에서 몸통 공간 그대로(모션 O 값)
		motor.C0 = if piece.Hand == "Back" then CFrame.identity
			elseif arm.Name:find("Hand") then CFrame.new(0, -arm.Size.Y / 2, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
			else (gripOverride(classId, slot) or GRIP_C0)
		motor.Parent = model.PrimaryPart
		model.Parent = folder
		self.Pieces[slot] = model
		self.Motors[slot] = motor
		rig:SetWeaponMotor(slot, motor)
	end
	return self
end

-- 조각의 한 점(Base/Tip)의 월드 자리. 없으면 손 자리.
function CombatWeapons:Socket(slot: string, socket: string): Vector3?
	local model = self.Pieces[slot]
	if model and model.PrimaryPart then
		local a = model.PrimaryPart:FindFirstChild(socket)
		if a and a:IsA("Attachment") then
			return a.WorldPosition
		end
		return model.PrimaryPart.Position
	end
	local orb = self.Orbs[1]
	if orb and orb.PrimaryPart then
		return orb.PrimaryPart.Position
	end
	return nil
end

function CombatWeapons:Trail(slot: string?, on: boolean)
	for s, model in self.Pieces do
		if slot == nil or slot == s or slot == "All" then
			local trail = model.PrimaryPart and model.PrimaryPart:FindFirstChild("Trail")
			if trail and trail:IsA("Trail") then
				trail.Enabled = on
			end
		end
	end
	for _, orb in self.Orbs do
		local trail = orb.PrimaryPart and orb.PrimaryPart:FindFirstChild("Trail")
		if trail and trail:IsA("Trail") then
			trail.Enabled = on
		end
	end
end

-- 손에 든 조각을 숨긴다(던진 병 등). 다시 보이면 새로 채운 것처럼 살짝 커지며 나타난다.
function CombatWeapons:Hide(slot: string, hidden: boolean)
	local model = self.Pieces[slot]
	if not model then
		return
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Grip" then
			if hidden then
				d:SetAttribute("CombatAlpha", d:GetAttribute("CombatAlpha") or d.Transparency)
				d.Transparency = 1
			else
				d.Transparency = (d:GetAttribute("CombatAlpha") :: number?) or 0
			end
		end
	end
end

-- 조각 복제본(던질 병·날릴 못 등)
function CombatWeapons:ClonePiece(slot: string): Model?
	local piece = if slot == "O" then self.Def.Off else self.Def.Main
	if not piece then
		return nil
	end
	local model = buildPiece(piece, "Thrown", true, meshSource(self.Def.Id, if slot == "O" then "Off" else "Main"))
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	return model
end

--[[
	오브 대형:
	  Orbit  몸 둘레를 돈다(기본)             Gather 앞으로 뻗은 손 앞에 모인다(빔 모으기)
	  Shield 앞에 세모 방패                   Spread 넓게 퍼져 빠르게 돈다(자기권)
	  Crown  머리 위 작은 원(명상·들림)
  Sky    (별자리 무기) 겨눈 자리(적 진영) 위에 별자리를 크게 펼친다(셉텐트리오네스)
  Whirl  몸 둘레를 한 바퀴 빠르게 돌고(WHIRL 초) 저절로 Orbit 으로 돌아간다(조율자 버릇 — 오른팔을 쭉 펼칠 때)
  별자리 무기(Orbit.Points — 조율자 일곱 별)는 Orbit 일 때 둘레를 돌지 않고 그 자리에 떠서 숨 쉬듯 흔들린다.
]]
function CombatWeapons:SetOrbMode(mode: OrbMode, aim: Vector3?)
	self.OrbMode = mode
	self.OrbAim = aim
	if mode == "Whirl" then
		-- 별마다 지금 자리의 몸 둘레 각에서 출발한다(제자리에서 곧장 돌기 시작하게)
		self.WhirlT = 0
		local root = self.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		for i in self.Orbs do
			local p = self.OrbPos[i]
			local rel = if root and p then root.CFrame:PointToObjectSpace(p) else Vector3.new(1, 0, 0)
			self.WhirlFrom[i] = math.atan2(rel.Z, rel.X)
		end
	end
end

local WHIRL = 0.8 -- 몸을 한 바퀴 도는 시간(초)

-- 별 하나의 지금 자리(이펙트가 그 별에서 빛을 쏜다). 없으면 nil
function CombatWeapons:OrbPosition(i: number): Vector3?
	return self.OrbPos[i]
end

--[[
	켜진 별(조율자 [칠성]을 준 별 — Orbit.Points 순서와 같은 BattleSkillEffects.STAR_SOURCES 이름 표)만 밝게.
	lit 가 nil 이면 전부 켠다(전시장·관전). 꺼진 별은 흐린 속만(없애지 않는다 — 별자리 꼴은 늘 보인다).
	막 켜진 별은 겉 빛이 한 번 부풀었다 가라앉고, 이웃 별도 켜져 있으면 별자리 선이 이어진다(Update).
]]
local STAR_NAMES = { "Megrez", "Merak", "Alioth", "Alkaid", "Mizar", "Phecda", "Dubhe" }
function CombatWeapons:SetLit(lit: { [string]: boolean }?)
	for i in self.Orbs do
		local on = lit == nil or lit[STAR_NAMES[i] or ""] == true
		if on and self.Lit[i] == false then
			self.Pop[i] = 0
		end
		self.Lit[i] = on
	end
end

-- 별 하나의 밝기: 켜짐 정도 k 를 부드럽게 쫓고(켜진 별 = 밝은 속 · 겉 빛 · 빛, 꺼진 별 = 흐린 속), 막 켜졌으면 0.7초 동안 빛이 부푼다
local POP = 0.7
local function shine(self: any, i: number, dt: number)
	local star = self.Stars[i]
	if not star then
		return
	end
	local on = self.Lit[i] ~= false
	local k = self.LitK[i] or (if on then 1 else 0)
	k += ((if on then 1 else 0) - k) * (1 - math.exp(-dt * 6))
	self.LitK[i] = k
	local swell = 0
	local pop = self.Pop[i]
	if pop then
		pop += dt
		self.Pop[i] = if pop < POP then pop else nil
		swell = math.max(0, 1 - pop / POP)
	end
	-- 켜진 별: 빛무리 · 고리 · 흰 속점 · 빛. 꺼진 별: 흐리고 작은 속점만(별자리 꼴은 보인다)
	for _, layer in star.Layers do
		layer.Frame.BackgroundTransparency = 1 - math.min(1, (1 - layer.Alpha) * k * (1 + 1.5 * swell))
	end
	star.Ring.Transparency = 1 - 0.35 * k
	star.Dot.BackgroundTransparency = 0.55 * (1 - k)
	star.Dot.Size = UDim2.fromScale(0.1 + 0.05 * k, 0.1 + 0.05 * k)
	local grow = 1 + 0.8 * swell
	star.Gui.Size = UDim2.fromScale(star.Size.X.Scale * grow, star.Size.Y.Scale * grow)
	star.Light.Brightness = 1.4 * k + 3 * swell
end

function CombatWeapons:Update(dt: number)
	if #self.Orbs == 0 then
		return
	end
	local root = self.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local orbit = self.Def.Orbit or { Count = 3, Radius = 2.6, Height = 1.6, Speed = 1 }
	local mode = self.OrbMode
	local speed = orbit.Speed * (if mode == "Spread" then 3.2 elseif mode == "Gather" then 2.4 else 1)
	self.OrbT += dt * speed
	self.SpinT += dt * (orbit.Spin or 0)
	if mode == "Whirl" then
		self.WhirlT += dt
		if self.WhirlT >= WHIRL then
			self.OrbMode = "Orbit"
			mode = "Orbit"
		end
	end
	local cf = root.CFrame
	local n = #self.Orbs
	for i, orb in self.Orbs do
		local phase = self.OrbT * math.pi * 2 / 3 + (i - 1) / n * math.pi * 2
		local target: Vector3
		local point = orbit.Points and orbit.Points[i]
		if point and mode == "Orbit" then
			-- 별자리: 캐릭터 옆에서 가운데를 축으로 제 판(YZ) 안에서 천천히 돌고(Spin), 별마다 다른 박자로 조금씩 숨 쉬듯 흔들린다
			local c = self.Center :: Vector3
			local a = self.SpinT
			local dy, dz = point[2] - c.Y, point[3] - c.Z
			local bob = math.sin(self.OrbT * 2.2 + i * 1.7) * 0.06
			target = (cf * CFrame.new(point[1], c.Y + dy * math.cos(a) - dz * math.sin(a) + bob, c.Z + dy * math.sin(a) + dz * math.cos(a))).Position
		elseif point and mode == "Sky" then
			-- 겨눈 자리(적 진영 가운데) 위에 별자리를 크게(2.5배) 펼친다 — 오른쪽 옆 카메라에 보이게 YZ 판 그대로
			-- (쉴 때 별자리가 폭 약 5.7 이라 하늘 별자리는 약 14)
			local center = self.OrbAim or (cf * CFrame.new(0, 3, -12)).Position
			local mid = self.Center :: Vector3
			local d = (Vector3.new(point[1], point[2], point[3]) - mid) * 2.5
			target = center + Vector3.new(0, 6, 0) + cf.RightVector * d.X + cf.UpVector * d.Y + cf.LookVector * -d.Z
		elseif mode == "Whirl" then
			-- 몸 둘레(반지름 2.8)를 별마다 다른 높이로 한 바퀴 — 천천히 일어나 빨라졌다 다시 늦춰진다
			local u = math.min(1, self.WhirlT / WHIRL)
			local a = (self.WhirlFrom[i] or 0) - 2 * math.pi * (-(math.cos(math.pi * u) - 1) / 2)
			target = (cf * CFrame.new(math.cos(a) * 2.8, 0.2 + (i - 1) * 0.45, math.sin(a) * 2.8)).Position
		elseif mode == "Gather" then
			local hand = self.Character:FindFirstChild("Right Arm") :: BasePart?
			local center = if hand then (hand.CFrame * CFrame.new(0, -1.6, 0)).Position else (cf * CFrame.new(0, 0.5, -2.5)).Position
			if self.OrbAim then
				center = self.OrbAim
			end
			target = center + (cf.RightVector * math.cos(phase) + cf.UpVector * math.sin(phase)) * 0.7
		elseif mode == "Shield" then
			local a = (i - 1) / n * math.pi * 2 + math.pi / 2
			target = (cf * CFrame.new(math.cos(a) * 1.3, 0.6 + math.sin(a) * 1.3, -2.4)).Position
		elseif mode == "Crown" then
			target = (cf * CFrame.new(math.cos(phase) * 1.1, 3.4, math.sin(phase) * 1.1)).Position
		else
			local r = if mode == "Spread" then orbit.Radius * 1.7 else orbit.Radius
			local bob = math.sin(self.OrbT * 2 + i) * 0.25
			target = (cf * CFrame.new(math.cos(phase) * r, orbit.Height - 1 + bob, math.sin(phase) * r)).Position
		end
		local current = self.OrbPos[i] or target
		local k = 1 - math.exp(-dt * (if mode == "Gather" or mode == "Whirl" then 18 else 10))
		current = current:Lerp(target, k)
		self.OrbPos[i] = current
		if point then
			orb:PivotTo(CFrame.new(current))
			shine(self, i, dt)
		else
			orb:PivotTo(CFrame.new(current) * CFrame.Angles(0, self.OrbT * 3 + i, self.OrbT * 2))
		end
	end
	-- 별자리 선: 두 별이 다 켜져 있고 별자리 꼴(Orbit·Sky)일 때만 잇는다(천천히 나타나고 사라진다)
	for _, line in self.Lines do
		local on = self.Lit[line.A] ~= false and self.Lit[line.B] ~= false and (mode == "Orbit" or mode == "Sky")
		line.Alpha += ((if on then 0.35 else 1) - line.Alpha) * (1 - math.exp(-dt * 5))
		local part = line.Part
		part.Transparency = line.Alpha
		local pa, pb = self.OrbPos[line.A], self.OrbPos[line.B]
		if pa and pb and line.Alpha < 0.995 then
			part.Size = Vector3.new(0.04, 0.04, math.max(0.05, (pb - pa).Magnitude))
			part.CFrame = CFrame.lookAt(pa:Lerp(pb, 0.5), pb)
		end
	end
end

function CombatWeapons:Destroy()
	self.Folder:Destroy()
end

return CombatWeapons
