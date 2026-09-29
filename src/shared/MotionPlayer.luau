--!strict

local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RotationUtil = require(ReplicatedStorage.Shared.RotationUtil)

local MotionPlayer = {}

local JOINT_ALIASES = {
	["Right Shoulder"] = true,
	["Left Shoulder"] = true,
	["Right Hip"] = true,
	["Left Hip"] = true,
	Neck = true,
	RootJoint = true,
}

local function findMotor(rig: Model, name: string): Motor6D?
	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("Motor6D") and descendant.Name == name then
			return descendant
		end
	end
	return nil
end

local function poseAt(frames: { any }, time: number, jointName: string, motor: Motor6D): CFrame
	local before = frames[1]
	local after = frames[#frames]
	for index = 1, #frames - 1 do
		if time >= frames[index].Time and time <= frames[index + 1].Time then
			before = frames[index]
			after = frames[index + 1]
			break
		end
	end
	local duration = math.max(0.001, after.Time - before.Time)
	local alpha = math.clamp((time - before.Time) / duration, 0, 1)
	local beforePose = (before.Joints and before.Joints[jointName]) or { X = 0, Y = 0, Z = 0 }
	local afterPose = (after.Joints and after.Joints[jointName]) or beforePose
	local beforeOffset = (before.JointOffsets and before.JointOffsets[jointName]) or { X = 0, Y = 0, Z = 0 }
	local afterOffset = (after.JointOffsets and after.JointOffsets[jointName]) or beforeOffset
	local offset = Vector3.new(beforeOffset.X or 0, beforeOffset.Y or 0, beforeOffset.Z or 0)
		:Lerp(Vector3.new(afterOffset.X or 0, afterOffset.Y or 0, afterOffset.Z or 0), alpha)
	local beforeRotation = before.JointRotations and before.JointRotations[jointName]
	local afterRotation = after.JointRotations and after.JointRotations[jointName]
	local rotation
	if beforeRotation or afterRotation then
		rotation = RotationUtil.ToCFrame(beforeRotation, beforePose)
			:Lerp(RotationUtil.ToCFrame(afterRotation, afterPose), alpha)
	else
		-- Legacy motions keep numeric Euler interpolation so authored spins over
		-- 180 degrees retain their original playback path.
		rotation = CFrame.Angles(
			math.rad((beforePose.X or 0) + ((afterPose.X or 0) - (beforePose.X or 0)) * alpha),
			math.rad((beforePose.Y or 0) + ((afterPose.Y or 0) - (beforePose.Y or 0)) * alpha),
			math.rad((beforePose.Z or 0) + ((afterPose.Z or 0) - (beforePose.Z or 0)) * alpha)
		)
	end
	local pivot = motor.C1:Inverse().Position
	return CFrame.new(offset) * CFrame.new(pivot) * rotation * CFrame.new(-pivot)
end

local function vector(value: any): Vector3
	return Vector3.new(value and value.X or 0, value and value.Y or 0, value and value.Z or 0)
end

local function layerDepth(frame: any, key: string): number
	local order = frame.LayerOrder or {}
	local playerIndex = table.find(order, "Player") or 1
	local itemIndex = table.find(order, key) or playerIndex
	return (itemIndex - playerIndex) * 0.08
end

local function weaponCFrame(frame: any, key: string?): CFrame
	local weaponKey = key or "Weapon"
	local weapon = frame[weaponKey] or {}
	local position = vector(weapon.Position)
	local rotation = vector(weapon.Rotation)
	return CFrame.new(position + Vector3.new(0, 0, layerDepth(frame, weaponKey)))
		* CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
		* CFrame.Angles(weapon.FlipY and math.pi or 0, weapon.FlipX and math.pi or 0, 0)
end

local function weaponAt(frames: { any }, time: number, key: string?): CFrame
	local before = frames[1]
	local after = frames[#frames]
	for index = 1, #frames - 1 do
		if time >= frames[index].Time and time <= frames[index + 1].Time then
			before = frames[index]
			after = frames[index + 1]
			break
		end
	end
	local duration = math.max(0.001, after.Time - before.Time)
	local alpha = math.clamp((time - before.Time) / duration, 0, 1)
	return weaponCFrame(before, key):Lerp(weaponCFrame(after, key), alpha)
end

local function frameAt(frames: { any }, time: number): any
	local selected = frames[1]
	for _, frame in frames do
		if frame.Time <= time then
			selected = frame
		else
			break
		end
	end
	return selected
end

local function rootOffsetAt(frames: { any }, time: number): Vector3
	local before = frames[1]
	local after = frames[#frames]
	for index = 1, #frames - 1 do
		if time >= frames[index].Time and time <= frames[index + 1].Time then
			before = frames[index]
			after = frames[index + 1]
			break
		end
	end
	local duration = math.max(0.001, after.Time - before.Time)
	local alpha = math.clamp((time - before.Time) / duration, 0, 1)
	return vector(before.RootOffset):Lerp(vector(after.RootOffset or before.RootOffset), alpha)
end

local function syncWeaponVisual(weapon: BasePart, frame: any, key: string?, enabled: boolean?)
	local definition = frame[key or "Weapon"] or {}
	local size = definition.Size or {}
	weapon.Size = Vector3.new(
		math.clamp(tonumber(size.X) or 0.35, 0.1, 12),
		math.clamp(tonumber(size.Y) or 3, 0.1, 12),
		math.clamp(tonumber(size.Z) or 0.12, 0.05, 4)
	)
	local assetId = tostring(definition.AssetId or "")
	local digits = string.match(assetId, "%d+")
	assetId = digits and ("rbxassetid://" .. digits) or ""
	weapon.Transparency = enabled == false and 1 or (assetId == "" and 0 or 0.88)
	for _, data in
		{
			{ Name = "WeaponImageFront", Face = Enum.NormalId.Front },
			{ Name = "WeaponImageBack", Face = Enum.NormalId.Back },
		}
	do
		local decal = weapon:FindFirstChild(data.Name)
		if not decal then
			decal = Instance.new("Decal")
			decal.Name = data.Name
			decal.Parent = weapon
		end
		if decal:IsA("Decal") then
			decal.Face = data.Face
			decal.Texture = assetId
			decal.Transparency = (enabled == false or assetId == "") and 1 or 0
		end
	end
end

local function syncWeaponHands(rig: Model, mainMotor: Motor6D?, dualMotor: Motor6D?, swapped: boolean)
	local rightArm = rig:FindFirstChild("Right Arm")
	local leftArm = rig:FindFirstChild("Left Arm")
	if not rightArm or not leftArm or not rightArm:IsA("BasePart") or not leftArm:IsA("BasePart") then
		return
	end
	if mainMotor then
		mainMotor.Part0 = swapped and leftArm or rightArm
		mainMotor.C0 = CFrame.new(0, -1.25, 0) * CFrame.Angles(0, 0, math.rad(swapped and 10 or -10))
	end
	if dualMotor then
		dualMotor.Part0 = swapped and rightArm or leftArm
		dualMotor.C0 = CFrame.new(0, -1.25, 0) * CFrame.Angles(0, 0, math.rad(swapped and -10 or 10))
	end
end

local function showHitbox(rig: Model, hit: any)
	local root = rig:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local definition = hit.Hitbox or {}
	local size = vector(definition.Size)
	if size.Magnitude < 0.1 then
		size = Vector3.new(3, 3, 3)
	end
	local part = Instance.new("Part")
	part.Name = "MotionHitboxPreview"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.ForceField
	part.Color = Color3.fromRGB(255, 75, 75)
	part.Transparency = 0.48
	part.Size = size
	local rotation = vector(definition.Rotation)
	part.CFrame = root.CFrame
		* CFrame.new(vector(definition.Offset))
		* CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
	part.Parent = rig.Parent
	Debris:AddItem(part, 0.16)
end

local function showFrameEvent(rig: Model, event: any, kind: string, target: Model?)
	local root = rig:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") or kind == "Teleports" then
		return
	end
	local size = vector(event.Size)
	local visual = Instance.new("Part")
	visual.Name = "Motion" .. kind .. "Preview"
	visual.Anchored = true
	visual.CanCollide = false
	visual.CanQuery = false
	visual.CanTouch = false
	visual.Material = Enum.Material.Neon
	local effectPreset = tostring(event.EffectPreset or "slash")
	if kind == "Effects" and (effectPreset == "spark" or effectPreset == "burst" or effectPreset == "smoke") then
		visual.Shape = Enum.PartType.Ball
	elseif kind == "Effects" and effectPreset == "ring" then
		visual.Shape = Enum.PartType.Cylinder
	else
		visual.Shape = Enum.PartType.Block
	end
	local colorValue = tostring(event.ColorHex or (kind == "Projectiles" and "#FFA050" or "#45F3FF"))
	local ok, color = pcall(Color3.fromHex, colorValue)
	visual.Color = ok and color
		or (kind == "Projectiles" and Color3.fromRGB(255, 160, 80) or Color3.fromRGB(69, 243, 255))
	local opacity = math.clamp(tonumber(event.Opacity) or 1, 0, 1)
	visual.Transparency = 1 - opacity * 0.65
	visual.Size = Vector3.new(math.max(0.1, math.abs(size.X)), math.max(0.1, math.abs(size.Y)), 0.12)
	local rotation = vector(event.Rotation)
	local startCFrame = root.CFrame
		* CFrame.new(vector(event.Offset))
		* CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
		* CFrame.Angles(event.FlipY and math.pi or 0, event.FlipX and math.pi or 0, 0)
	if kind == "Effects" and effectPreset == "ring" then
		startCFrame *= CFrame.Angles(0, math.pi * 0.5, 0)
	elseif kind == "Effects" and effectPreset == "spark" then
		visual.Size *= 0.45
	elseif kind == "Effects" and effectPreset == "burst" then
		visual.Size *= 0.8
	elseif kind == "Effects" and effectPreset == "smoke" then
		visual.Material = Enum.Material.SmoothPlastic
		visual.Transparency = math.max(visual.Transparency, 0.45)
	end
	visual.CFrame = startCFrame
	visual.Parent = rig.Parent
	local digits = string.match(tostring(event.AssetId or ""), "%d+")
	if digits then
		visual.Transparency = 1
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local decal = Instance.new("Decal")
			decal.Face = face
			decal.Texture = "rbxassetid://" .. digits
			decal.Color3 = visual.Color
			decal.Transparency = 1 - opacity
			decal.Parent = visual
		end
	end
	local duration = math.clamp(tonumber(event.Duration) or 0.35, 0.05, 10)
	if kind == "Projectiles" then
		local direction = root.CFrame.LookVector
		local targetRoot = target and target:FindFirstChild("HumanoidRootPart")
		if event.DirectionMode == "target" and targetRoot and targetRoot:IsA("BasePart") then
			direction = (targetRoot.Position - startCFrame.Position).Unit
		elseif event.DirectionMode == "fixed" then
			direction = CFrame.Angles(0, math.rad(tonumber(event.FixedAngle) or 0), 0):VectorToWorldSpace(direction)
		end
		local speed = math.clamp(tonumber(event.Speed) or 12, 1, 100)
		task.spawn(function()
			local started = os.clock()
			while visual.Parent and os.clock() - started < duration do
				local alpha = math.clamp((os.clock() - started) / duration, 0, 1)
				visual.CFrame = startCFrame + direction * (speed * duration * alpha)
				RunService.RenderStepped:Wait()
			end
		end)
	elseif kind == "Effects" then
		local initialSize = visual.Size
		local initialCFrame = visual.CFrame
		task.spawn(function()
			local started = os.clock()
			while visual.Parent and os.clock() - started < duration do
				local alpha = math.clamp((os.clock() - started) / duration, 0, 1)
				if effectPreset == "slash" then
					visual.Size =
						Vector3.new(math.max(0.1, initialSize.X * (0.35 + alpha * 0.65)), initialSize.Y, initialSize.Z)
				elseif effectPreset == "spark" then
					local pulse = 0.55 + math.sin(alpha * math.pi) * 0.85
					visual.Size = initialSize * pulse
				elseif effectPreset == "burst" or effectPreset == "ring" then
					visual.Size = initialSize * (0.25 + alpha * 1.25)
				elseif effectPreset == "smoke" then
					visual.Size = initialSize * (0.7 + alpha * 0.65)
					visual.CFrame = initialCFrame + Vector3.new(0, alpha * 1.4, 0)
				end
				local fade = math.clamp((alpha - 0.58) / 0.42, 0, 1)
				visual.Transparency = math.max(visual.Transparency, fade)
				for _, decal in visual:GetChildren() do
					if decal:IsA("Decal") then
						decal.Transparency = math.max(1 - opacity, fade)
					end
				end
				RunService.RenderStepped:Wait()
			end
		end)
	end
	Debris:AddItem(visual, duration)
end

local function createDecorationVisuals(rig: Model): { Part }
	local visuals = {}
	for index = 1, 5 do
		local visual = Instance.new("Part")
		visual.Name = "MotionDecorationPreview" .. index
		visual.Anchored = true
		visual.CanCollide = false
		visual.CanQuery = false
		visual.CanTouch = false
		visual.Size = Vector3.new(2, 2, 0.12)
		visual.Transparency = 1
		visual.Parent = rig.Parent
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local decal = Instance.new("Decal")
			decal.Face = face
			decal.Transparency = 1
			decal.Parent = visual
		end
		table.insert(visuals, visual)
	end
	return visuals
end

local function syncDecorations(rig: Model, visuals: { Part }, frame: any)
	for index, visual in visuals do
		local decoration = frame.Decorations and frame.Decorations[index]
		if not decoration then
			visual.Transparency = 1
			for _, decal in visual:GetChildren() do
				if decal:IsA("Decal") then
					decal.Transparency = 1
				end
			end
			continue
		end
		local parent = decoration.Attach == "Head" and rig:FindFirstChild("Head")
			or rig:FindFirstChild("HumanoidRootPart")
		if not parent or not parent:IsA("BasePart") then
			continue
		end
		local size = vector(decoration.Size)
		visual.Size = Vector3.new(math.max(0.1, math.abs(size.X)), math.max(0.1, math.abs(size.Y)), 0.12)
		local offset = vector(decoration.Offset)
		local rotation = vector(decoration.Rotation)
		visual.CFrame = parent.CFrame
			* CFrame.new(offset.X, offset.Y, offset.Z + layerDepth(frame, "Decoration:" .. index))
			* CFrame.Angles(math.rad(rotation.X), math.rad(rotation.Y), math.rad(rotation.Z))
		local digits = string.match(tostring(decoration.AssetId or ""), "%d+")
		visual.Transparency = digits and 0.9 or 0.4
		for _, decal in visual:GetChildren() do
			if decal:IsA("Decal") then
				decal.Texture = digits and ("rbxassetid://" .. digits) or ""
				decal.Transparency = digits and 0 or 1
			end
		end
	end
end

function MotionPlayer.Play(rig: Model, motion: any, target: Model?)
	if not rig or not motion or not motion.Frames or #motion.Frames < 2 then
		return
	end
	task.spawn(function()
		local motors: { [string]: Motor6D } = {}
		for name in JOINT_ALIASES do
			local motor = findMotor(rig, name)
			if motor then
				motors[name] = motor
			end
		end
		local weaponMotor = findMotor(rig, "MotionWeaponMotor")
		local dualWeaponMotor = findMotor(rig, "MotionDualWeaponMotor")
		local weaponPart = rig:FindFirstChild("MotionWeapon", true)
		local dualWeaponPart = rig:FindFirstChild("MotionDualWeapon", true)
		local root = rig:FindFirstChild("HumanoidRootPart")
		local rootStart = root and root:IsA("BasePart") and root.CFrame or nil
		local playedEvents: { [string]: boolean } = {}
		local teleportOffset = Vector3.zero
		local decorationVisuals = createDecorationVisuals(rig)
		local playedHits: { [number]: boolean } = {}
		local started = os.clock()
		-- Keep one render interval after Duration so events authored on the last frame are not skipped.
		while rig.Parent and os.clock() - started < motion.Duration + 0.05 do
			local elapsed = math.min(motion.Duration, os.clock() - started)
			local currentFrame = frameAt(motion.Frames, elapsed)
			for name, motor in motors do
				motor.Transform = poseAt(motion.Frames, elapsed, name, motor)
			end
			syncWeaponHands(rig, weaponMotor, dualWeaponMotor, currentFrame.HandSwap == true)
			if weaponMotor then
				weaponMotor.Transform = weaponAt(motion.Frames, elapsed)
			end
			if dualWeaponMotor then
				dualWeaponMotor.Transform = weaponAt(motion.Frames, elapsed, "DualWeapon")
			end
			if weaponPart and weaponPart:IsA("BasePart") then
				syncWeaponVisual(weaponPart, currentFrame)
			end
			if dualWeaponPart and dualWeaponPart:IsA("BasePart") then
				syncWeaponVisual(dualWeaponPart, currentFrame, "DualWeapon", motion.DualWield == true)
			end
			syncDecorations(rig, decorationVisuals, currentFrame)
			for _, kind in { "Effects", "Projectiles", "Teleports" } do
				for index, event in ((motion.Events and motion.Events[kind]) or {}) do
					local frame = motion.Frames[event.Frame]
					local key = kind .. index
					if frame and not playedEvents[key] and elapsed >= frame.Time then
						playedEvents[key] = true
						if kind == "Teleports" then
							teleportOffset += vector(event.Offset)
						else
							local renderedEvent = table.clone(event)
							local endFrame = motion.Frames[event.EndFrame or event.Frame]
							if endFrame and (event.EndFrame or event.Frame) > event.Frame then
								renderedEvent.Duration = math.max(0.05, endFrame.Time - frame.Time)
							end
							showFrameEvent(rig, renderedEvent, kind, target)
						end
					end
				end
			end
			if root and root:IsA("BasePart") and rootStart then
				local facing = rootStart
				local targetRoot = target and target:FindFirstChild("HumanoidRootPart")
				if targetRoot and targetRoot:IsA("BasePart") and currentFrame.CastDirection ~= "preserve" then
					local targetPosition =
						Vector3.new(targetRoot.Position.X, rootStart.Position.Y, targetRoot.Position.Z)
					if (targetPosition - rootStart.Position).Magnitude > 0.01 then
						facing = CFrame.lookAt(rootStart.Position, targetPosition)
						if currentFrame.CastDirection == "away" then
							facing *= CFrame.Angles(0, math.pi, 0)
						end
					end
				end
				root.CFrame = facing * CFrame.new(rootOffsetAt(motion.Frames, elapsed) + teleportOffset)
			end
			for index, hit in motion.Hits or {} do
				local frame = motion.Frames[hit.Frame]
				if frame and not playedHits[index] and elapsed >= frame.Time then
					playedHits[index] = true
					showHitbox(rig, hit)
				end
			end
			RunService.RenderStepped:Wait()
		end
		for _, motor in motors do
			motor.Transform = CFrame.identity
		end
		if weaponMotor then
			weaponMotor.Transform = CFrame.identity
		end
		if dualWeaponMotor then
			dualWeaponMotor.Transform = CFrame.identity
		end
		syncWeaponHands(rig, weaponMotor, dualWeaponMotor, false)
		if root and root:IsA("BasePart") and rootStart then
			root.CFrame = rootStart
		end
		for _, visual in decorationVisuals do
			visual:Destroy()
		end
	end)
end

return MotionPlayer
