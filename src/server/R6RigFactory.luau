--!strict

local R6RigFactory = {}

function R6RigFactory.ApplyClassicHead(rig: Model)
	local head = rig:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	if not head:IsA("Part") then
		return
	end
	head.Size = Vector3.new(2, 1, 1)
	for _, child in head:GetChildren() do
		if child:IsA("SpecialMesh") then
			child:Destroy()
		end
	end
	local mesh = Instance.new("SpecialMesh")
	mesh.Name = "ClassicHeadMesh"
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head
end

local function shade(color: Color3, multiplier: number): Color3
	return Color3.new(
		math.clamp(color.R * multiplier, 0, 1),
		math.clamp(color.G * multiplier, 0, 1),
		math.clamp(color.B * multiplier, 0, 1)
	)
end

local function part(name: string, size: Vector3, color: Color3): Part
	local value = Instance.new("Part")
	value.Name = name
	value.Size = size
	value.Color = color
	value.Anchored = false
	value.CanCollide = false
	value.TopSurface = Enum.SurfaceType.Smooth
	value.BottomSurface = Enum.SurfaceType.Smooth
	return value
end

local function motor(parent: BasePart, name: string, p0: BasePart, p1: BasePart, c0: CFrame, c1: CFrame): Motor6D
	local value = Instance.new("Motor6D")
	value.Name = name
	value.Part0 = p0
	value.Part1 = p1
	value.C0 = c0
	value.C1 = c1
	value.Parent = parent
	return value
end

function R6RigFactory.Create(name: string, color: Color3, at: CFrame): Model
	local rig = Instance.new("Model")
	rig.Name = name
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), color)
	root.Transparency = 1
	root.Anchored = true
	local torso = part("Torso", Vector3.new(2, 2, 1), color)
	local head = part("Head", Vector3.new(2, 1, 1), Color3.fromRGB(240, 205, 170))
	local rightArm = part("Right Arm", Vector3.new(1, 2, 1), color)
	local leftArm = part("Left Arm", Vector3.new(1, 2, 1), color)
	local rightLeg = part("Right Leg", Vector3.new(1, 2, 1), shade(color, 0.75))
	local leftLeg = part("Left Leg", Vector3.new(1, 2, 1), shade(color, 0.75))
	for _, item in { root, torso, head, rightArm, leftArm, rightLeg, leftLeg } do
		item.Parent = rig
	end
	R6RigFactory.ApplyClassicHead(rig)
	motor(root, "RootJoint", root, torso, CFrame.new(), CFrame.new())
	motor(torso, "Neck", torso, head, CFrame.new(0, 1, 0), CFrame.new(0, -0.5, 0))
	motor(torso, "Right Shoulder", torso, rightArm, CFrame.new(1, 0.5, 0), CFrame.new(-0.5, 0.5, 0))
	motor(torso, "Left Shoulder", torso, leftArm, CFrame.new(-1, 0.5, 0), CFrame.new(0.5, 0.5, 0))
	motor(torso, "Right Hip", torso, rightLeg, CFrame.new(0.5, -1, 0), CFrame.new(0, 1, 0))
	motor(torso, "Left Hip", torso, leftLeg, CFrame.new(-0.5, -1, 0), CFrame.new(0, 1, 0))
	local humanoid = Instance.new("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = rig
	local weapon = part("MotionWeapon", Vector3.new(0.35, 3, 0.45), Color3.fromRGB(205, 210, 220))
	weapon.Material = Enum.Material.Metal
	weapon.Parent = rig
	motor(
		rightArm,
		"MotionWeaponMotor",
		rightArm,
		weapon,
		CFrame.new(0, -1.25, 0) * CFrame.Angles(0, 0, math.rad(-10)),
		CFrame.new(0, 1.2, 0)
	)
	local dualWeapon = part("MotionDualWeapon", Vector3.new(0.35, 3, 0.12), Color3.fromRGB(205, 210, 220))
	dualWeapon.Material = Enum.Material.Metal
	dualWeapon.Transparency = 1
	dualWeapon.Parent = rig
	motor(
		leftArm,
		"MotionDualWeaponMotor",
		leftArm,
		dualWeapon,
		CFrame.new(0, -1.25, 0) * CFrame.Angles(0, 0, math.rad(10)),
		CFrame.new(0, 1.2, 0)
	)
	rig.PrimaryPart = root
	rig:PivotTo(at)
	return rig
end

return R6RigFactory
