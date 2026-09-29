--!strict
--[[
	CombatDirector — 전투 **연출 지휘**. (2026-09-28)

	누가 어디 서 있고(배우), 지금 무슨 모션을 하며, 모션의 사건(Hit·Dash·Fx …)이 오면 무엇을
	보여 줄지를 여기서 정한다. 판정은 하지 않는다 — 피해 숫자·죽음은 서버 결과를 받아 보여 준다.

	배우(actor)
	  Humanoid  아바타(R6). CombatRig + CombatWeapons. 자리 = HumanoidRootPart
	  Slime     Slime 모델. 자리 = 바닥 가운데 Pivot
	  Boss      보스 부위(DebugBoss). 자리 = 부위가 차지한 칸들 가운데 바닥. 움직이지 않는다
	자리는 연출이 매 프레임 쓴다: 돌진(Dash) 중이면 그 길을, 들려 있으면 커서를, 아니면 집(Home)으로 미끄러진다.

	시간: 매 프레임 dt 를 받아 모든 재생기·이펙트에 나눠 준다. Stop 사건(타격 정지) 동안은 0 을 준다 —
	그래서 모션·돌진·이펙트가 함께 멈췄다 다시 간다.

	사건(모션 Events 의 k)
	  Hit    { i = 몇 번째 타격, fx = 이펙트 이름 }  대상 반응·번쩍·피해 숫자
	  Dash   { to = "Target"|"Home", gap = 대상 앞 거리(음수 = 뚫고 지나감), d = 걸리는 초 }
	  Fx     { n = 이펙트 이름 }                     Fx/<직업>.luau 의 함수
	  Trail  { on = true/false, slot = "W"|"O"|nil } 무기 궤적
	  Shake  { a = 세기, d = 초 }
	  Stop   { d = 초 }                              타격 정지
	  Orbs   { mode = "Orbit"|"Gather"|"Shield"|"Spread"|"Crown" }
	  Hide   { slot = "W", on = true/false }         손에 든 것 숨기기(던진 병)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared.Combat
local CombatMotions = require(Shared.CombatMotions)
local SlimeMotions = require(Shared.Motions.Slime)
local DebugMotions = require(Shared.Motions.Debug)

local CombatRig = require(script.Parent.CombatRig)
local CombatAnimator = require(script.Parent.CombatAnimator)
local CombatWeapons = require(script.Parent.CombatWeapons)
local CombatVfx = require(script.Parent.CombatVfx)
local Slime = require(script.Parent.Slime)
local DebugBoss = require(script.Parent.DebugBoss)
local FxCommon = require(script.Parent.Fx.Common)

local FX: { [string]: { [string]: any } } = {}
for _, m in script.Parent.Fx:GetChildren() do
	if m:IsA("ModuleScript") and m.Name ~= "Common" then
		FX[m.Name] = require(m) :: any
	end
end

local CombatDirector = {}
CombatDirector.__index = CombatDirector

type Actor = {
	Id: string,
	Kind: "Humanoid" | "Slime" | "Boss",
	-- 슬라임·보스 부위의 모션 묶음(Idle·Windup·Hit·Death·Skills). 사람은 CombatMotions 에서 찾는다
	Motions: any?,
	Model: Model,
	Rig: any,
	Animator: any,
	Weapons: any?,
	ClassId: string,
	WeaponType: string?,
	Home: CFrame,
	Pos: CFrame,
	Chest: number,
	Ground: number,
	Dash: any?,
	Held: boolean,
	HeldAt: Vector3?,
	PendingDeath: boolean,
	Dying: boolean,
	Idle: any,
}

-- 관전용 연출기(Quiet)는 화면을 흔들지 않고, 치울 때 남(내 전투)의 효과까지 지우지 않는다
local QuietVfx = setmetatable({ Shake = function() end }, { __index = CombatVfx })

function CombatDirector.new(opts: { Quiet: boolean? }?)
	local self = setmetatable({}, CombatDirector)
	self.Quiet = opts ~= nil and opts.Quiet == true
	self.Actors = {} :: { [string]: Actor }
	self.Plays = {} :: { any }
	self.StopLeft = 0
	-- 안전장치로 강제로 끝낸 재생 수(0 이어야 정상 — 점검 도구가 본다)
	self.ForcedDone = 0
	self.CameraBase = nil :: CFrame?
	-- PreSimulation: 애니메이션 단계(Animator 가 관절 Transform 을 다시 쓴다) 다음, 물리 단계 전.
	-- RenderStepped 에서 넣으면 Animator 가 덮어써 몸이 차렷 그대로 보였다.
	self.Connection = RunService.PreSimulation:Connect(function(dt)
		self:_step(dt)
	end)
	return self
end

--=== 배우 ===--

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-3 then f.Unit else Vector3.new(0, 0, -1)
end

function CombatDirector:AddHumanoid(id: string, character: Model, classId: string, home: CFrame, weaponId: string?)
	self:Remove(id)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart
	local rig = CombatRig.new(character)
	rig:Take()
	local weapons = CombatWeapons.Attach(character, rig, weaponId, classId)
	local animator = CombatAnimator.new(rig)
	local idle = CombatMotions.Get(classId, "Idle", weapons.Type)
	animator:SetBase(idle)
	local actor: Actor = {
		Id = id,
		Kind = "Humanoid",
		Model = character,
		Rig = rig,
		Animator = animator,
		Weapons = weapons,
		ClassId = classId,
		WeaponType = weapons.Type,
		Home = home,
		Pos = if root then root.CFrame else home,
		Chest = 0.6,
		Ground = -3,
		Dash = nil,
		Held = false,
		HeldAt = nil,
		PendingDeath = false,
		Dying = false,
		Idle = idle,
	}
	self.Actors[id] = actor
	return actor
end

function CombatDirector:AddSlime(id: string, parent: Instance, home: CFrame, color: Color3?)
	self:Remove(id)
	local model = Slime.Build("Slime_" .. id, color)
	model:PivotTo(home)
	model.Parent = parent
	local rig = Slime.new(model)
	local animator = CombatAnimator.new(rig)
	animator:SetBase(SlimeMotions.Idle)
	-- 여러 마리가 똑같이 튀지 않게 대기 시작점을 흩는다
	animator.baseT = math.random() * 1.7
	local actor: Actor = {
		Id = id,
		Kind = "Slime",
		Model = model,
		Rig = rig,
		Animator = animator,
		Weapons = nil,
		ClassId = "Slime",
		WeaponType = nil,
		Home = home,
		Pos = home,
		Chest = 1.4,
		Ground = 0,
		Dash = nil,
		Held = false,
		HeldAt = nil,
		PendingDeath = false,
		Dying = false,
		Idle = SlimeMotions.Idle,
		Motions = SlimeMotions,
	}
	self.Actors[id] = actor
	return actor
end

-- 보스 부위(디버그). key = 부위 이름(Head·DeleteArm·PatchArm·Core). 이펙트는 Fx/Debug
local BOSS_CHEST = { Head = 5.6, DeleteArm = 3.2, PatchArm = 2.8, Core = 7.5 }

function CombatDirector:AddBossPart(id: string, key: string, parent: Instance, home: CFrame)
	self:Remove(id)
	local rig = DebugBoss.new(key, home)
	rig.Model.Parent = parent
	local motions = (DebugMotions :: any)[key] or DebugMotions.Core
	local animator = CombatAnimator.new(rig)
	animator:SetBase(motions.Idle)
	animator.baseT = math.random() * 1.5
	local actor: Actor = {
		Id = id,
		Kind = "Boss",
		Model = rig.Model,
		Rig = rig,
		Animator = animator,
		Weapons = nil,
		ClassId = "Debug",
		WeaponType = nil,
		Home = home,
		Pos = home,
		Chest = BOSS_CHEST[key] or 4,
		Ground = 0,
		Dash = nil,
		Held = false,
		HeldAt = nil,
		PendingDeath = false,
		Dying = false,
		Idle = motions.Idle,
		Motions = motions,
	}
	self.Actors[id] = actor
	return actor
end

-- 적 하나: 보스 부위면 부위 몸, 아니면 슬라임
function CombatDirector:AddEnemy(id: string, part: string?, parent: Instance, home: CFrame)
	if part then
		return self:AddBossPart(id, part, parent, home)
	end
	return self:AddSlime(id, parent, home)
end

function CombatDirector:Has(id: string): boolean
	return self.Actors[id] ~= nil
end

function CombatDirector:Model(id: string): Model?
	local a = self.Actors[id]
	return a and a.Model
end

function CombatDirector:SetHome(id: string, home: CFrame, instant: boolean?)
	local a = self.Actors[id]
	if not a then
		return
	end
	local moved = (a.Home.Position - home.Position).Magnitude
	a.Home = home
	if instant then
		a.Pos = home
	elseif a.Kind == "Slime" and moved > 1 and not a.Dash and not a.Dying then
		-- 슬라임은 미끄러지지 않고 통 튀어서 옮긴다
		a.Dash = { From = a.Pos, To = home, T = 0, D = 0.35, Ease = "sineInOut", Arc = 1.8 }
		local hop = SlimeMotions.Hit
		if hop and not a.Animator:IsBusy() then
			a.Animator:Play(hop, { Speed = 1.4 })
		end
	end
end

function CombatDirector:Remove(id: string)
	local a = self.Actors[id]
	if not a then
		return
	end
	self.Actors[id] = nil
	-- 관절을 먼저 되돌리고 무기를 치운다(무기 모터가 먼저 사라지면 되돌리다 오류)
	if a.Kind == "Humanoid" then
		a.Rig:Release()
	end
	if a.Weapons then
		a.Weapons:Destroy()
	end
	if a.Kind ~= "Humanoid" then
		a.Model:Destroy()
	end
end

function CombatDirector:Destroy()
	for id in self.Actors do
		self:Remove(id)
	end
	self.Connection:Disconnect()
	if not self.Quiet then
		CombatVfx.Clear()
	end
end

function CombatDirector:SetCamera(cf: CFrame)
	self.CameraBase = cf
end

--=== 모션 고르기 ===--

function CombatDirector:_motion(a: Actor, name: string): any
	if a.Kind ~= "Humanoid" then
		return (a.Motions or SlimeMotions)[name]
	end
	return CombatMotions.Get(a.ClassId, name, a.WeaponType)
end

function CombatDirector:_skillMotion(a: Actor, skillId: string): any
	if a.Kind ~= "Humanoid" then
		local skills = (a.Motions or SlimeMotions).Skills
		return skills[skillId] or SlimeMotions.Skills[skillId] or select(2, next(skills))
	end
	return CombatMotions.Skill(a.ClassId, skillId)
end

--=== 이펙트 ===--

function CombatDirector:_targetPoint(id: string): Vector3?
	local t = self.Actors[id]
	if not t then
		return nil
	end
	return t.Pos.Position + Vector3.new(0, t.Chest, 0)
end

function CombatDirector:_ctx(a: Actor, targets: { string }?)
	local points = {}
	for _, id in targets or {} do
		local p = self:_targetPoint(id)
		if p then
			table.insert(points, p)
		end
	end
	local forward = flat(a.Home.LookVector)
	local weapons = a.Weapons
	local ctx = {
		Vfx = if self.Quiet then QuietVfx else CombatVfx,
		Actor = a,
		Root = a.Pos,
		Forward = forward,
		Weapons = weapons,
		Ground = a.Pos.Y + a.Ground,
		Targets = points,
		Target = points[1] or (a.Pos.Position + forward * 6),
	}
	function ctx.Tip(slot: string?): Vector3?
		return if weapons then weapons:Socket(slot or "W", "Tip") else nil
	end
	function ctx.Base(slot: string?): Vector3?
		return if weapons then weapons:Socket(slot or "W", "Base") else nil
	end
	function ctx.Hand(side: string?): Vector3
		local arm = a.Model:FindFirstChild(if side == "L" then "Left Arm" else "Right Arm") :: BasePart?
		return if arm then (arm.CFrame * CFrame.new(0, -1, 0)).Position else a.Pos.Position
	end
	return ctx
end

function CombatDirector:_fx(a: Actor, name: string?, ctx: any, ev: any, at: Vector3?): boolean
	if not name then
		return false
	end
	local set = FX[a.ClassId]
	local fn = set and set[name]
	if fn then
		local ok, err = pcall(fn, ctx, ev, at)
		if not ok then
			warn("[CombatDirector] 이펙트 오류", a.ClassId, name, err)
		end
		return true
	end
	return false
end

--=== 재생 ===--

--[[
	한 배우의 동작 하나를 재생한다. targetsByHit[i] = i번째 Hit 사건이 맞히는 배우 Id 목록.
	돌려주는 play 로 서버 결과를 나중에 붙인다: play:SetResult({ Hits = { { {Id=, Damage=, Killed=} … } … } })
	onHit(i, targets) 는 Hit 사건마다 불린다(대상 반응을 부른 쪽이 정하고 싶을 때).
]]
function CombatDirector:_play(a: Actor, motion: any, targetsByHit: { { string } }?, opts: any?)
	local o = opts or {}
	local play = {
		Actor = a,
		Targets = targetsByHit or {},
		Result = nil :: any,
		Shown = {} :: { [string]: boolean },
		HitsSeen = 0,
		HitCount = 0,
		Done = false,
		OnHit = o.OnHit,
		OnDone = o.OnDone,
		NumberStyle = o.NumberStyle,
		-- 안전장치: 모션 길이 + 2초가 지나도 안 끝나면 끝난 것으로 본다(연출이 멈춰 턴이 막히지 않게)
		Deadline = os.clock() + (motion.Duration or 1) + 2,
	}
	for _, ev in motion.Events or {} do
		if ev.k == "Hit" then
			play.HitCount += 1
		end
	end
	local director = self
	function play.SetResult(_, result: any)
		play.Result = result
		director:_showNumbers(play)
		-- 펄서 자기권 반사: 공격한 쪽 머리 위에 청록 숫자
		if result and (result.Reflect or 0) > 0 then
			local p = director:_targetPoint(a.Id)
			if p then
				CombatVfx.Number(p + Vector3.new(0, 1.6, 0), tostring(result.Reflect), { Color = Color3.fromRGB(120, 230, 255) })
			end
			if result.ReflectKilled then
				director:Kill(a.Id)
			end
		end
	end
	table.insert(self.Plays, play)
	a.Animator:Play(motion, {
		OnEvent = function(ev)
			self:_event(play, ev)
		end,
		OnDone = function()
			play.Done = true
			if play.OnDone then
				play.OnDone()
			end
		end,
	})
	return play
end

-- i 번째 Hit 사건의 대상. 서버 묶음보다 사건이 많으면(찌르기 3연타 = 모양 1개) 마지막 묶음을 쓴다.
local function groupOf(play: any, i: number): number
	local n = #play.Targets
	if n == 0 then
		return 1
	end
	return math.min(i, n)
end

function CombatDirector:_event(play: any, ev: any)
	local a: Actor = play.Actor
	local k = ev.k
	if k == "Hit" then
		play.HitsSeen += 1
		local i = ev.i or play.HitsSeen
		local targets = play.Targets[groupOf(play, i)] or {}
		local ctx = self:_ctx(a, targets)
		if #targets == 0 then
			-- 빈 곳을 쳐도 휘두른 자리에 이펙트는 나온다
			self:_fx(a, ev.fx, ctx, ev, ctx.Target)
		end
		for _, id in targets do
			local p = self:_targetPoint(id)
			if not self:_fx(a, ev.fx, ctx, ev, p) and p then
				FxCommon.Impact(CombatVfx, p, nil, 0.8)
			end
			local t = self.Actors[id]
			if t and play.OnHit == nil then
				self:_react(t, "Hit")
			end
		end
		if play.OnHit then
			play.OnHit(i, targets)
		end
		if not self.Quiet then
			CombatVfx.Shake(0.12, 0.12)
		end
		self:_showNumbers(play)
	elseif k == "Dash" then
		self:_dash(a, play, ev)
	elseif k == "Fx" then
		self:_fx(a, ev.n, self:_ctx(a, play.Targets[1]), ev, nil)
	elseif k == "Trail" then
		if a.Weapons then
			a.Weapons:Trail(ev.slot, ev.on ~= false)
		end
	elseif k == "Shake" then
		if not self.Quiet then
			CombatVfx.Shake(ev.a or 0.3, ev.d or 0.25)
		end
	elseif k == "Stop" then
		self.StopLeft = math.max(self.StopLeft, ev.d or 0.06)
	elseif k == "Orbs" then
		if a.Weapons then
			local aim = nil
			if ev.at == "Target" then
				aim = self:_ctx(a, play.Targets[1]).Target
			end
			a.Weapons:SetOrbMode(ev.mode or "Orbit", aim)
		end
	elseif k == "Hide" then
		if a.Weapons then
			a.Weapons:Hide(ev.slot or "W", ev.on ~= false)
		end
	end
end

-- 대상 반응(맞음·막음·피함). 죽어 가는 중이면 무시.
function CombatDirector:_react(t: Actor, name: string)
	if t.Dying then
		return
	end
	local motion = self:_motion(t, name)
	if motion then
		-- 반응 모션에도 이펙트 사건(패링 불꽃·돌벽 …)이 있어 _play 로 돌린다
		self:_play(t, motion, { {} })
	end
	if name == "Hit" then
		CombatVfx.HitFlash(t.Model)
	end
end

function CombatDirector:_dash(a: Actor, play: any, ev: any)
	local to: CFrame
	if ev.to == "Home" then
		to = a.Home
	else
		local targets = play.Targets[1] or {}
		local t = targets[1] and self.Actors[targets[1]]
		local forward = flat(a.Home.LookVector)
		if t then
			local toward = flat(t.Pos.Position - a.Pos.Position)
			local pos = t.Pos.Position - toward * (ev.gap or 3)
			to = CFrame.lookAt(Vector3.new(pos.X, a.Home.Y, pos.Z), Vector3.new(pos.X, a.Home.Y, pos.Z) + forward)
		else
			to = a.Home + forward * (ev.dist or 6)
		end
	end
	-- arc = 포물선 높이(도약해서 내려찍기)
	a.Dash = { From = a.Pos, To = to, T = 0, D = math.max(0.02, ev.d or 0.15), Ease = ev.e or "quadOut", Arc = ev.arc }
end

--=== 피해 숫자 ===--

local GRADE_TEXT = { Success = "회피!", Partial = "막음", Fail = nil }

function CombatDirector:_showNumbers(play: any)
	local result = play.Result
	if not result or not result.Hits then
		return
	end
	-- 사건 수와 서버 묶음 수가 다르면 묶음 피해를 사건에 나눠 보여 준다
	local perGroup: { [number]: number } = {}
	for i = 1, play.HitCount do
		local g = groupOf(play, i)
		perGroup[g] = (perGroup[g] or 0) + 1
	end
	for i = 1, play.HitsSeen do
		local g = groupOf(play, i)
		local hits = result.Hits[g] or {}
		local share = perGroup[g] or 1
		local nth = 0
		for j = 1, i do
			if groupOf(play, j) == g then
				nth += 1
			end
		end
		for _, h in hits do
			local key = string.format("%d:%s", i, tostring(h.Id))
			if play.Shown[key] then
				continue
			end
			play.Shown[key] = true
			local p = self:_targetPoint(h.Id)
			if p then
				local dmg = math.floor((h.Damage or 0) / share)
				if nth == share then
					dmg = (h.Damage or 0) - dmg * (share - 1)
				end
				local enemy = self.Actors[h.Id] and self.Actors[h.Id].Kind ~= "Humanoid"
				local label = tostring(dmg)
				local color = if enemy then Color3.fromRGB(255, 244, 214) else Color3.fromRGB(255, 90, 80)
				if h.Grade and GRADE_TEXT[h.Grade] and dmg <= 0 then
					label = GRADE_TEXT[h.Grade]
					color = Color3.fromRGB(150, 230, 255)
				elseif h.Grade == "Partial" then
					color = Color3.fromRGB(255, 190, 90)
				end
				CombatVfx.Number(p + Vector3.new(0, 1.6, 0), label, { Color = color, Big = dmg >= 30 })
			end
		end
	end
end

--=== 밖에서 부르는 것 ===--

-- 스킬: 목록 targetsByHit 는 서버의 모양 묶음 순서와 같다
function CombatDirector:PlaySkill(id: string, skillId: string, targetsByHit: { { string } }, onDone: (() -> ())?)
	local a = self.Actors[id]
	if not a then
		return nil
	end
	return self:_play(a, self:_skillMotion(a, skillId), targetsByHit, { OnDone = onDone })
end

-- 적이 공격을 예고하는 동안(회피 QTE 중) 웅크려 떤다
function CombatDirector:Windup(id: string, on: boolean)
	local a = self.Actors[id]
	if not a or a.Kind == "Humanoid" then
		return
	end
	local motions = a.Motions or SlimeMotions
	a.Animator:SetBase(if on then motions.Windup else motions.Idle)
end

--[[
	적 공격: 맞는 순간 대상이 등급대로 반응한다(Success 회피 / Partial 막음 / Fail 맞음).
	패링(Success)이면 공격한 쪽이 튕겨 나간다.
]]
function CombatDirector:PlayEnemyAttack(enemyId: string, skillId: string, targetId: string, grade: string, onDone: (() -> ())?)
	local a = self.Actors[enemyId]
	if not a then
		if onDone then
			onDone()
		end
		return nil
	end
	a.Animator:SetBase(a.Idle)
	local reaction = if grade == "Success" then "Dodge" elseif grade == "Partial" then "Guard" else "Hit"
	local play
	play = self:_play(a, self:_skillMotion(a, skillId), { { targetId } }, {
		OnDone = onDone,
		OnHit = function()
			local t = self.Actors[targetId]
			if t then
				self:_react(t, reaction)
				if grade == "Success" then
					-- 받아넘겼다: 공격자가 움찔
					task.delay(0.05, function()
						if self.Actors[enemyId] then
							CombatVfx.HitFlash(a.Model, { Color = Color3.fromRGB(170, 220, 255) })
						end
					end)
				end
			end
		end,
	})
	return play
end

-- 마우스로 집어 듦
function CombatDirector:Grab(id: string)
	local a = self.Actors[id]
	if not a or a.Held then
		return
	end
	a.Held = true
	a.HeldAt = a.Pos.Position + Vector3.new(0, 2.4, 0)
	if a.Weapons then
		a.Weapons:SetOrbMode("Crown")
	end
	local held = self:_motion(a, "Held")
	if held then
		a.Animator:SetBase(held)
	end
	CombatVfx.Ring(CFrame.new(Vector3.new(a.Pos.X, a.Pos.Y + a.Ground + 0.15, a.Pos.Z)), { R0 = 0.8, R1 = 2.6, Color = Color3.fromRGB(255, 240, 200), Life = 0.3, Width = 0.18, Height = 0.06 })
end

-- 들고 있는 동안 따라갈 자리(칸 위 공중)
function CombatDirector:HoldAt(id: string, position: Vector3)
	local a = self.Actors[id]
	if a and a.Held then
		a.HeldAt = position
	end
end

-- 내려놓음: home 으로 툭 떨어지고 내려놓임 모션
function CombatDirector:Drop(id: string, home: CFrame)
	local a = self.Actors[id]
	if not a or not a.Held then
		return
	end
	a.Held = false
	a.Home = home
	a.Animator:SetBase(a.Idle)
	if a.Weapons then
		a.Weapons:SetOrbMode("Orbit")
	end
	a.Dash = { From = a.Pos, To = home, T = 0, D = 0.08, Ease = "quadIn" }
	local drop = self:_motion(a, "Drop")
	if drop then
		self:_play(a, drop, { {} })
	end
end

function CombatDirector:IsHeld(id: string): boolean
	local a = self.Actors[id]
	return a ~= nil and a.Held
end

-- 서버가 죽었다고 알림: 맞는 연출이 끝난 뒤 쓰러진다
function CombatDirector:Kill(id: string)
	local a = self.Actors[id]
	if a and not a.Dying then
		a.PendingDeath = true
	end
end

-- 누가 아직 이 배우를 때리는 중인가(마지막 Hit 가 안 나왔는가)
function CombatDirector:_involved(id: string): boolean
	for _, play in self.Plays do
		if not play.Done and play.HitsSeen < play.HitCount then
			for _, group in play.Targets do
				for _, t in group do
					if t == id then
						return true
					end
				end
			end
		end
	end
	return false
end

function CombatDirector:IsBusy(): boolean
	for _, play in self.Plays do
		if not play.Done then
			return true
		end
	end
	for _, a in self.Actors do
		if a.Dash or a.Dying or a.PendingDeath then
			return true
		end
	end
	return false
end

function CombatDirector:_die(a: Actor)
	a.Dying = true
	a.PendingDeath = false
	local death = self:_motion(a, "Death")
	local ctx = self:_ctx(a, nil)
	if death then
		a.Animator:Play(death, {
			OnEvent = function(ev)
				if ev.k == "Fx" then
					self:_fx(a, ev.n, ctx, ev, nil)
				end
			end,
		})
	end
	local fade = 0
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt)
		fade += dt
		if a.Kind ~= "Humanoid" and fade > 0.7 then
			a.Rig.Fade = math.clamp((fade - 0.7) / 0.5, 0, 1)
		end
		if fade > 1.3 then
			conn:Disconnect()
			if self.Actors[a.Id] == a then
				self:Remove(a.Id)
			end
		end
	end)
end

--=== 매 프레임 ===--

local EASE = require(Shared.MotionMath).Ease

function CombatDirector:_step(realDt: number)
	local dt = realDt
	if self.StopLeft > 0 then
		self.StopLeft -= realDt
		dt = realDt * 0.03
	end
	for id, a in self.Actors do
		-- 자리
		if a.Dash then
			local d = a.Dash
			d.T += dt
			local alpha = math.clamp(d.T / d.D, 0, 1)
			local e = (EASE[d.Ease] or EASE.quadOut)(alpha)
			a.Pos = d.From:Lerp(d.To, e)
			if d.Arc then
				a.Pos += Vector3.new(0, math.sin(alpha * math.pi) * d.Arc, 0)
			end
			if alpha >= 1 then
				a.Dash = nil
			end
		elseif a.Held and a.HeldAt then
			local goal = CFrame.new(a.HeldAt) * a.Home.Rotation
			local sway = math.sin(os.clock() * 5) * 0.08
			a.Pos = a.Pos:Lerp(goal * CFrame.Angles(0, 0, sway), 1 - math.exp(-realDt * 14))
		elseif not a.Dying then
			a.Pos = a.Pos:Lerp(a.Home, 1 - math.exp(-realDt * 12))
		end
		if a.Kind == "Humanoid" then
			local root = a.Model:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				root.CFrame = a.Pos
			end
		else
			a.Rig.Pivot = a.Pos
		end
		-- 모션
		a.Animator:Update(dt)
		if a.Weapons then
			a.Weapons:Update(dt)
		end
		if a.PendingDeath and not a.Dying and not self:_involved(id) and not a.Animator:IsBusy() then
			self:_die(a)
		end
	end
	local now = os.clock()
	for i = #self.Plays, 1, -1 do
		local play = self.Plays[i]
		if not play.Done and (self.Actors[play.Actor.Id] ~= play.Actor or now > play.Deadline) then
			play.Done = true
			if self.Actors[play.Actor.Id] == play.Actor then
				self.ForcedDone += 1
			end
		end
		if play.Done then
			table.remove(self.Plays, i)
		end
	end
	CombatVfx.Step(dt)
	-- 화면 흔들림
	local camera = workspace.CurrentCamera
	if camera and self.CameraBase and camera.CameraType == Enum.CameraType.Scriptable then
		local amp = CombatVfx.ShakeAmp
		if amp > 0.001 then
			local t = os.clock() * 40
			camera.CFrame = self.CameraBase
				* CFrame.new(math.noise(t, 0.3) * amp, math.noise(0.7, t) * amp, 0)
				* CFrame.Angles(0, 0, math.noise(t, t * 0.5) * amp * 0.02)
		else
			camera.CFrame = self.CameraBase
		end
	end
end

return CombatDirector
