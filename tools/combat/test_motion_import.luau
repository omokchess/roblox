--[[
	test_motion_import.luau — 모션 → KeyframeSequence → 모션 되돌리기 점검(2026-09-29). Shared.Combat.MotionImport.
	  lune run tools/combat/test_motion_import.luau
	직업 모션 전부를 표준 R6 관절 Transform 으로 바꿔(CombatRig:Apply 와 같은 계산) 키프레임을 만들고, 가져오기로
	되돌린 모션의 관절 자세가 키 시각마다 원래와 같은지(0.5° · 0.02 스터드 안) 본다. 사건도 그대로 돌아와야 한다.
]]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Instance, CFrame, Vector3, Enum = roblox.Instance, roblox.CFrame, roblox.Vector3, roblox.Enum

local cache = {}
local function load(path: string)
	if cache[path] then
		return cache[path]
	end
	local dir = string.match(path, "^(.*)/[^/]+$")
	local function node(p)
		return setmetatable({ __path = p }, {
			__index = function(_, key)
				if key == "Parent" then
					return node(string.match(p, "^(.*)/[^/]+$") or p)
				end
				return node(p .. "/" .. key)
			end,
		})
	end
	local env = setmetatable({
		script = node(path:gsub("%.luau$", "")),
		require = function(target)
			local p = rawget(target, "__path")
			return load(p .. ".luau")
		end,
		CFrame = CFrame,
		Vector3 = Vector3,
		Enum = Enum,
	}, { __index = _G })
	local fn = luau.load(fs.readFile(path), { debugName = path, environment = env })
	local result = fn()
	cache[path] = result
	local _ = dir
	return result
end

local MotionMath = load("src/shared/Combat/MotionMath.luau")
local MotionImport = load("src/shared/Combat/MotionImport.luau")

local RAD = math.pi / 180
local function rot(v, o)
	local i = o or 0
	return CFrame.fromOrientation((v[i + 1] or 0) * RAD, (v[i + 2] or 0) * RAD, (v[i + 3] or 0) * RAD)
end
local CONJ = {
	Torso = MotionImport.CHANNELS.Torso.C0,
	Head = MotionImport.CHANNELS.Head.C0,
	["Right Arm"] = MotionImport.CHANNELS["Right Arm"].C0,
	["Left Arm"] = MotionImport.CHANNELS["Left Arm"].C0,
	["Right Leg"] = MotionImport.CHANNELS["Right Leg"].C0,
	["Left Leg"] = MotionImport.CHANNELS["Left Leg"].C0,
}
local CH = { Head = "Head", ["Right Arm"] = "RArm", ["Left Arm"] = "LArm", ["Right Leg"] = "RLeg", ["Left Leg"] = "LLeg" }
local WAIST, WAIST_BACK = CFrame.new(0, -1, 0), CFrame.new(0, 1, 0)

local function quatCf(q)
	local o = if #q == 7 then 3 else 0
	local x, y, z, w = q[o + 1], q[o + 2], q[o + 3], q[o + 4]
	local n = math.sqrt(x * x + y * y + z * z + w * w)
	x, y, z, w = x / n, y / n, z / n, w / n
	return if o == 3 then CFrame.new(q[1], q[2], q[3], x, y, z, w) else CFrame.new(0, 0, 0, x, y, z, w)
end

-- CombatRig:Apply(R6) 와 같은 계산: 포즈 이름 → Transform (쿼터니언 채널이 있으면 그것 먼저)
local function transforms(pose)
	local root = pose.Root or { 0, 0, 0, 0, 0, 0 }
	local rootCf = if pose.RootQ then quatCf(pose.RootQ) else CFrame.new(root[1], root[2], root[3]) * rot(root, 3)
	local torsoRot = rot(pose.Torso or { 0, 0, 0 })
	local out = {}
	for name, conj in CONJ do
		local r
		if name == "Torso" then
			r = rootCf * WAIST * torsoRot * WAIST_BACK
		else
			local q = pose[CH[name] .. "Q"]
			r = if q then quatCf(q) else rot(pose[CH[name]] or { 0, 0, 0 })
			if name == "Right Leg" or name == "Left Leg" then
				r = torsoRot:Inverse() * r
			end
		end
		out[name] = conj:Inverse() * r * conj
	end
	for _, slot in { "W", "O" } do
		local q, w = pose[slot .. "Q"], pose[slot]
		if q then
			out["Grip" .. slot] = quatCf(q)
		elseif w then
			out["Grip" .. slot] = CFrame.Angles(w[4] * RAD, w[5] * RAD, w[6] * RAD) * CFrame.new(w[1], w[2], w[3])
		end
	end
	return out
end

local PARENT = { Torso = "HumanoidRootPart", Head = "Torso", ["Right Arm"] = "Torso", ["Left Arm"] = "Torso", ["Right Leg"] = "Torso", ["Left Leg"] = "Torso", GripW = "Right Arm", GripO = "Left Arm" }

local function toSequence(motion)
	local c = MotionMath.Compile(motion)
	local seq = Instance.new("KeyframeSequence")
	seq.Loop = c.Loop
	for _, k in MotionImport.Frames(c) do
		local kf = Instance.new("Keyframe")
		kf.Time = k.t
		local style, dir = MotionImport.PoseEase(k.nextE or "linear")
		local made = {}
		local hrp = Instance.new("Pose")
		hrp.Name = "HumanoidRootPart"
		hrp.Weight = 0
		hrp.Parent = kf
		made.HumanoidRootPart = hrp
		local tf = transforms(k.pose)
		for _, name in { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg", "GripW", "GripO" } do
			if tf[name] then
				local p = Instance.new("Pose")
				p.Name = name
				p.CFrame = tf[name]
				p.EasingStyle, p.EasingDirection = style, dir
				p.Weight = 1
				p.Parent = made[PARENT[name]]
				made[name] = p
			end
		end
		kf.Parent = seq
	end
	for _, ev in c.Events do
		local kf = Instance.new("Keyframe")
		kf.Time = ev.t
		kf.Parent = seq
		local m = Instance.new("KeyframeMarker")
		m.Name = tostring(ev.k)
		m.Value = MotionImport.EncodeEvent(ev)
		m.Parent = kf
	end
	return seq, c
end

local function angleBetween(a, b)
	local d = a.Rotation:Inverse() * b.Rotation
	local _, angle = d:ToAxisAngle()
	return math.abs(angle) / RAD
end

local checked, worst, jumpWorst = 0, 0, 0
for _, file in fs.readDir("src/shared/Combat/Motions") do
	if file == "Slime.luau" or file == "Debug.luau" then
		continue
	end
	local set = load("src/shared/Combat/Motions/" .. file)
	local list = {}
	for name, m in set do
		if type(m) == "table" and m.Keys then
			list[name] = m
		end
	end
	for id, m in set.Skills or {} do
		list["Skill_" .. id] = m
	end
	for name, motion in list do
		local seq, c = toSequence(motion)
		local back = MotionImport.FromSequence(seq, motion)
		local cb = MotionMath.Compile(back)
		assert(#cb.Events == #c.Events, file .. " " .. name .. " 사건 수")
		-- 같은 시각 사건은 순서가 바뀔 수 있어 (시각·이름·값)으로 줄 세워 맞춘다
		local function ordered(list)
			local copy = table.clone(list)
			table.sort(copy, function(a, b)
				local ka = string.format("%.3f|%s|%s", a.t, tostring(a.k), MotionImport.EncodeEvent(a))
				local kb = string.format("%.3f|%s|%s", b.t, tostring(b.k), MotionImport.EncodeEvent(b))
				return ka < kb
			end)
			return copy
		end
		local want, have = ordered(c.Events), ordered(cb.Events)
		for i, ev in want do
			local got = have[i]
			assert(got.k == ev.k and math.abs(got.t - ev.t) < 1e-4, file .. " " .. name .. " 사건 " .. tostring(ev.k))
			for key, v in ev do
				assert(key == "t" or got[key] == v, string.format("%s %s 사건 값 %s: %s ~= %s", file, name, key, tostring(got[key]), tostring(v)))
			end
		end
		for _, k in c.Keys do
			local a = transforms(MotionMath.Sample(c, k.t))
			local b = transforms(MotionMath.Sample(cb, k.t))
			for joint, cf in a do
				local other = b[joint]
				assert(other, file .. " " .. name .. " 관절 빠짐 " .. joint)
				local ang = angleBetween(cf, other)
				-- 몸통(RootJoint)은 자리도 본다
				local dist = (cf.Position - other.Position).Magnitude
				worst = math.max(worst, ang)
				assert(ang < 0.5 and dist < 0.02, string.format("%s %s t=%.2f %s 각 %.2f° 거리 %.3f", file, name, k.t, joint, ang, dist))
			end
			checked += 1
		end
		-- 촘촘한 키 사이(각도 보간)가 회전 보간과 크게 다르지 않아야 한다 — 같은 회전의 다른 각도로 튀면 여기서 걸린다
		for i = 2, #cb.Keys do
			local ka, kb = cb.Keys[i - 1], cb.Keys[i]
			local mid = (ka.t + kb.t) / 2
			local a = transforms(MotionMath.Sample(cb, ka.t))
			local b = transforms(MotionMath.Sample(cb, kb.t))
			local m = transforms(MotionMath.Sample(cb, mid))
			for joint, cf in m do
				local slerp = a[joint]:Lerp(b[joint], 0.5)
				local ang = angleBetween(cf, slerp)
				jumpWorst = math.max(jumpWorst, ang)
				assert(ang < 6, string.format("%s %s t=%.3f %s 키 사이 튐 %.1f°", file, name, mid, joint, ang))
			end
		end
		-- 각도 자세(코드 모션) ↔ 쿼터니언 자세(고친 모션) 섞기: 같은 자세끼리 섞으면 거의 그대로여야 한다.
		-- 코드 모션은 허리에서 굽고(Torso) 고친 모션은 몸 전체(Root)라, 섞는 잠깐(0.1초 안팎) 몸통 기울기만큼 어긋날 수 있다 — 뒤집힘만 막는다
		for _, k in c.Keys do
			local qb = MotionMath.Sample(cb, k.t)
			for _, w in { 0.25, 0.5, 0.75 } do
				local mixed = transforms(MotionMath.Blend(k.pose, qb, w))
				local want = transforms(k.pose)
				for joint, cf in want do
					local ang = angleBetween(cf, mixed[joint])
					assert(ang < 12 and (cf.Position - mixed[joint].Position).Magnitude < 0.6, string.format("%s %s 섞기 %s %.2f°", file, name, joint, ang))
				end
			end
		end
		local sig = MotionImport.Signature(seq)
		assert(sig == MotionImport.Signature(seq), "지문이 한결같아야")
	end
end
print(string.format("모션 되돌리기 점검 통과: 키 %d개, 키 어긋남 최대 %.3f°, 키 사이 최대 %.2f°", checked, worst, jumpWorst))
