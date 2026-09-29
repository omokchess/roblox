--!strict
--[[
	MotionMath — 전투 모션의 **수치 계산**(가속 곡선·키 채우기·보간·섞기). (2026-09-28)

	Roblox 객체를 전혀 안 쓰는 순수 계산이라 Lune 으로 시험하고, 블렌더 미리보기 도구도
	같은 규칙을 따른다(tools/combat/preview_motion.py).

	모션 자료 모양(직업별 모션 파일이 이렇게 쓴다)
	  {
	    Duration = 1.1,          -- 초
	    Loop = false,            -- 대기 자세처럼 되풀이하면 true
	    BlendIn = 0.08,          -- 앞 자세에서 넘어오는 시간
	    BlendOut = 0.16,         -- 끝나고 대기 자세로 돌아가는 시간(Hold 면 안 돌아감)
	    Keys = {
	      { t = 0, Torso = {x,y,z}, RArm = {...}, Root = {x,y,z, rx,ry,rz}, W = {...} },
	      { t = 0.2, e = "backOut", RArm = {...} },   -- e = 이 키로 **들어오는** 곡선
	    },
	    Events = { { t = 0.3, k = "Hit", i = 1 }, { t = 0.25, k = "Vfx", fx = "Slash", ... } },
	  }

	관절 각도는 **캐릭터 공간 도(°)** 다: X = 오른쪽 축(앞뒤로 숙임), Y = 위 축(돌기), Z = 뒤 축(옆으로 기욺).
	  - 팔·다리: X+ 면 앞으로 든다(90 = 수평으로 앞). 오른팔 Z+ 는 바깥으로 벌림, 왼팔은 Z- 가 바깥.
	  - 몸통·머리: X- 면 앞으로 숙이고 X+ 면 뒤로 젖힌다. Y+ 는 왼쪽으로 돈다. Z+ 는 왼쪽으로 기운다.
	    몸통은 **허리(몸통 아래 가운데)** 에서 굽는다 — 다리는 따라 돌지 않는다.
	  - 다리는 골반(Root) 기준이다. 몸통을 숙여도 다리는 그대로 서 있다.
	  - Root: 몸 전체(다리까지)의 자리(스터드, x 오른쪽 · y 위 · z 뒤)와 회전(도).
	  - W / O: 오른손 무기 / 왼손 무기의 쥔 점 기준 자리·회전(무기 공간, WeaponDefinitions 주석).
	    회전은 관절과 달리 CFrame.Angles 순서다: {x,y,z, 숙임, 비틀기, 기울기}
	      숙임 0 = 팔에 직각(팔을 내리면 앞을 봄), -90 = 팔과 일직선(찌르기), 90 = 팔 쪽으로 거꾸로
	      비틀기 = 날 길이 축으로 돌림(날이 향하는 쪽을 바꿈), 기울기 = 날 면 안에서 좌우로 젖힘
	    자리(x,y,z)는 돌린 **뒤의 무기 자기 축**으로 민다: y- 면 무기를 길이 방향으로 손 쪽으로 당긴다
	      (바이올린을 턱까지 끌어오기, 도끼 자루를 짧게 잡기 …)
	  - RElbow·LElbow·RKnee·LKnee 는 R15 몸에만 먹는다(R6 에선 무시).
	키에 없는 관절은 **앞 키 값을 그대로 이어 받는다**(첫 키에 없으면 0).
]]

local MotionMath = {}

export type Pose = { [string]: { number } }

MotionMath.JOINTS = { "Torso", "Head", "RArm", "LArm", "RElbow", "LElbow", "RLeg", "LLeg", "RKnee", "LKnee" }
MotionMath.SIX = { "Root", "W", "O" }

--=== 가속 곡선 ===--
local PI = math.pi
local ease: { [string]: (number) -> number } = {}
ease.linear = function(x)
	return x
end
ease.sineIn = function(x)
	return 1 - math.cos(x * PI / 2)
end
ease.sineOut = function(x)
	return math.sin(x * PI / 2)
end
ease.sineInOut = function(x)
	return -(math.cos(PI * x) - 1) / 2
end
ease.quadIn = function(x)
	return x * x
end
ease.quadOut = function(x)
	return 1 - (1 - x) * (1 - x)
end
ease.quadInOut = function(x)
	return if x < 0.5 then 2 * x * x else 1 - (-2 * x + 2) ^ 2 / 2
end
ease.cubicIn = function(x)
	return x * x * x
end
ease.cubicOut = function(x)
	return 1 - (1 - x) ^ 3
end
ease.cubicInOut = function(x)
	return if x < 0.5 then 4 * x * x * x else 1 - (-2 * x + 2) ^ 3 / 2
end
ease.quartOut = function(x)
	return 1 - (1 - x) ^ 4
end
ease.quartIn = function(x)
	return x ^ 4
end
ease.expoOut = function(x)
	return if x >= 1 then 1 else 1 - 2 ^ (-10 * x)
end
ease.expoIn = function(x)
	return if x <= 0 then 0 else 2 ^ (10 * x - 10)
end
ease.backOut = function(x)
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end
ease.backIn = function(x)
	local c1 = 1.70158
	return (c1 + 1) * x * x * x - c1 * x * x
end
ease.backInOut = function(x)
	local c2 = 1.70158 * 1.525
	return if x < 0.5
		then ((2 * x) ^ 2 * ((c2 + 1) * 2 * x - c2)) / 2
		else ((2 * x - 2) ^ 2 * ((c2 + 1) * (x * 2 - 2) + c2) + 2) / 2
end
ease.elasticOut = function(x)
	if x <= 0 or x >= 1 then
		return x
	end
	return 2 ^ (-10 * x) * math.sin((x * 10 - 0.75) * (2 * PI) / 3) + 1
end
ease.bounceOut = function(x)
	local n1, d1 = 7.5625, 2.75
	if x < 1 / d1 then
		return n1 * x * x
	elseif x < 2 / d1 then
		x -= 1.5 / d1
		return n1 * x * x + 0.75
	elseif x < 2.5 / d1 then
		x -= 2.25 / d1
		return n1 * x * x + 0.9375
	end
	x -= 2.625 / d1
	return n1 * x * x + 0.984375
end
-- 앞 값을 붙잡고 있다가 끝에서 툭 바뀐다(순간 자세 전환)
ease.step = function(x)
	return if x >= 1 then 1 else 0
end
MotionMath.Ease = ease

local function curve(name: string?): (number) -> number
	return ease[name or "sineInOut"] or ease.sineInOut
end

--=== 키 채우기 ===--

local ZERO3 = { 0, 0, 0 }
local ZERO6 = { 0, 0, 0, 0, 0, 0 }

--[[
	모션을 재생하기 좋은 꼴로 바꾼다: 시간순 정렬, 빠진 관절은 앞 키에서 이어 받기, 사건 정렬.
	같은 모션을 여러 번 쓰므로 한 번만 하고 결과를 모션 표에 달아 둔다(`_c`).
]]
function MotionMath.Compile(motion: any): any
	if motion._c then
		return motion._c
	end
	local keys = table.clone(motion.Keys or {})
	table.sort(keys, function(a, b)
		return (a.t or 0) < (b.t or 0)
	end)
	local out = {}
	-- 채널 이름과 길이: 사람 관절 + 키에 나오는 다른 채널(슬라임의 Body 같은 것)
	local sizes: { [string]: number } = {}
	for _, name in MotionMath.JOINTS do
		sizes[name] = 3
	end
	for _, name in MotionMath.SIX do
		sizes[name] = 6
	end
	for _, key in keys do
		for name, v in key do
			if type(v) == "table" and sizes[name] == nil then
				sizes[name] = #v
			end
		end
	end
	local prev: { [string]: { number } } = {}
	for name, size in sizes do
		prev[name] = if size == 3 then ZERO3 elseif size == 6 then ZERO6 else table.create(size, 0)
	end
	for _, key in keys do
		local pose: { [string]: { number } } = {}
		for name, size in sizes do
			local v = key[name]
			if v then
				local filled = table.create(size, 0)
				for i = 1, size do
					filled[i] = v[i] or 0
				end
				pose[name] = filled
			else
				pose[name] = prev[name]
			end
		end
		prev = pose
		table.insert(out, { t = key.t or 0, e = key.e, pose = pose })
	end
	if #out == 0 then
		out[1] = { t = 0, pose = table.clone(prev) }
	end
	local events = table.clone(motion.Events or {})
	table.sort(events, function(a, b)
		return (a.t or 0) < (b.t or 0)
	end)
	local compiled = {
		Keys = out,
		Events = events,
		Duration = motion.Duration or out[#out].t,
		Loop = motion.Loop == true,
		BlendIn = motion.BlendIn or 0.08,
		BlendOut = motion.BlendOut or 0.16,
		Hold = motion.Hold == true,
	}
	motion._c = compiled
	return compiled
end

local function lerpArray(a: { number }, b: { number }, alpha: number): { number }
	local r = table.create(#a)
	for i = 1, #a do
		r[i] = a[i] + (b[i] - a[i]) * alpha
	end
	return r
end

-- 회전 칸: 관절은 셋 다, Root·W·O 는 4~6번째
local ANGLE_FROM: { [string]: number } = {}
for _, name in MotionMath.JOINTS do
	ANGLE_FROM[name] = 1
end
for _, name in MotionMath.SIX do
	ANGLE_FROM[name] = 4
end

--[[
	두 자세 섞기(w=0 이면 a, 1 이면 b).
	섞기(모션 사이 넘어가기)에서는 회전을 **가까운 쪽으로** 돈다 — 한 바퀴 돈 회피(Root 회전 372°)가
	대기 자세(12°)로 돌아갈 때 거꾸로 한 바퀴 되감지 않게. 키 사이 보간(Sample)은 적힌 대로 돈다.
]]
local function blendArray(a: { number }, b: { number }, w: number, from: number?): { number }
	local r = table.create(#a)
	for i = 1, #a do
		local d = b[i] - a[i]
		if from and i >= from then
			d = (d + 180) % 360 - 180
		end
		r[i] = a[i] + d * w
	end
	return r
end

-- 시각 t 의 자세. 되풀이 모션은 t 를 길이로 감는다.
function MotionMath.Sample(compiled: any, t: number): Pose
	local keys = compiled.Keys
	if compiled.Loop and compiled.Duration > 0 then
		t = t % compiled.Duration
	end
	if t <= keys[1].t then
		return keys[1].pose
	end
	for i = 2, #keys do
		local b = keys[i]
		if t <= b.t then
			local a = keys[i - 1]
			local span = math.max(1e-4, b.t - a.t)
			local alpha = curve(b.e)((t - a.t) / span)
			local pose = {}
			for name, va in a.pose do
				pose[name] = lerpArray(va, b.pose[name], alpha)
			end
			return pose
		end
	end
	-- 되풀이면 마지막 키에서 첫 키로 이어서 감는다(한 바퀴 돌린 값은 되감지 않게 가까운 쪽으로)
	local last = keys[#keys]
	if compiled.Loop and #keys > 1 then
		local span = math.max(1e-4, compiled.Duration - last.t)
		local alpha = curve(keys[1].e)((t - last.t) / span)
		local pose = {}
		for name, va in last.pose do
			pose[name] = blendArray(va, keys[1].pose[name], alpha, ANGLE_FROM[name])
		end
		return pose
	end
	return last.pose
end

--=== 쿼터니언 채널(편집기로 고친 모션) ===--
--[[
	스튜디오 애니메이션 편집기로 고친 모션(MotionImport)은 각도 대신 **쿼터니언**으로 적는다 — 편집기는 회전을 쿼터니언으로
	잇는데 각도로 옮기면 팔을 수평(90°)으로 든 근처(짐벌)에서 값이 튀기 때문이다. 채널 이름 뒤에 Q:
	  관절(Torso 빼고) {qx, qy, qz, qw}          (캐릭터 공간 회전 — 각도 채널과 같은 뜻)
	  RootQ           {x, y, z, qx, qy, qz, qw}   (몸 전체 자리·회전)
	  WQ · OQ         {x, y, z, qx, qy, qz, qw}   (무기 모터 Transform 그대로: 자리 = 돌린 뒤가 아니라 모터 공간)
	키 사이는 성분별로 섞고(촘촘한 키라 nlerp 로 충분) 쓸 때 정규화한다. 각도 채널과 섞을 때는 각도 쪽을 쿼터니언으로 바꾼다.
]]
MotionMath.Q_OF = {
	Root = "RootQ",
	Torso = "TorsoQ",
	Head = "HeadQ",
	RArm = "RArmQ",
	LArm = "LArmQ",
	RLeg = "RLegQ",
	LLeg = "LLegQ",
	W = "WQ",
	O = "OQ",
}

local function qmul(a: { number }, b: { number }): { number }
	local ax, ay, az, aw = a[1], a[2], a[3], a[4]
	local bx, by, bz, bw = b[1], b[2], b[3], b[4]
	return {
		aw * bx + ax * bw + ay * bz - az * by,
		aw * by - ax * bz + ay * bw + az * bx,
		aw * bz + ax * by - ay * bx + az * bw,
		aw * bw - ax * bx - ay * by - az * bz,
	}
end

local function qaxis(i: number, deg: number): { number }
	local h = deg * math.pi / 360
	local q = { 0, 0, 0, math.cos(h) }
	q[i] = math.sin(h)
	return q
end

-- 도 세 개 → 쿼터니언. order "YXZ" = CFrame.fromOrientation(관절·Root), "XYZ" = CFrame.Angles(무기)
function MotionMath.EulerQuat(x: number, y: number, z: number, order: string): { number }
	if order == "XYZ" then
		return qmul(qmul(qaxis(1, x), qaxis(2, y)), qaxis(3, z))
	end
	return qmul(qmul(qaxis(2, y), qaxis(1, x)), qaxis(3, z))
end

-- 쿼터니언으로 벡터 돌리기
local function qrot(q: { number }, v: { number }): { number }
	local r = qmul(qmul(q, { v[1], v[2], v[3], 0 }), { -q[1], -q[2], -q[3], q[4] })
	return { r[1], r[2], r[3] }
end

-- 각도 채널 값 → 같은 뜻의 쿼터니언 채널 값
function MotionMath.ToQ(name: string, v: { number }): { number }
	if name == "W" or name == "O" then
		local q = MotionMath.EulerQuat(v[4], v[5], v[6], "XYZ")
		local p = qrot(q, { v[1], v[2], v[3] })
		return { p[1], p[2], p[3], q[1], q[2], q[3], q[4] }
	elseif name == "Root" then
		local q = MotionMath.EulerQuat(v[4], v[5], v[6], "YXZ")
		return { v[1], v[2], v[3], q[1], q[2], q[3], q[4] }
	end
	return MotionMath.EulerQuat(v[1], v[2], v[3], "YXZ")
end

-- 쿼터니언 섞기(짧은 쪽으로). from = 쿼터니언이 시작하는 칸(관절 1, Root·W·O 4)
local function blendQuat(a: { number }, b: { number }, w: number, from: number): { number }
	local dot = 0
	for i = from, from + 3 do
		dot += a[i] * b[i]
	end
	local sign = if dot < 0 then -1 else 1
	local r = table.create(#a)
	for i = 1, #a do
		local bi = if i >= from then b[i] * sign else b[i]
		r[i] = a[i] + (bi - a[i]) * w
	end
	return r
end

function MotionMath.Blend(a: Pose, b: Pose, w: number): Pose
	if w <= 0 then
		return a
	elseif w >= 1 then
		return b
	end
	local pose = {}
	-- 한쪽이라도 쿼터니언이면 그 관절은 쿼터니언으로 섞는다
	local quat: { [string]: boolean } = {}
	for name in a do
		if string.sub(name, -1) == "Q" then
			quat[string.sub(name, 1, -2)] = true
		end
	end
	for name in b do
		if string.sub(name, -1) == "Q" then
			quat[string.sub(name, 1, -2)] = true
		end
	end
	for base in quat do
		local qa = a[base .. "Q"] or (a[base] and MotionMath.ToQ(base, a[base]))
		local qb = b[base .. "Q"] or (b[base] and MotionMath.ToQ(base, b[base]))
		if qa and qb then
			pose[base .. "Q"] = blendQuat(qa, qb, w, if #qa == 7 then 4 else 1)
		else
			pose[base .. "Q"] = qa or qb
		end
	end
	for name, va in a do
		if pose[name] ~= nil or quat[name] then
			continue
		end
		local vb = b[name]
		pose[name] = if vb then blendArray(va, vb, w, ANGLE_FROM[name]) else va
	end
	-- a 에 없는 채널은 0 에서 섞는다
	for name, vb in b do
		if a[name] == nil and pose[name] == nil and not quat[name] then
			pose[name] = lerpArray(table.create(#vb, 0), vb, w)
		end
	end
	return pose
end

-- 빈 자세(모든 관절 0)
function MotionMath.Neutral(): Pose
	local pose = {}
	for _, name in MotionMath.JOINTS do
		pose[name] = ZERO3
	end
	for _, name in MotionMath.SIX do
		pose[name] = ZERO6
	end
	return pose
end

return MotionMath
