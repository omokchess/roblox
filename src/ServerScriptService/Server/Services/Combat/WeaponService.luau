--!strict
-- 무기 장착: 에셋 모델을 손에 용접하고 휘두르기 궤적(Trail)을 준비한다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AssetLibrary = require(Shared.World.AssetLibrary)
local WeaponDefs = require(Shared.Combat.WeaponDefs)

local WeaponService = {}

local WEAPON_NAME = "SwampWeapon"

local function prepare(model: Model): BasePart?
	local anchor = model:FindFirstChild("Anchor") :: BasePart?
	if not anchor then
		return nil
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.Massless = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			if d ~= anchor then
				local w = Instance.new("WeldConstraint")
				w.Part0 = anchor
				w.Part1 = d
				w.Parent = d
			end
		end
	end
	local colliders = model:FindFirstChild("Colliders")
	if colliders then
		colliders:Destroy()
	end
	-- 궤적
	local a0 = anchor:FindFirstChild("TrailA") :: Attachment?
	local a1 = anchor:FindFirstChild("TrailB") :: Attachment?
	if a0 and a1 then
		local trail = Instance.new("Trail")
		trail.Name = "SwingTrail"
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Lifetime = 0.16
		trail.MinLength = 0.05
		trail.LightEmission = 0.7
		trail.LightInfluence = 0.2
		trail.FaceCamera = false
		trail.Color = ColorSequence.new(Color3.fromRGB(230, 255, 220), Color3.fromRGB(120, 220, 160))
		trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
		trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.3) })
		trail.Enabled = false
		trail.Parent = anchor
	end
	return anchor
end

local function hand(character: Model): (BasePart?, CFrame)
	local r15 = character:FindFirstChild("RightHand") :: BasePart?
	if r15 then
		return r15, WeaponDefs.GripR15
	end
	local r6 = character:FindFirstChild("Right Arm") :: BasePart?
	if r6 then
		return r6, WeaponDefs.GripR6
	end
	return nil, CFrame.identity
end

function WeaponService.Unequip(character: Model)
	local old = character:FindFirstChild(WEAPON_NAME)
	if old then
		old:Destroy()
	end
end

-- 플레이어 무기 장착. 성공 시 WeaponDef 반환
function WeaponService.EquipPlayer(character: Model, weaponId: string): WeaponDefs.WeaponDef?
	local def = WeaponDefs.Weapons[weaponId]
	if not def then
		return nil
	end
	local h, grip = hand(character)
	if not h then
		return nil
	end
	local model = AssetLibrary.Clone(def.Model)
	if not model then
		warn("[Weapon] 모델 없음:", def.Model)
		return nil
	end
	WeaponService.Unequip(character)
	model.Name = WEAPON_NAME
	local anchor = prepare(model)
	if not anchor then
		return nil
	end
	anchor.CFrame = h.CFrame * grip
	local weld = Instance.new("Weld")
	weld.Name = "GripWeld"
	weld.Part0 = h
	weld.Part1 = anchor
	weld.C0 = grip
	weld.Parent = anchor
	model:SetAttribute("WeaponId", weaponId)
	model.Parent = character
	character:SetAttribute("WeaponId", weaponId)
	character:SetAttribute("WeaponKind", def.Kind)
	return def
end

-- NPC 무기: 지정한 뼈(파트)의 CFrame 에 그립 오프셋으로 용접
function WeaponService.EquipNPC(character: Model, assetName: string, bone: BasePart, gripWorld: CFrame): Model?
	local model = AssetLibrary.Clone(assetName)
	if not model then
		return nil
	end
	model.Name = WEAPON_NAME
	local anchor = prepare(model)
	if not anchor then
		return nil
	end
	anchor.CFrame = gripWorld
	local weld = Instance.new("Weld")
	weld.Part0 = bone
	weld.Part1 = anchor
	weld.C0 = bone.CFrame:ToObjectSpace(gripWorld)
	weld.Parent = anchor
	model.Parent = character
	return model
end

return WeaponService
