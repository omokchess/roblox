--!strict
--[[
	CombatRig — 아바타 관절에 전투 모션 자세를 **입힌다**(R6·R15 둘 다). (2026-09-28)

	자세 값의 뜻은 `Shared.Combat.MotionMath` 주석(캐릭터 공간 도).
	관절 모터의 Transform 은 모터 자기 축(C0 회전)으로 먹으므로, 캐릭터 공간 회전 R 을
	C0 회전으로 켤레 변환해 넣는다:  Transform = C0회전⁻¹ · R · C0회전
	(Part1 = Part0 · C0 · Transform · C1⁻¹ 이라 이렇게 하면 관절점을 중심으로 R 만큼 돈다)

	R6 는 다리가 몸통에 붙어 있어서, 모션 규칙(몸통 = 허리에서 굽힘, 다리 = 골반 기준)에 맞추려고
	  몸통 관절: Root · 허리점 이동 · 몸통회전 · 되돌림   (허리점 = 몸통 아래 가운데 (0,-1,0))
	  다리 관절: 몸통회전⁻¹ · 다리회전                  (몸통을 숙여도 다리는 그대로)
	로 넣는다. 미리보기 도구(tools/combat/preview_motion.py solve)도 같은 계산이다.

	기본 Animate 스크립트와 재생 중인 애니메이션이 Transform 을 덮어쓰므로, 전투에 들어가면
	`Take()` 로 멈추고 끝나면 `Release()` 로 되돌린다. Apply 는 PreSimulation 에서 불러야 한다(CombatDirector).
]]

local MotionMath = require(game:GetService("ReplicatedStorage").Shared.Combat.MotionMath)

local CombatRig = {}
CombatRig.__index = CombatRig

type Channel = { Motor: Motor6D, Conj: CFrame, ConjInv: CFrame }

local R6 = {
	Torso = { "HumanoidRootPart", "RootJoint" },
	Head = { "Torso", "Neck" },
	RArm = { "Torso", "Right Shoulder" },
	LArm = { "Torso", "Left Shoulder" },
	RLeg = { "Torso", "Right Hip" },
	LLeg = { "Torso", "Left Hip" },
}
-- R15 는 몸이 원래 허리에서 나뉘어 있다: Root = 골반(다리까지), Torso = 허리 위
local R15 = {
	Root = { "LowerTorso", "Root" },
	Torso = { "UpperTorso", "Waist" },
	Head = { "Head", "Neck" },
	RArm = { "RightUpperArm", "RightShoulder" },
	RElbow = { "RightLowerArm", "RightElbow" },
	LArm = { "LeftUpperArm", "LeftShoulder" },
	LElbow = { "LeftLowerArm", "LeftElbow" },
	RLeg = { "RightUpperLeg", "RightHip" },
	RKnee = { "RightLowerLeg", "RightKnee" },
	LLeg = { "LeftUpperLeg", "LeftHip" },
	LKnee = { "LeftLowerLeg", "LeftKnee" },
}

local RAD = math.pi / 180

local function rot(v: { number }, o: number?): CFrame
	local i = o or 0
	return CFrame.fromOrientation((v[i + 1] or 0) * RAD, (v[i + 2] or 0) * RAD, (v[i + 3] or 0) * RAD)
end

function CombatRig.new(character: Model)
	local self = setmetatable({}, CombatRig)
	self.Character = character
	self.IsR6 = character:FindFirstChild("Torso") ~= nil
	self.Channels = {} :: { [string]: Channel }
	self.WeaponMotors = {} :: { [string]: Motor6D }
	for channel, spec in (if self.IsR6 then R6 else R15) :: any do
		local holder = character:FindFirstChild(spec[1])
		local motor = holder and holder:FindFirstChild(spec[2])
		if motor and motor:IsA("Motor6D") then
			local conj = motor.C0.Rotation
			self.Channels[channel] = { Motor = motor, Conj = conj, ConjInv = conj:Inverse() }
		end
	end
	self.taken = false
	return self
end

-- 무기 모터(W = 오른손, O = 왼손)를 등록한다. CombatWeapons 가 만든다.
function CombatRig:SetWeaponMotor(slot: string, motor: Motor6D?)
	self.WeaponMotors[slot] = motor
end

-- 전투 모션이 관절을 쓰도록 기본 애니메이션을 멈춘다
function CombatRig:Take()
	if self.taken then
		return
	end
	self.taken = true
	local character = self.Character
	local animate = character:FindFirstChild("Animate")
	if animate and animate:IsA("LocalScript") then
		self.animateWasEnabled = animate.Enabled
		animate.Enabled = false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in animator:GetPlayingAnimationTracks() do
			track:Stop(0)
		end
		-- 전투 중 다른 스크립트가 트는 애니메이션도 바로 멈춘다(관절을 두고 다투지 않게)
		self.playedConn = animator.AnimationPlayed:Connect(function(track)
			track:Stop(0)
		end)
	end
end

function CombatRig:Release()
	if not self.taken then
		return
	end
	self.taken = false
	if self.playedConn then
		self.playedConn:Disconnect()
		self.playedConn = nil
	end
	self:Reset()
	local animate = self.Character:FindFirstChild("Animate")
	if animate and animate:IsA("LocalScript") and self.animateWasEnabled ~= false then
		animate.Enabled = true
	end
end

function CombatRig:Reset()
	for _, ch in self.Channels do
		if ch.Motor.Parent then
			ch.Motor.Transform = CFrame.identity
		end
	end
	for slot, motor in self.WeaponMotors do
		if motor.Parent then
			motor.Transform = CFrame.identity
		else
			self.WeaponMotors[slot] = nil
		end
	end
end

local WAIST = CFrame.new(0, -1, 0)
local WAIST_BACK = CFrame.new(0, 1, 0)
local ZERO = { 0, 0, 0, 0, 0, 0 }

-- 쿼터니언 채널 값(MotionMath 주석) → CFrame. 관절 {qx,qy,qz,qw}, Root·W·O {x,y,z,qx,qy,qz,qw}
local function quatCf(q: { number }): CFrame
	local o = if #q == 7 then 3 else 0
	local x, y, z, w = q[o + 1], q[o + 2], q[o + 3], q[o + 4]
	local n = math.sqrt(x * x + y * y + z * z + w * w)
	if n < 1e-6 then
		return if o == 3 then CFrame.new(q[1], q[2], q[3]) else CFrame.identity
	end
	x, y, z, w = x / n, y / n, z / n, w / n
	if o == 3 then
		return CFrame.new(q[1], q[2], q[3], x, y, z, w)
	end
	return CFrame.new(0, 0, 0, x, y, z, w)
end

-- 자세 하나를 관절에 입힌다. 쿼터니언 채널(이름 뒤 Q — 편집기로 고친 모션)이 있으면 그것을 먼저 쓴다
function CombatRig:Apply(pose: MotionMath.Pose)
	local rootQ = pose.RootQ
	local root = pose.Root or ZERO
	local rootCf = if rootQ then quatCf(rootQ) else CFrame.new(root[1], root[2], root[3]) * rot(root, 3)
	local torsoRot = if pose.TorsoQ then quatCf(pose.TorsoQ) else rot(pose.Torso or ZERO)
	local isR6 = self.IsR6
	for channel, ch in self.Channels do
		local r: CFrame
		if channel == "Root" then
			r = rootCf
		elseif channel == "Torso" then
			r = if isR6 then rootCf * WAIST * torsoRot * WAIST_BACK else torsoRot
		else
			local q = pose[channel .. "Q"]
			local v = pose[channel]
			if q then
				r = quatCf(q)
			elseif v then
				r = rot(v)
			else
				continue
			end
			if isR6 and (channel == "RLeg" or channel == "LLeg") then
				r = torsoRot:Inverse() * r
			end
		end
		ch.Motor.Transform = ch.ConjInv * r * ch.Conj
	end
	for slot, motor in self.WeaponMotors do
		if not motor.Parent then
			continue
		end
		local q = pose[slot .. "Q"]
		local w = pose[slot]
		if q then
			motor.Transform = quatCf(q)
		elseif w then
			-- 무기는 CFrame.Angles 순서(숙임 → 날 비틀기 → 기울기)로 돌린 뒤 **무기 자기 축**으로 민다: MotionMath 주석
			motor.Transform = CFrame.Angles(w[4] * RAD, w[5] * RAD, w[6] * RAD) * CFrame.new(w[1], w[2], w[3])
		end
	end
end

return CombatRig
