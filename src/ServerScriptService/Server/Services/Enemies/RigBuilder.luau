--!strict
-- 크리처 에셋(부위별 그룹 + 관절 마커) → Humanoid 리그로 조립.
--   Visual/<부위명> 그룹마다 투명 "뼈" 파트를 만들고 시각 파트를 용접,
--   J_<관절> 마커(part0/part1 속성)로 Motor6D 를 연결한다. 관절 이름은 R15 와 동일.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AssetLibrary = require(Shared.World.AssetLibrary)

local RigBuilder = {}

export type Rig = {
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Bones: { [string]: BasePart },
}

local function makeBone(name: string, cf: CFrame, size: Vector3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(math.max(size.X, 0.4), math.max(size.Y, 0.4), math.max(size.Z, 0.4))
	p.CFrame = cf
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = true
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

function RigBuilder.Build(assetName: string, displayName: string): Rig?
	local template = AssetLibrary.Get(assetName)
	if not template then
		warn("[Rig] 에셋 없음:", assetName)
		return nil
	end
	local src = template:Clone()
	local model = Instance.new("Model")
	model.Name = displayName
	local rootPos = (src:GetAttribute("RootPos") :: Vector3?) or Vector3.new(0, 3, 0)
	local hrpSize = (src:GetAttribute("HrpSize") :: Vector3?) or Vector3.new(2, 2, 1)
	local hipHeight = (src:GetAttribute("HipHeight") :: number?) or (rootPos.Y - hrpSize.Y / 2)

	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = hrpSize
	hrp.CFrame = CFrame.new(rootPos)
	hrp.Transparency = 1
	hrp.CanCollide = true
	hrp.CanQuery = true
	hrp.CanTouch = true
	hrp.Anchored = false
	hrp.CastShadow = false
	hrp.Parent = model
	model.PrimaryPart = hrp

	local bones: { [string]: BasePart } = {}
	local visual = src:FindFirstChild("Visual")
	if visual then
		for _, group in visual:GetChildren() do
			if group:IsA("Model") then
				local cf, size = group:GetBoundingBox()
				local bone = makeBone(group.Name, CFrame.new(cf.Position), size, model)
				bones[group.Name] = bone
				for _, d in group:GetDescendants() do
					if d:IsA("BasePart") then
						d.Anchored = false
						d.Massless = true
						d.CanCollide = false
						d.CanQuery = false
						d.CanTouch = false
						local w = Instance.new("WeldConstraint")
						w.Part0 = bone
						w.Part1 = d
						w.Parent = d
					end
				end
				local folder = Instance.new("Model")
				folder.Name = group.Name .. "_Visual"
				for _, ch in group:GetChildren() do
					ch.Parent = folder
				end
				folder.Parent = model
			end
		end
		-- 그룹에 속하지 않은 파트는 LowerTorso 에 붙임
		local fallback = bones.LowerTorso or hrp
		for _, d in visual:GetChildren() do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.Massless = true
				d.CanCollide = false
				d.CanQuery = false
				local w = Instance.new("WeldConstraint")
				w.Part0 = fallback
				w.Part1 = d
				w.Parent = d
				d.Parent = model
			end
		end
	end

	-- 관절 & 마커
	local anchor = src:FindFirstChild("Anchor")
	if anchor then
		for _, a in anchor:GetChildren() do
			if not a:IsA("Attachment") then
				continue
			end
			local jointName = string.match(a.Name, "^J_(.+)$")
			if jointName then
				local p0name = a:GetAttribute("part0") :: string?
				local p1name = a:GetAttribute("part1") :: string?
				local p0 = if p0name == "HumanoidRootPart" then hrp else (p0name and bones[p0name])
				local p1 = p1name and bones[p1name]
				if p0 and p1 then
					local jcf = a.WorldCFrame
					local m = Instance.new("Motor6D")
					m.Name = jointName
					m.Part0 = p0
					m.Part1 = p1
					m.C0 = p0.CFrame:ToObjectSpace(jcf)
					m.C1 = p1.CFrame:ToObjectSpace(jcf)
					m.Parent = p1
				end
			else
				-- 일반 마커: 무기 손잡이는 오른팔, 나머지는 루트
				local wcf = a.WorldCFrame
				local target: BasePart = hrp
				if a.Name == "WeaponGrip" then
					target = bones.RightLowerArm or hrp
				elseif a.Name == "CastPoint" or a.Name == "Mouth" then
					target = bones.Head or bones.UpperTorso or hrp
				elseif string.sub(a.Name, 1, 6) == "Light_" then
					target = bones.UpperTorso or hrp
				end
				a.Parent = target
				a.WorldCFrame = wcf
			end
		end
	end
	src:Destroy()

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.HipHeight = hipHeight
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.BreakJointsOnDeath = false
	hum.RequiresNeck = false
	hum.AutomaticScalingEnabled = false
	hum.UseJumpPower = true
	hum.JumpPower = 40
	hum.Parent = model
	local animator = Instance.new("Animator")
	animator.Parent = hum
	model:SetAttribute("AssetName", assetName)
	return { Model = model, Humanoid = hum, Root = hrp :: BasePart, Bones = bones }
end

return RigBuilder
