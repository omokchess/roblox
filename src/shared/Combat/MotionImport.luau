--!strict
--[[
	MotionImport — 스튜디오 **애니메이션 편집기**로 고친 모션(KeyframeSequence)을 전투 모션 자료로 바꾼다. (2026-09-29)

	요청: "직업별 모션은 내가 짤 수 있게 해줘. 지금 모션을 토대로 내가 짤게."
	  1. tools/MotionStudio_Export.luau 가 workspace.MotionStudio 에 직업마다 R6 인형(직업 기본 무기를 쥔)을 세우고,
	     지금 모션을 전부 KeyframeSequence 로 바꿔 인형의 AnimSaves 에 넣는다(이름 "Skill_찌르기Id 한글이름" 꼴).
	  2. 사용자는 인형을 골라 애니메이션 편집기에서 불러와 고치고 **같은 이름으로** 저장한다.
	  3. 플레이하면 서버(MotionStudioService)가 인형들의 저장본을 ReplicatedStorage.MotionStudio 로 모으고,
	     CombatMotions 가 여기(FromSequence)로 바꿔 코드 모션 대신 쓴다. 손대지 않은 저장본(Sig 가 그대로)은 코드 모션을 쓴다.

	포즈 → 자료 (CombatRig:Apply 의 거꾸로, R6 표준 관절). 각도가 아니라 **쿼터니언 채널**(MotionMath 주석)로 적는다 —
	편집기는 회전을 쿼터니언으로 잇고, 각도로 옮기면 팔을 수평으로 든 근처(짐벌)에서 값이 튄다.
	  관절 모터의 Transform T 에서 캐릭터 공간 회전 R = C0회전 · T · C0회전⁻¹
	  RootJoint(Torso 포즈)  → RootQ = {자리, 쿼터니언}  (R6 는 골반·몸통이 한 관절이라 Torso 는 0 — 편집기의 몸 전체 움직임 그대로)
	  Head·팔·다리           → HeadQ · RArmQ … = 쿼터니언
	  GripW / GripO          → WQ / OQ = 모터 Transform 그대로 {자리, 쿼터니언}
	키 사이 곡선은 그 구간 **앞** 키프레임 포즈의 EasingStyle/Direction(편집기와 같다). 옛 Cubic·Elastic·Bounce 는
	In/Out 이 뒤바뀌어 있다(로블록스 옛 호환). 관절마다 키가 달라도 되게, 키 시각과 1/30 초마다 관절마다 제 트랙을
	편집기처럼(CFrame:Lerp) 뽑아 촘촘한 직선 키로 적는다.
	사건(맞는 순간·돌진·이펙트)은 애니메이션 이벤트(KeyframeMarker): 이름 = k, 값 = "i=1;to=Target" 꼴.
]]

local MotionMath = require(script.Parent.MotionMath)

local MotionImport = {}

local DEG = 180 / math.pi

-- 포즈 이름(= 관절의 Part1) → 채널과 그 관절의 표준 C0 회전(R6)
local ROOT_C0 = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
local RIGHT_C0 = CFrame.new(0, 0, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)
local LEFT_C0 = CFrame.new(0, 0, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)
MotionImport.CHANNELS = {
	Torso = { Channel = "Root", C0 = ROOT_C0 },
	Head = { Channel = "Head", C0 = ROOT_C0 },
	["Right Arm"] = { Channel = "RArm", C0 = RIGHT_C0 },
	["Left Arm"] = { Channel = "LArm", C0 = LEFT_C0 },
	["Right Leg"] = { Channel = "RLeg", C0 = RIGHT_C0 },
	["Left Leg"] = { Channel = "LLeg", C0 = LEFT_C0 },
	GripW = { Channel = "W" },
	GripO = { Channel = "O" },
}

-- 포즈 곡선 → 모션 곡선 이름
function MotionImport.EaseName(style: Enum.PoseEasingStyle, dir: Enum.PoseEasingDirection): string
	local d = dir.Name
	if style == Enum.PoseEasingStyle.Linear then
		return "linear"
	elseif style == Enum.PoseEasingStyle.Constant then
		return "step"
	elseif style == Enum.PoseEasingStyle.CubicV2 then
		return if d == "In" then "cubicIn" elseif d == "Out" then "cubicOut" else "cubicInOut"
	elseif style == Enum.PoseEasingStyle.Cubic then
		-- 옛 Cubic 은 In/Out 이 뒤바뀌어 있다
		return if d == "In" then "cubicOut" elseif d == "Out" then "cubicIn" else "cubicInOut"
	elseif style == Enum.PoseEasingStyle.Elastic then
		return "elasticOut"
	elseif style == Enum.PoseEasingStyle.Bounce then
		return "bounceOut"
	end
	return "sineInOut"
end

-- 모션 곡선 이름 → 포즈 곡선(내보내기). 편집기에 없는 곡선은 가장 비슷한 CubicV2 로
function MotionImport.PoseEase(name: string?): (Enum.PoseEasingStyle, Enum.PoseEasingDirection)
	local n = name or "sineInOut"
	if n == "linear" then
		return Enum.PoseEasingStyle.Linear, Enum.PoseEasingDirection.In
	elseif n == "step" then
		return Enum.PoseEasingStyle.Constant, Enum.PoseEasingDirection.In
	elseif n == "elasticOut" then
		return Enum.PoseEasingStyle.Elastic, Enum.PoseEasingDirection.In
	elseif n == "bounceOut" then
		return Enum.PoseEasingStyle.Bounce, Enum.PoseEasingDirection.In
	end
	local dir = if n:find("InOut") then Enum.PoseEasingDirection.InOut
		elseif n:find("Out") then Enum.PoseEasingDirection.Out
		else Enum.PoseEasingDirection.In
	return Enum.PoseEasingStyle.CubicV2, dir
end

-- 사건 값 "i=1;to=Target;on=true" ↔ 표
function MotionImport.EncodeEvent(ev: { [string]: any }): string
	local parts = {}
	for key, value in ev do
		if key ~= "t" and key ~= "k" then
			table.insert(parts, key .. "=" .. tostring(value))
		end
	end
	table.sort(parts)
	return table.concat(parts, ";")
end

function MotionImport.DecodeEvent(name: string, t: number, value: string): { [string]: any }
	local ev: { [string]: any } = { t = t, k = name }
	for key, raw in value:gmatch("([%w_]+)=([^;]*)") do
		ev[key] = if raw == "true" then true elseif raw == "false" then false else (tonumber(raw) or raw)
	end
	return ev
end

-- 회전 → 쿼터니언 {x, y, z, w}. prev 와 반대쪽(내적 < 0)이면 뒤집어 이어 붙인다(같은 회전)
local function quat(cf: CFrame, prev: { number }?): { number }
	local _, _, _, m00, m01, m02, m10, m11, m12, m20, m21, m22 = cf:GetComponents()
	local x, y, z, w
	local tr = m00 + m11 + m22
	if tr > 0 then
		local k = math.sqrt(tr + 1) * 2
		w, x, y, z = 0.25 * k, (m21 - m12) / k, (m02 - m20) / k, (m10 - m01) / k
	elseif m00 > m11 and m00 > m22 then
		local k = math.sqrt(1 + m00 - m11 - m22) * 2
		w, x, y, z = (m21 - m12) / k, 0.25 * k, (m01 + m10) / k, (m02 + m20) / k
	elseif m11 > m22 then
		local k = math.sqrt(1 + m11 - m00 - m22) * 2
		w, x, y, z = (m02 - m20) / k, (m01 + m10) / k, 0.25 * k, (m12 + m21) / k
	else
		local k = math.sqrt(1 + m22 - m00 - m11) * 2
		w, x, y, z = (m10 - m01) / k, (m02 + m20) / k, (m12 + m21) / k, 0.25 * k
	end
	if prev then
		local o = #prev - 4
		if prev[o + 1] * x + prev[o + 2] * y + prev[o + 3] * z + prev[o + 4] * w < 0 then
			x, y, z, w = -x, -y, -z, -w
		end
	end
	return { x, y, z, w }
end

-- 관절 Transform → 쿼터니언 채널 값. prev 는 같은 채널의 앞 값(부호를 이어 붙이려고)
function MotionImport.ChannelValue(poseName: string, t: CFrame, prev: { number }?): { number }?
	local spec = MotionImport.CHANNELS[poseName]
	if not spec then
		return nil
	end
	if spec.Channel == "W" or spec.Channel == "O" then
		local q = quat(t, prev)
		return { t.X, t.Y, t.Z, q[1], q[2], q[3], q[4] }
	end
	local c0 = spec.C0 :: CFrame
	local r = c0 * t * c0:Inverse()
	local q = quat(r, prev)
	if spec.Channel == "Root" then
		return { r.X, r.Y, r.Z, q[1], q[2], q[3], q[4] }
	end
	return q
end

type Track = { { t: number, cf: CFrame, e: string } }

-- 키프레임을 시각순으로, 포즈를 관절 트랙으로
local function tracks(seq: KeyframeSequence): ({ number }, { [string]: Track }, { any })
	local frames = {}
	for _, k in seq:GetChildren() do
		if k:IsA("Keyframe") then
			table.insert(frames, k)
		end
	end
	table.sort(frames, function(a, b)
		return a.Time < b.Time
	end)
	local times, seen = {}, {}
	local byName: { [string]: Track } = {}
	local events = {}
	for _, k in frames do
		if not seen[k.Time] then
			seen[k.Time] = true
			table.insert(times, k.Time)
		end
		for _, d in k:GetDescendants() do
			if d:IsA("Pose") and MotionImport.CHANNELS[d.Name] and d.Weight > 0 then
				local track = byName[d.Name] or {}
				byName[d.Name] = track
				table.insert(track, { t = k.Time, cf = d.CFrame, e = MotionImport.EaseName(d.EasingStyle, d.EasingDirection) })
			elseif d:IsA("KeyframeMarker") then
				table.insert(events, MotionImport.DecodeEvent(d.Name, k.Time, d.Value))
			end
		end
	end
	return times, byName, events
end

-- 트랙의 시각 t 값(구간 앞 포즈의 곡선으로 — 편집기처럼 회전은 CFrame:Lerp)
local function sampleTrack(track: Track, t: number): CFrame
	if t <= track[1].t then
		return track[1].cf
	end
	for i = 2, #track do
		local b = track[i]
		if t <= b.t + 1e-6 then
			local a = track[i - 1]
			local span = math.max(1e-4, b.t - a.t)
			local alpha = (MotionMath.Ease[a.e] or MotionMath.Ease.sineInOut)(math.clamp((t - a.t) / span, 0, 1))
			return a.cf:Lerp(b.cf, alpha)
		end
	end
	return track[#track].cf
end

--[[
	KeyframeSequence → 모션 표. base(코드 모션)가 있으면 BlendIn·BlendOut·Hold 는 거기서 이어 받는다
	(편집기 저장본엔 이 값이 없다).
	편집기는 키 사이를 **회전(쿼터니언)** 으로 잇고 모션 자료는 각도를 잇는다 — 둘이 어긋나지 않게 키 시각과
	1/30 초마다 편집기 방식으로 뽑아 촘촘한 직선 키로 적는다.
]]
local STEP = 1 / 30
function MotionImport.FromSequence(seq: KeyframeSequence, base: any?): any
	local times, byName, events = tracks(seq)
	local all: { number } = {}
	local last = times[#times] or 0
	for _, t in times do
		table.insert(all, t)
	end
	local t = (times[1] or 0) + STEP
	while t < last - 1e-4 do
		local close = false
		for _, k in times do
			if math.abs(k - t) < STEP * 0.25 then
				close = true
			end
		end
		if not close then
			table.insert(all, t)
		end
		t += STEP
	end
	table.sort(all)
	local keys = {}
	local prev: { [string]: { number } } = {}
	for i, at in all do
		local key: { [string]: any } = { t = at, Torso = { 0, 0, 0 } }
		if i > 1 then
			key.e = "linear"
		end
		for poseName, track in byName do
			local q = MotionMath.Q_OF[MotionImport.CHANNELS[poseName].Channel]
			local v = MotionImport.ChannelValue(poseName, sampleTrack(track, at), prev[q])
			key[q] = v
			prev[q] = v
		end
		table.insert(keys, key)
	end
	local duration = last
	for _, ev in events do
		duration = math.max(duration, ev.t)
	end
	return {
		Duration = duration,
		Loop = seq.Loop,
		BlendIn = base and base.BlendIn,
		BlendOut = base and base.BlendOut,
		Hold = base and base.Hold,
		Keys = keys,
		Events = events,
		Authored = true,
	}
end

--[[
	내보낼 키프레임 줄: 모션 키마다 {t, pose, nextE(이 키에서 다음 키로 가는 곡선)}.
	되풀이면 마지막에 첫 자세로 돌아가는 키를, 아니면 길이까지 버티는 키를 덧붙인다(편집기 길이 = 모션 길이).
]]
function MotionImport.Frames(compiled: any): { { t: number, pose: any, nextE: string? } }
	local keys = compiled.Keys
	local frames = {}
	for i, k in keys do
		table.insert(frames, { t = k.t, pose = k.pose, nextE = keys[i + 1] and keys[i + 1].e })
	end
	local last = frames[#frames]
	if compiled.Loop and #keys > 1 and compiled.Duration > last.t + 1e-3 then
		last.nextE = keys[1].e
		table.insert(frames, { t = compiled.Duration, pose = keys[1].pose, nextE = "linear" })
	elseif compiled.Duration > last.t + 1e-3 then
		last.nextE = "linear"
		table.insert(frames, { t = compiled.Duration, pose = last.pose, nextE = "linear" })
	end
	return frames
end

--[[
	저장본의 지문(키 시각·포즈 CFrame·곡선·사건). 내보낼 때 Sig 속성에 적어 두고, 같으면 "손대지 않음"으로 본다.
]]
function MotionImport.Signature(seq: KeyframeSequence): string
	local times, byName, events = tracks(seq)
	local parts = { tostring(seq.Loop), #times }
	local names = {}
	for name in byName do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in names do
		for _, p in byName[name] do
			local x, y, z = p.cf:ToEulerAnglesXYZ()
			table.insert(parts, string.format("%s%.2f:%.3f,%.3f,%.3f,%.2f,%.2f,%.2f%s", name, p.t, p.cf.X, p.cf.Y, p.cf.Z, x * DEG, y * DEG, z * DEG, p.e))
		end
	end
	for _, ev in events do
		table.insert(parts, string.format("%s%.2f", tostring(ev.k), ev.t))
	end
	return table.concat(parts, "|")
end

return MotionImport
