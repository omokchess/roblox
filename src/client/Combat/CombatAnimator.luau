--!strict
--[[
	CombatAnimator — 전투 모션 **재생기**. (2026-09-28)

	두 층:
	  바탕(Base)  대기 자세처럼 되풀이하는 모션. 바꿀 때 0.25초 동안 섞어 넘어간다.
	  동작(Action) 스킬·피격·회피처럼 한 번 하는 모션. 들어올 때 BlendIn, 끝나면 BlendOut 동안 바탕으로 돌아간다.
	               Hold 모션(들려 있음 등)은 끝 자세를 붙들고 `Release()` 전까지 안 돌아간다.
	  버릇(Fidget) 대기 중 가끔 하는 작은 동작(깃 다듬기 …). 바탕 위에 **키에 적힌 관절만** 얹어 나머지는 계속
	               숨 쉬고, IsBusy 에 안 잡혀 전투 흐름을 막지 않는다. 동작이 들어오면 바로 사라진다.

	시간은 밖에서 `Update(dt)` 로 밀어 준다 — 타격 정지(히트스톱)처럼 연출 쪽에서 시간을 멈추려면
	dt 를 0 으로 넘기면 된다(CombatDirector 가 한다).

	모션의 Events 는 재생 시각을 지날 때 `onEvent(ev)` 로 알린다. 무엇을 할지는 부른 쪽이 정한다
	(타격 판정 표시·이펙트·화면 흔들림 …).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MotionMath = require(ReplicatedStorage.Shared.Combat.MotionMath)

local CombatAnimator = {}
CombatAnimator.__index = CombatAnimator

export type PlayOptions = {
	Speed: number?,
	OnEvent: ((ev: any) -> ())?,
	OnDone: (() -> ())?,
}

function CombatAnimator.new(rig: any)
	local self = setmetatable({}, CombatAnimator)
	self.Rig = rig
	self.base = nil :: any
	self.baseT = 0
	self.baseFrom = nil :: MotionMath.Pose?
	self.baseFade = 0
	self.action = nil :: any
	self.fidget = nil :: any
	self.lastPose = MotionMath.Neutral()
	return self
end

function CombatAnimator:SetBase(motion: any)
	local compiled = MotionMath.Compile(motion)
	if self.base == compiled then
		return
	end
	self.baseFrom = self.lastPose
	self.baseFade = 0
	self.base = compiled
	self.baseT = 0
end

--[[
	한 번 하는 모션. 이미 하던 동작이 있으면 지금 보이는 자세에서 새 모션으로 넘어간다.
	돌려주는 표로 멈추거나(Stop) 끝났는지(Done) 본다.
]]
function CombatAnimator:Play(motion: any, options: PlayOptions?)
	local opts = options or {}
	local compiled = MotionMath.Compile(motion)
	local previous = self.action
	if previous and not previous.Done then
		previous.Done = true
		if previous.OnDone then
			task.spawn(previous.OnDone)
		end
	end
	local handle = {
		Motion = compiled,
		T = 0,
		Speed = opts.Speed or 1,
		OnEvent = opts.OnEvent,
		OnDone = opts.OnDone,
		From = self.lastPose,
		EventIndex = 1,
		Done = false,
		Releasing = false,
		ReleaseT = 0,
	}
	function handle.Stop()
		handle.Releasing = true
	end
	self.action = handle
	return handle
end

-- 대기 버릇을 한 번 한다(동작 중이거나 이미 하고 있으면 건너뛴다)
function CombatAnimator:Fidget(motion: any)
	if self.fidget or (self.action and not self.action.Done) then
		return
	end
	local only = {}
	for _, key in motion.Keys or {} do
		for name, v in key do
			if type(v) == "table" then
				only[name] = true
			end
		end
	end
	self.fidget = { Motion = MotionMath.Compile(motion), T = 0, Only = only }
end

-- 붙든(Hold) 동작을 풀고 바탕으로 돌아간다
function CombatAnimator:Release()
	if self.action then
		self.action.Releasing = true
	end
end

function CombatAnimator:IsBusy(): boolean
	return self.action ~= nil and not self.action.Done
end

function CombatAnimator:Update(dt: number)
	-- 바탕
	local basePose = MotionMath.Neutral()
	if self.base then
		self.baseT += dt
		basePose = MotionMath.Sample(self.base, self.baseT)
		if self.baseFrom then
			self.baseFade += dt / 0.25
			if self.baseFade >= 1 then
				self.baseFrom = nil
			else
				basePose = MotionMath.Blend(self.baseFrom, basePose, self.baseFade)
			end
		end
	end

	-- 버릇: 바탕 위에 적힌 관절만 덮는다
	local fidget = self.fidget
	if fidget and self.action then
		self.fidget = nil
	elseif fidget then
		fidget.T += dt
		local m = fidget.Motion
		local fp = MotionMath.Sample(m, math.min(fidget.T, m.Duration))
		local wIn = if m.BlendIn > 0 then math.min(1, fidget.T / m.BlendIn) else 1
		local wOut = if fidget.T <= m.Duration then 0 elseif m.BlendOut > 0 then math.min(1, (fidget.T - m.Duration) / m.BlendOut) else 1
		local target = table.clone(basePose)
		for name in fidget.Only do
			target[name] = fp[name] or target[name]
		end
		basePose = MotionMath.Blend(basePose, target, wIn * (1 - wOut))
		if wOut >= 1 then
			self.fidget = nil
		end
	end

	local pose = basePose
	local action = self.action
	if action and not action.Done then
		local motion = action.Motion
		action.T += dt * action.Speed
		-- 사건
		local events = motion.Events
		while action.EventIndex <= #events and events[action.EventIndex].t <= action.T do
			local ev = events[action.EventIndex]
			action.EventIndex += 1
			if action.OnEvent then
				action.OnEvent(ev)
			end
		end
		local t = math.min(action.T, motion.Duration)
		local actionPose = MotionMath.Sample(motion, t)
		-- 들어오기
		local wIn = if motion.BlendIn > 0 then math.min(1, action.T / motion.BlendIn) else 1
		local mixed = MotionMath.Blend(action.From, actionPose, wIn)
		-- 나가기
		local finished = action.T >= motion.Duration and not motion.Loop
		if (finished and not motion.Hold) or action.Releasing then
			action.ReleaseT += if action.Releasing and not finished then dt else dt * action.Speed
			local wOut = if motion.BlendOut > 0 then math.min(1, action.ReleaseT / motion.BlendOut) else 1
			mixed = MotionMath.Blend(mixed, basePose, wOut)
			if wOut >= 1 then
				action.Done = true
				self.action = nil
				if action.OnDone then
					task.spawn(action.OnDone)
				end
			end
		end
		pose = mixed
	end
	self.lastPose = pose
	self.Rig:Apply(pose)
end

return CombatAnimator
