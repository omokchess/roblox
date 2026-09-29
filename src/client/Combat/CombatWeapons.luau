--!strict
--[[
	CombatWeapons — WeaponDefinitions 표로 무기를 **지어서 손에 붙인다**. (2026-09-28)

	무기 하나 = 손(오른손 W / 왼손 O)마다 조각(Piece) 하나. 조각은 보이지 않는 "Grip" 부품을
	중심으로 부품을 용접해 만들고, 팔과 Grip 을 Motor6D 로 잇는다. 모션의 W·O 값이 이
	모터의 Transform 이 된다(CombatRig:SetWeaponMotor).
	  모터 C0 = 팔 끝 (0,-1,0) · X -90°  (팔을 내리면 무기가 앞을 본다)
	떠 있는 무기(Hand = "Float", 펄서 오브)는 손에 안 붙이고 매 프레임 자리를 옮긴다(`Update`).

	새 무기를 표에 더하면 여기는 손대지 않아도 된다 — 모양·쥐는 점·궤적 점이 모두 표에 있다.
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

-- 조각 하나를 짓는다. 돌려주는 모델의 PrimaryPart = Grip(쥐는 점)
local function buildPiece(piece: WeaponDefinitions.Piece, name: string, anchored: boolean): Model
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
	for _, spec in piece.Parts do
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
		p.CFrame = at(spec.At)
		local weld = Instance.new("Weld")
		weld.Part0 = grip
		weld.Part1 = p
		weld.C0 = at(spec.At)
		weld.Parent = p
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

export type OrbMode = "Orbit" | "Gather" | "Shield" | "Spread" | "Crown"

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
			for i = 1, orbit.Count do
				local orb = buildPiece(piece, "Orb" .. i, true)
				-- 떠 있는 조각은 용접 대신 통째로 옮긴다
				for _, d in orb:GetDescendants() do
					if d:IsA("BasePart") then
						d.Anchored = true
					end
				end
				orb.Parent = folder
				table.insert(self.Orbs, orb)
			end
			continue
		end
		local armName = if piece.Hand == "Left" then "Left Arm" else "Right Arm"
		local arm = character:FindFirstChild(armName) or character:FindFirstChild(if piece.Hand == "Left" then "LeftHand" else "RightHand")
		if not arm or not arm:IsA("BasePart") then
			continue
		end
		local model = buildPiece(piece, slot, false)
		local motor = Instance.new("Motor6D")
		motor.Name = "CombatGrip" .. slot
		motor.Part0 = arm
		motor.Part1 = model.PrimaryPart
		-- R15 는 손 부품 끝에서 쥔다
		motor.C0 = if arm.Name:find("Hand")
			then CFrame.new(0, -arm.Size.Y / 2, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
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
	local model = buildPiece(piece, "Thrown", true)
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
]]
function CombatWeapons:SetOrbMode(mode: OrbMode, aim: Vector3?)
	self.OrbMode = mode
	self.OrbAim = aim
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
	local cf = root.CFrame
	local n = #self.Orbs
	for i, orb in self.Orbs do
		local phase = self.OrbT * math.pi * 2 / 3 + (i - 1) / n * math.pi * 2
		local target: Vector3
		if mode == "Gather" then
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
		local k = 1 - math.exp(-dt * (if mode == "Gather" then 18 else 10))
		current = current:Lerp(target, k)
		self.OrbPos[i] = current
		orb:PivotTo(CFrame.new(current) * CFrame.Angles(0, self.OrbT * 3 + i, self.OrbT * 2))
	end
end

function CombatWeapons:Destroy()
	self.Folder:Destroy()
end

return CombatWeapons
