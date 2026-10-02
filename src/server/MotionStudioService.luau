--!strict
--[[
	MotionStudioService — 스튜디오 애니메이션 편집기로 고친 전투 모션을 플레이 때 클라이언트로 넘긴다. (2026-09-29)

	편집 모드: workspace.MotionStudio 에 직업마다 인형(속성 ClassId)이 서 있고, 인형의 저장본(AnimSaves)이 모션이다
	(tools/MotionStudio_Export.luau 가 지금 모션으로 채워 둔다 — Shared.Combat.MotionImport 설명).
	플레이 시작: 인형마다 **고친** 저장본만 ReplicatedStorage.MotionStudio.<직업>.<이름> 으로 모으고, 인형 무대는 치운다
	(게임 화면에 인형이 보이지 않게). 손대지 않은 저장본은 속성 Sig 가 내용과 같아 건너뛴다 → 코드 모션을 그대로 쓴다.

	편집기 저장 위치(2026-09 스튜디오에서 확인): ServerStorage.RBX_ANIMSAVES(Model) 안 ObjectValue <인형 이름>(Value = 인형)의
	자식 KeyframeSequence 들, 인형의 AnimSaves 는 그 ObjectValue 를 가리키는 ObjectValue. 옛 방식(인형 AnimSaves 안에 바로)도 본다.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local MotionImport = require(ReplicatedStorage.Shared.Combat.MotionImport)

local MotionStudioService = {}

local function saves(rig: Instance): { KeyframeSequence }
	local list = {}
	local function add(x: Instance?)
		if x and x:IsA("KeyframeSequence") then
			table.insert(list, x)
		end
	end
	local function scan(holder: Instance?)
		for _, c in (holder and holder:GetChildren()) or {} do
			if c:IsA("ObjectValue") then
				add(c.Value)
			else
				add(c)
			end
		end
	end
	-- 인형의 AnimSaves: 옛 방식은 그 안에 바로, 새 방식은 ObjectValue 가 RBX_ANIMSAVES 쪽 묶음을 가리킨다
	local holder = rig:FindFirstChild("AnimSaves")
	if holder and holder:IsA("ObjectValue") then
		scan(holder.Value)
	else
		scan(holder)
	end
	local store = ServerStorage:FindFirstChild("RBX_ANIMSAVES")
	local mine = store and store:FindFirstChild(rig.Name)
	if mine and mine ~= (holder and holder:IsA("ObjectValue") and holder.Value) then
		scan(mine)
	end
	return list
end

-- 2026-09-30 사용자가 애니메이션 편집기 방식을 접었다(버그가 많음) — 코드 모션(Motions/<직업>.luau)만 쓴다.
-- 무대에 남은 편집본·쥐는 모양(음악가 인형의 활·바이올린 C0 를 손댄 것)이 새 자세를 덮어쓰지 않게 끈다.
local USE_STUDIO_EDITS = false

function MotionStudioService.Start()
	local studio = workspace:FindFirstChild("MotionStudio")
	if not studio then
		return
	end
	if not USE_STUDIO_EDITS then
		studio:Destroy()
		return
	end
	local out = Instance.new("Folder")
	out.Name = "MotionStudio"
	local count = 0
	for _, rig in studio:GetChildren() do
		local classId = rig:GetAttribute("ClassId")
		if typeof(classId) ~= "string" then
			continue
		end
		local folder = Instance.new("Folder")
		folder.Name = classId
		folder.Parent = out
		-- 쥐는 모양: 인형 무기 모터 C0(사용자가 속성 창에서 고친 값) → 클라이언트 CombatWeapons
		for _, slot in { "W", "O" } do
			local grip = rig:FindFirstChild("Grip" .. slot, true)
			local motor = grip and grip:FindFirstChild("CombatGrip" .. slot)
			if motor and motor:IsA("Motor6D") then
				folder:SetAttribute("Grip" .. slot, motor.C0)
			end
		end
		for _, seq in saves(rig) do
			local key = string.match(seq.Name, "^(%S+)")
			local sig = seq:GetAttribute("Sig")
			if not key or (sig ~= nil and sig == MotionImport.Signature(seq)) then
				continue
			end
			local old = folder:FindFirstChild(key)
			if old then
				old:Destroy()
			end
			local copy = seq:Clone()
			copy.Name = key
			copy.Parent = folder
			count += 1
		end
	end
	out.Parent = ReplicatedStorage
	studio:Destroy()
	local grips = 0
	for _, f in out:GetChildren() do
		if f:GetAttribute("GripW") or f:GetAttribute("GripO") then
			grips += 1
		end
	end
	print(string.format("[MotionStudio] 편집기로 고친 모션 %d개, 쥐는 모양 %d직업", count, grips))
end

return MotionStudioService
