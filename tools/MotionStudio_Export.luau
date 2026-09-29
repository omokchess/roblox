--!nocheck
--[[
	MotionStudio_Export.luau — 직업별 전투 모션을 스튜디오 애니메이션 편집기로 고칠 수 있게 꺼내 놓는다. (2026-09-29)
	편집 모드 로더(StudioJobs)로 돌린다:  bash tools/job.sh tools/MotionStudio_Export.luau

	workspace.MotionStudio 에 직업마다 표준 R6 인형(게임 캐릭터와 같은 관절 축)을 세우고, 직업 기본 무기를 쥐여
	(CombatWeapons — 무기 관절 GripW/GripO 도 편집기에서 움직일 수 있다), 지금 모션을 전부 KeyframeSequence 로 바꿔
	편집기 저장 자리(ServerStorage.RBX_ANIMSAVES.<직업>)에 넣는다. 자세는 게임과 같은 계산(CombatRig:Apply)으로 관절에 입힌 뒤 Transform 을 읽는다.
	이름은 "Idle 대기", "Skill_FrontBackPierce 앞뒤관통" 꼴 — 앞 낱말이 열쇠라 저장할 때 **이름을 바꾸지 말 것**.
	**다시 돌려도 안전하다**: 무대·인형이 있으면 그대로 두고 **없는 모션만 채운다**(사용자가 고친 저장본은 건드리지 않는다).
	통째로 새로 만들려면 커맨드 바에서 _G.MotionStudioRebuild = true 뒤 돌린다(고친 저장본이 지워진다).
	플레이 때 고친 것만 쓰이는 방식은 src/server/MotionStudioService.luau · src/shared/Combat/MotionImport.luau.
]]
local HS = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client

local function report(text)
	pcall(function()
		HS:PostAsync("http://127.0.0.1:34999/motionstudio", text)
	end)
end

if workspace:FindFirstChild("MotionStudio") and _G.MotionStudioRebuild then
	workspace.MotionStudio:Destroy()
	local store = game:GetService("ServerStorage"):FindFirstChild("RBX_ANIMSAVES")
	for _, c in (store and store:GetChildren()) or {} do
		if c:IsA("ObjectValue") then
			c:Destroy()
		end
	end
end
_G.MotionStudioRebuild = nil

local MotionMath = require(RS.Shared.Combat.MotionMath)
local MotionImport = require(RS.Shared.Combat.MotionImport)
local CombatMotions = require(RS.Shared.Combat.CombatMotions)
local BattleSkills = require(RS.Shared.BattleSkills)
local CharacterDefinitions = require(RS.Shared.CharacterDefinitions)
local CombatRig = require(Client.Combat.CombatRig)
local CombatWeapons = require(Client.Combat.CombatWeapons)

local BASE = CFrame.new(0, 1200, 0)
local SPACING = 9

-- 표준 R6(게임 캐릭터와 같은 C0·C1)
local function stdRig(name, color, at)
	local rig = Instance.new("Model")
	rig.Name = name
	local function part(n, size, c)
		local p = Instance.new("Part")
		p.Name = n
		p.Size = size
		p.Color = c
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.CanCollide = false
		p.Parent = rig
		return p
	end
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), color)
	root.Transparency = 1
	root.Anchored = true
	local torso = part("Torso", Vector3.new(2, 2, 1), color)
	local head = part("Head", Vector3.new(2, 1, 1), Color3.fromRGB(240, 205, 170))
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	mesh.Parent = head
	local ra = part("Right Arm", Vector3.new(1, 2, 1), color)
	local la = part("Left Arm", Vector3.new(1, 2, 1), color)
	local rl = part("Right Leg", Vector3.new(1, 2, 1), color:Lerp(Color3.new(0, 0, 0), 0.25))
	local ll = part("Left Leg", Vector3.new(1, 2, 1), color:Lerp(Color3.new(0, 0, 0), 0.25))
	local function motor(parent, n, p0, p1, c0, c1)
		local m = Instance.new("Motor6D")
		m.Name = n
		m.Part0, m.Part1, m.C0, m.C1 = p0, p1, c0, c1
		m.Parent = parent
	end
	local ROOT = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	motor(root, "RootJoint", root, torso, ROOT, ROOT)
	motor(torso, "Neck", torso, head, CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0))
	motor(torso, "Right Shoulder", torso, ra, CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	motor(torso, "Left Shoulder", torso, la, CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))
	motor(torso, "Right Hip", torso, rl, CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	motor(torso, "Left Hip", torso, ll, CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R6
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.Parent = rig
	Instance.new("Animator").Parent = hum
	rig.PrimaryPart = root
	rig:PivotTo(at)
	return rig
end

-- 관절 이름 → 포즈 이름(Part1)
local JOINTS = {
	{ "HumanoidRootPart", "RootJoint", "Torso" },
	{ "Torso", "Neck", "Head" },
	{ "Torso", "Right Shoulder", "Right Arm" },
	{ "Torso", "Left Shoulder", "Left Arm" },
	{ "Torso", "Right Hip", "Right Leg" },
	{ "Torso", "Left Hip", "Left Leg" },
}

local LABEL = { Idle = "대기", Held = "들림", Drop = "내려놓임", Hit = "피격", Guard = "방어", Dodge = "회피", Death = "쓰러짐" }

local function buildSequence(rig, api, gripMotors, key, label, motion)
	local compiled = MotionMath.Compile(motion)
	local frames = MotionImport.Frames(compiled)

	local seq = Instance.new("KeyframeSequence")
	seq.Name = key .. " " .. label
	seq.Loop = compiled.Loop
	seq.Priority = Enum.AnimationPriority.Action
	local byTime = {}
	for _, f in frames do
		api:Apply(f.pose)
		local style, dir = MotionImport.PoseEase(f.nextE)
		local kf = Instance.new("Keyframe")
		kf.Time = f.t
		local function pose(name, cf, parent)
			local p = Instance.new("Pose")
			p.Name = name
			p.CFrame = cf
			p.EasingStyle, p.EasingDirection = style, dir
			p.Weight = 1
			p.Parent = parent
			return p
		end
		local hrp = pose("HumanoidRootPart", CFrame.new(), kf)
		hrp.Weight = 0
		local made = { HumanoidRootPart = hrp }
		for _, j in JOINTS do
			local m = rig[j[1]]:FindFirstChild(j[2])
			made[j[3]] = pose(j[3], m.Transform, made[j[1]])
		end
		for slot, m in gripMotors do
			pose("Grip" .. slot, m.Transform, made[m.Part0.Name])
		end
		kf.Parent = seq
		byTime[f.t] = kf
	end
	for _, ev in compiled.Events do
		local kf = nil
		for t, k in byTime do
			if math.abs(t - ev.t) < 1e-3 then
				kf = k
			end
		end
		if not kf then
			kf = Instance.new("Keyframe")
			kf.Time = ev.t
			kf.Parent = seq
			byTime[ev.t] = kf
		end
		local marker = Instance.new("KeyframeMarker")
		marker.Name = tostring(ev.k)
		marker.Value = MotionImport.EncodeEvent(ev)
		marker.Parent = kf
	end
	seq:SetAttribute("Sig", MotionImport.Signature(seq))
	return seq
end

local studio = workspace:FindFirstChild("MotionStudio")
if not studio then
	studio = Instance.new("Folder")
	studio.Name = "MotionStudio"
end
local stage = studio:FindFirstChild("무대") or Instance.new("Part")
stage.Name = "무대"
stage.Anchored = true
stage.Size = Vector3.new(SPACING * 11, 1, 16)
stage.Color = Color3.fromRGB(40, 38, 46)
stage.Material = Enum.Material.Slate
stage.CFrame = BASE * CFrame.new(SPACING * 4, -3.5, 0)
stage.Parent = studio

local lines = {}
local total = 0
for i, def in CharacterDefinitions.All() do
	local classId = def.Id
	local at = BASE * CFrame.new((i - 1) * SPACING, 0, 0)
	local rig = studio:FindFirstChild(classId)
	local newRig = rig == nil
	if newRig then
		rig = stdRig(classId, Color3.fromHSV((i * 0.11) % 1, 0.35, 0.8), at)
		rig:SetAttribute("ClassId", classId)
		rig.Parent = studio
	end
	-- 이름표(무대 앞, 인형 밖 — 편집기가 인형 부품으로 착각하지 않게)
	local sign = studio:FindFirstChild("이름표_" .. classId) or Instance.new("Part")
	sign.Name = "이름표_" .. classId
	sign.Anchored, sign.CanCollide, sign.Transparency = true, false, 1
	sign.Size = Vector3.new(1, 1, 1)
	sign.CFrame = at * CFrame.new(0, 4.5, 0)
	sign.Parent = studio
	local bb = sign:FindFirstChildOfClass("BillboardGui") or Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(160, 30)
	bb.AlwaysOnTop = true
	bb.Parent = sign
	local tl = bb:FindFirstChildOfClass("TextLabel") or Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.TextColor3 = Color3.new(1, 1, 1)
	tl.TextStrokeTransparency = 0.3
	tl.Font = Enum.Font.GothamBold
	tl.TextSize = 16
	tl.Text = (def.Name or classId) .. " (" .. classId .. ")"
	tl.Parent = bb

	local api = CombatRig.new(rig)
	local gripMotors = {}
	if newRig then
		local weapons = CombatWeapons.Attach(rig, api, nil, classId)
		-- 떠 있는 무기(오브)는 관절이 없어 편집기에서 못 움직인다 — 인형에선 뺀다
		for _, orb in weapons.Orbs do
			orb:Destroy()
		end
		-- 편집기는 부품 이름이 겹치면 못 쓴다: 쥐는 점 GripW/GripO, 무기 조각은 W_/O_ 머리
		for slot, model in weapons.Pieces do
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					d.Name = if d == model.PrimaryPart then "Grip" .. slot else slot .. "_" .. d.Name
				end
			end
			gripMotors[slot] = weapons.Motors[slot]
		end
	else
		-- 있는 인형: 사용자가 고친 쥐는 모양(모터 C0)을 그대로 쓴다
		for _, slot in { "W", "O" } do
			local g = rig:FindFirstChild("Grip" .. slot, true)
			local m = g and g:FindFirstChild("CombatGrip" .. slot)
			if m then
				gripMotors[slot] = m
				api:SetWeaponMotor(slot, m)
			end
		end
	end

	-- 편집기의 저장 방식 그대로: ServerStorage.RBX_ANIMSAVES / ObjectValue <직업>(Value = 인형) / 모션들,
	-- 인형 AnimSaves = 그 ObjectValue 를 가리킴(이렇게 두면 편집기가 옮기기 창 없이 바로 연다)
	local store = game:GetService("ServerStorage"):FindFirstChild("RBX_ANIMSAVES")
	if not store then
		store = Instance.new("Model")
		store.Name = "RBX_ANIMSAVES"
		store.Parent = game:GetService("ServerStorage")
	end
	local saves = store:FindFirstChild(classId)
	if not saves then
		saves = Instance.new("ObjectValue")
		saves.Name = classId
		saves.Parent = store
	end
	saves.Value = rig
	local pointer = rig:FindFirstChild("AnimSaves") or Instance.new("ObjectValue")
	pointer.Name = "AnimSaves"
	pointer.Value = saves
	pointer.Parent = rig
	-- 이미 있는 모션(앞 낱말)은 건너뛴다 — 사용자가 고친 것을 덮지 않게
	local have = {}
	for _, c in saves:GetChildren() do
		local k = string.match(c.Name, "^(%S+)")
		if k then
			have[k] = true
		end
	end
	local list = {}
	for key, label in LABEL do
		local set = CombatMotions.Sets[classId]
		local motion = (set and set[key]) or CombatMotions.Sets.Common[key]
		if motion and motion.Keys then
			table.insert(list, { key, label, motion })
		end
	end
	local ids, seen = {}, {}
	for _, s in BattleSkills.ForClass(classId) do
		table.insert(ids, s.Id)
	end
	for _, s in BattleSkills.Common() do
		table.insert(ids, s.Id)
	end
	for id in (CombatMotions.Sets[classId] and CombatMotions.Sets[classId].Skills) or {} do
		table.insert(ids, id)
	end
	-- 강화 스킬(조건이 차면 열리는 것)
	for _, s in BattleSkills.Upgrades() do
		if s.ClassId == classId then
			table.insert(ids, s.Id)
		end
	end
	for _, id in ids do
		if not seen[id] then
			seen[id] = true
			local s = BattleSkills.ById(id)
			table.insert(list, { "Skill_" .. id, (s and s.Name or id):gsub("%s", "_"), CombatMotions.Skill(classId, id) })
		end
	end
	local n = 0
	for _, item in list do
		if have[item[1]] then
			continue
		end
		local ok, err = pcall(function()
			buildSequence(rig, api, gripMotors, item[1], item[2], item[3]).Parent = saves
		end)
		if ok then
			n += 1
		else
			table.insert(lines, classId .. " " .. item[1] .. " 실패: " .. tostring(err))
		end
	end
	api:Reset()
	total += n
	table.insert(lines, string.format("%s 새로 넣은 모션 %d개%s", classId, n, if newRig then " (새 인형)" else ""))
end
studio.Parent = workspace
report(string.format("무대 %s, 새로 넣은 모션 %d개\n%s", tostring(BASE.Position), total, table.concat(lines, "\n")))
