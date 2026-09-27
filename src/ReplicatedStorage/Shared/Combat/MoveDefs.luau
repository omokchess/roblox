--!strict
-- 모든 공격 기술 정의 (플레이어 무기 + 적). 데이터만 바꿔 밸런스를 조정한다.
--
-- 시간: Windup(선딜) → Active(판정) → Recovery(후딜)
-- 히트박스 Offset 은 공격자 로컬 좌표 (X=오른쪽, Y=위, Z=뒤 / 정면 = -Z)
--   Arc    : Range, Angle(전체 각도), Height            — 부채꼴
--   Box    : Size, Offset                               — 회전 상자
--   Sphere : Radius, Offset                             — 구
--   Line   : Length, Width, Offset                      — 찌르기 (정면 선분)

export type Hitbox = {
	Shape: string,
	Range: number?,
	Angle: number?,
	Height: number?,
	Size: Vector3?,
	Radius: number?,
	Length: number?,
	Width: number?,
	Offset: Vector3?,
}

export type StatusApply = { Id: string, Stacks: number?, Amount: number?, Chance: number?, Duration: number? }

export type AreaSpec = {
	At: string, -- "Self" | "Target" | "Line" | "RandomAroundTarget" | "Front"
	Radius: number,
	Delay: number, -- 경고 표시 후 폭발까지
	Count: number?,
	Spacing: number?,
	Step: number?, -- 연속 폭발 간격
	Spread: number?,
	Forward: number?,
	Damage: number,
	Poise: number?,
	KnockUp: number?,
	Knockback: number?,
	Unblockable: boolean?,
	Statuses: { StatusApply }?,
	Visual: string,
}

export type ProjectileDef = {
	Speed: number,
	Gravity: number,
	Range: number,
	Radius: number,
	Damage: number,
	Poise: number,
	Homing: number?, -- rad/s
	Pull: boolean?,
	Statuses: { StatusApply }?,
	Visual: string,
	Knockback: number?,
}

export type Move = {
	Name: string,
	Type: string, -- "Light" | "Heavy" | "Skill" | "Enemy"
	Anim: string,
	Windup: number,
	Active: number,
	Recovery: number,
	Damage: number,
	Poise: number,
	Stamina: number,
	Cooldown: number?,
	Hitbox: Hitbox?,
	MultiHit: number?, -- 대상당 최대 적중 횟수
	HitInterval: number?,
	Knockback: number?,
	KnockUp: number?,
	Lunge: number?, -- 전진 거리 (stud)
	LungeStart: number?, -- 전진 시작 시각 (기본: Windup*0.5)
	LungeTime: number?,
	SuperArmor: boolean?,
	Unblockable: boolean?,
	Unparryable: boolean?,
	Telegraph: boolean?,
	Statuses: { StatusApply }?,
	HitStop: number?,
	Shake: number?,
	Projectile: string?,
	Area: AreaSpec?,
	Summon: { Type: string, Count: number }?,
	Chargeable: boolean?,
	Sound: string?,
	Icon: string?,
	Description: string?,
}

local V = Vector3.new

local Moves: { [string]: Move } = {
	-- ── 늪지기 식칼 ────────────────────────────────────────
	Cleaver_L1 = { Name = "베기", Type = "Light", Anim = "Cleaver_L1", Windup = 0.15, Active = 0.12, Recovery = 0.25, Damage = 16, Poise = 10, Stamina = 10,
		Hitbox = { Shape = "Arc", Range = 8.5, Angle = 140, Height = 7 }, Lunge = 2, HitStop = 0.05, Knockback = 8 },
	Cleaver_L2 = { Name = "올려베기", Type = "Light", Anim = "Cleaver_L2", Windup = 0.15, Active = 0.12, Recovery = 0.25, Damage = 17, Poise = 10, Stamina = 10,
		Hitbox = { Shape = "Arc", Range = 8.5, Angle = 140, Height = 8 }, Lunge = 2, HitStop = 0.05, Knockback = 8 },
	Cleaver_L3 = { Name = "내려찍기", Type = "Light", Anim = "Cleaver_L3", Windup = 0.22, Active = 0.12, Recovery = 0.28, Damage = 22, Poise = 18, Stamina = 12,
		Hitbox = { Shape = "Box", Size = V(5, 8, 9), Offset = V(0, 0, -4.5) }, Lunge = 3, HitStop = 0.07, Knockback = 14, Shake = 0.3 },
	Cleaver_L4 = { Name = "회전 마무리", Type = "Light", Anim = "Cleaver_L4", Windup = 0.12, Active = 0.4, Recovery = 0.26, Damage = 26, Poise = 24, Stamina = 14,
		Hitbox = { Shape = "Sphere", Radius = 8.5 }, Lunge = 3, HitStop = 0.08, Knockback = 34, Shake = 0.4 },
	Cleaver_Heavy = { Name = "강베기", Type = "Heavy", Anim = "Cleaver_Heavy", Windup = 0.14, Active = 0.14, Recovery = 0.44, Damage = 38, Poise = 40, Stamina = 24,
		Hitbox = { Shape = "Box", Size = V(5, 8, 11), Offset = V(0, 0, -5.5) }, Lunge = 7, LungeStart = 0, LungeTime = 0.2, SuperArmor = true,
		Knockback = 40, HitStop = 0.1, Shake = 0.6, Chargeable = true },
	Cleaver_VenomRend = { Name = "독날 베기", Type = "Skill", Anim = "Cleaver_VenomRend", Windup = 0.1, Active = 0.3, Recovery = 0.22, Damage = 12, Poise = 8, Stamina = 18,
		Cooldown = 8, Hitbox = { Shape = "Arc", Range = 9, Angle = 150, Height = 8 }, MultiHit = 2, HitInterval = 0.18, Lunge = 3,
		Statuses = { { Id = "Poison", Stacks = 2 } }, HitStop = 0.05, Icon = "☠", Description = "X자 이연격, 적중 시 중독 2중첩" },
	Cleaver_Whirl = { Name = "소용돌이 베기", Type = "Skill", Anim = "Cleaver_Whirl", Windup = 0.1, Active = 0.7, Recovery = 0.15, Damage = 14, Poise = 14, Stamina = 26,
		Cooldown = 12, Hitbox = { Shape = "Sphere", Radius = 10 }, MultiHit = 3, HitInterval = 0.22, SuperArmor = true, Knockback = 18,
		HitStop = 0.04, Icon = "🌀", Description = "2회전 범위 공격, 시전 중 경직 무시" },

	-- ── 작살창 ────────────────────────────────────────────
	Spear_L1 = { Name = "찌르기", Type = "Light", Anim = "Spear_L1", Windup = 0.14, Active = 0.1, Recovery = 0.26, Damage = 14, Poise = 8, Stamina = 9,
		Hitbox = { Shape = "Line", Length = 11.5, Width = 2.4 }, Lunge = 1.5, HitStop = 0.04, Knockback = 6 },
	Spear_L2 = { Name = "휘두르기", Type = "Light", Anim = "Spear_L2", Windup = 0.16, Active = 0.14, Recovery = 0.26, Damage = 15, Poise = 10, Stamina = 10,
		Hitbox = { Shape = "Arc", Range = 11, Angle = 120, Height = 6 }, Lunge = 1, HitStop = 0.05, Knockback = 14 },
	Spear_L3 = { Name = "연속 찌르기", Type = "Light", Anim = "Spear_L3", Windup = 0.1, Active = 0.3, Recovery = 0.26, Damage = 11, Poise = 8, Stamina = 12,
		Hitbox = { Shape = "Line", Length = 12.5, Width = 2.4 }, MultiHit = 2, HitInterval = 0.2, Lunge = 3, HitStop = 0.04, Knockback = 10 },
	Spear_Heavy = { Name = "관통 찌르기", Type = "Heavy", Anim = "Spear_Heavy", Windup = 0.16, Active = 0.26, Recovery = 0.28, Damage = 34, Poise = 30, Stamina = 22,
		Hitbox = { Shape = "Line", Length = 14, Width = 2.8 }, Lunge = 9, LungeStart = 0.02, LungeTime = 0.25, SuperArmor = true, Knockback = 30,
		Statuses = { { Id = "Bleed", Amount = 40 } }, HitStop = 0.09, Shake = 0.4, Chargeable = true },
	Spear_Throw = { Name = "작살 투척", Type = "Skill", Anim = "Spear_Throw", Windup = 0.3, Active = 0.02, Recovery = 0.3, Damage = 0, Poise = 0, Stamina = 16,
		Cooldown = 9, Projectile = "HarpoonThrow", Icon = "🎯", Description = "작살을 던져 적을 끌어당기고 출혈을 쌓는다" },
	Spear_Leap = { Name = "도약 찌르기", Type = "Skill", Anim = "Spear_Leap", Windup = 0.45, Active = 0.14, Recovery = 0.31, Damage = 30, Poise = 32, Stamina = 26,
		Cooldown = 12, Hitbox = { Shape = "Sphere", Radius = 7.5, Offset = V(0, 0, -3) }, Lunge = 20, LungeStart = 0.12, LungeTime = 0.4, SuperArmor = true,
		Knockback = 26, KnockUp = 14, HitStop = 0.09, Shake = 0.6, Icon = "🦘", Description = "높이 도약해 내리찍는 돌진기" },

	-- ── 이끼 망치 ─────────────────────────────────────────
	Maul_L1 = { Name = "휘둘러치기", Type = "Light", Anim = "Maul_L1", Windup = 0.3, Active = 0.14, Recovery = 0.34, Damage = 30, Poise = 30, Stamina = 16,
		Hitbox = { Shape = "Arc", Range = 10, Angle = 160, Height = 7 }, Lunge = 2, Knockback = 22, HitStop = 0.08, Shake = 0.3 },
	Maul_L2 = { Name = "되받아치기", Type = "Light", Anim = "Maul_L2", Windup = 0.28, Active = 0.16, Recovery = 0.36, Damage = 30, Poise = 30, Stamina = 16,
		Hitbox = { Shape = "Arc", Range = 10, Angle = 160, Height = 7 }, Lunge = 2, Knockback = 22, HitStop = 0.08, Shake = 0.3 },
	Maul_L3 = { Name = "내려찍기", Type = "Light", Anim = "Maul_L3", Windup = 0.38, Active = 0.12, Recovery = 0.45, Damage = 44, Poise = 50, Stamina = 20,
		Hitbox = { Shape = "Box", Size = V(6, 8, 10), Offset = V(0, 0, -5) }, Lunge = 3, Knockback = 36, KnockUp = 16, HitStop = 0.11, Shake = 0.7, SuperArmor = true },
	Maul_Heavy = { Name = "도약 강타", Type = "Heavy", Anim = "Maul_Heavy", Windup = 0.34, Active = 0.16, Recovery = 0.35, Damage = 60, Poise = 70, Stamina = 30,
		Hitbox = { Shape = "Sphere", Radius = 9, Offset = V(0, 0, -6) }, Lunge = 6, LungeStart = 0.05, LungeTime = 0.28, SuperArmor = true,
		Knockback = 44, KnockUp = 22, HitStop = 0.13, Shake = 1, Chargeable = true },
	Maul_GroundSlam = { Name = "대지 강타", Type = "Skill", Anim = "Maul_GroundSlam", Windup = 0.45, Active = 0.1, Recovery = 0.45, Damage = 36, Poise = 50, Stamina = 30,
		Cooldown = 12, Hitbox = { Shape = "Sphere", Radius = 15 }, SuperArmor = true, KnockUp = 20, Knockback = 20,
		Statuses = { { Id = "Slow", Duration = 3 } }, HitStop = 0.1, Shake = 1.2, Icon = "💥", Description = "주변을 강타해 적을 띄우고 둔화" },
	Maul_Charge = { Name = "돌진 강타", Type = "Skill", Anim = "Maul_Charge", Windup = 0.15, Active = 0.7, Recovery = 0.25, Damage = 32, Poise = 45, Stamina = 28,
		Cooldown = 14, Hitbox = { Shape = "Box", Size = V(7, 8, 6), Offset = V(0, 0, -3) }, Lunge = 28, LungeStart = 0.15, LungeTime = 0.7, SuperArmor = true,
		Knockback = 60, HitStop = 0.08, Shake = 0.6, Icon = "🐗", Description = "경직 무시 돌진, 부딪힌 적을 날려버린다" },

	-- ── 늪 크롤러 ─────────────────────────────────────────
	Crawler_Bite = { Name = "독 물기", Type = "Enemy", Anim = "Crawler_Bite", Windup = 0.32, Active = 0.1, Recovery = 0.18, Damage = 12, Poise = 10, Stamina = 0,
		Hitbox = { Shape = "Line", Length = 6, Width = 3 }, Lunge = 3, Statuses = { { Id = "Poison", Stacks = 1 } }, HitStop = 0.04 },
	Crawler_Swipe = { Name = "할퀴기", Type = "Enemy", Anim = "Crawler_Swipe", Windup = 0.34, Active = 0.1, Recovery = 0.18, Damage = 10, Poise = 10, Stamina = 0,
		Hitbox = { Shape = "Arc", Range = 6.5, Angle = 120, Height = 6 }, Lunge = 1.5, HitStop = 0.04 },
	Crawler_Pounce = { Name = "덮치기", Type = "Enemy", Anim = "Crawler_Pounce", Windup = 0.4, Active = 0.22, Recovery = 0.33, Damage = 16, Poise = 18, Stamina = 0,
		Hitbox = { Shape = "Sphere", Radius = 4, Offset = V(0, 0, -2) }, Lunge = 14, LungeStart = 0.35, LungeTime = 0.3, Knockback = 18, HitStop = 0.05 },

	-- ── 진흙 거인 ─────────────────────────────────────────
	Brute_Smash = { Name = "곤봉 내려찍기", Type = "Enemy", Anim = "Brute_Smash", Windup = 0.84, Active = 0.1, Recovery = 0.41, Damage = 42, Poise = 60, Stamina = 0,
		Hitbox = { Shape = "Box", Size = V(7, 10, 13), Offset = V(1.5, 0, -7) }, Knockback = 40, KnockUp = 12, SuperArmor = true, Telegraph = true, HitStop = 0.1, Shake = 0.8 },
	Brute_Sweep = { Name = "휩쓸기", Type = "Enemy", Anim = "Brute_Sweep", Windup = 0.72, Active = 0.12, Recovery = 0.36, Damage = 30, Poise = 40, Stamina = 0,
		Hitbox = { Shape = "Arc", Range = 14, Angle = 170, Height = 9 }, Knockback = 55, SuperArmor = true, Telegraph = true, HitStop = 0.08, Shake = 0.5 },
	Brute_Stomp = { Name = "지진 발구르기", Type = "Enemy", Anim = "Brute_Stomp", Windup = 0.72, Active = 0.08, Recovery = 0.5, Damage = 24, Poise = 40, Stamina = 0,
		Hitbox = { Shape = "Sphere", Radius = 13 }, Unblockable = true, KnockUp = 16, Statuses = { { Id = "Slow", Duration = 2.5 } },
		SuperArmor = true, Telegraph = true, Shake = 0.9 },

	-- ── 늪 마녀 ───────────────────────────────────────────
	Witch_Cast = { Name = "독 구체", Type = "Enemy", Anim = "Witch_Cast", Windup = 0.52, Active = 0.02, Recovery = 0.36, Damage = 0, Poise = 0, Stamina = 0,
		Projectile = "WitchBolt" },
	Witch_Hex = { Name = "저주 늪", Type = "Enemy", Anim = "Witch_Hex", Windup = 0.9, Active = 0.02, Recovery = 0.38, Damage = 0, Poise = 0, Stamina = 0,
		Area = { At = "Target", Radius = 8, Delay = 1.1, Damage = 18, Statuses = { { Id = "Poison", Stacks = 2 } :: StatusApply, { Id = "Slow", Duration = 2 } :: StatusApply }, Visual = "PoisonCloud" } },
	Witch_Swat = { Name = "지팡이 후려치기", Type = "Enemy", Anim = "Witch_Swat", Windup = 0.36, Active = 0.1, Recovery = 0.24, Damage = 12, Poise = 12, Stamina = 0,
		Hitbox = { Shape = "Arc", Range = 7.5, Angle = 130, Height = 7 }, Knockback = 26 },

	-- ── 늪의 군주 (보스) ──────────────────────────────────
	Lord_Swipe = { Name = "뿌리 할퀴기", Type = "Enemy", Anim = "Lord_Swipe", Windup = 0.52, Active = 0.46, Recovery = 0.32, Damage = 36, Poise = 45, Stamina = 0,
		Hitbox = { Shape = "Arc", Range = 17, Angle = 150, Height = 16 }, MultiHit = 2, HitInterval = 0.42, Knockback = 38, SuperArmor = true, HitStop = 0.08, Shake = 0.6 },
	Lord_Slam = { Name = "늪 강타", Type = "Enemy", Anim = "Lord_Slam", Windup = 1.16, Active = 0.12, Recovery = 0.52, Damage = 70, Poise = 100, Stamina = 0,
		Hitbox = { Shape = "Sphere", Radius = 16, Offset = V(0, -6, -12) }, Unblockable = true, KnockUp = 30, Knockback = 30, SuperArmor = true, Telegraph = true,
		HitStop = 0.14, Shake = 1.6 },
	Lord_Roots = { Name = "가시 뿌리", Type = "Enemy", Anim = "Lord_Roots", Windup = 0.85, Active = 0.02, Recovery = 0.63, Damage = 0, Poise = 0, Stamina = 0,
		SuperArmor = true,
		Area = { At = "Line", Radius = 4.5, Delay = 0.45, Count = 8, Spacing = 6.5, Step = 0.11, Forward = 6, Damage = 32, Poise = 30, KnockUp = 18,
			Statuses = { { Id = "Rooted" } }, Visual = "RootSpike" } },
	Lord_Roar = { Name = "포효", Type = "Enemy", Anim = "Lord_Roar", Windup = 0.4, Active = 0.8, Recovery = 0.4, Damage = 10, Poise = 80, Stamina = 0,
		Hitbox = { Shape = "Sphere", Radius = 22 }, Unblockable = true, Knockback = 70, Statuses = { { Id = "Stun", Duration = 0.8 } }, SuperArmor = true, Shake = 1.2 },
	Lord_Summon = { Name = "늪의 부름", Type = "Enemy", Anim = "Lord_Summon", Windup = 0.6, Active = 0.02, Recovery = 0.78, Damage = 0, Poise = 0, Stamina = 0,
		Summon = { Type = "BogCrawler", Count = 2 }, SuperArmor = true },
	Lord_Rain = { Name = "독비", Type = "Enemy", Anim = "Lord_Rain", Windup = 0.7, Active = 0.02, Recovery = 0.7, Damage = 0, Poise = 0, Stamina = 0,
		SuperArmor = true,
		Area = { At = "RandomAroundTarget", Radius = 7, Delay = 1.4, Count = 7, Spread = 26, Step = 0.12, Damage = 24, Statuses = { { Id = "Poison", Stacks = 2 } },
			Visual = "PoisonCloud" } },
}

local Projectiles: { [string]: ProjectileDef } = {
	HarpoonThrow = { Speed = 150, Gravity = 22, Range = 95, Radius = 1.4, Damage = 22, Poise = 20, Pull = true, Knockback = 0,
		Statuses = { { Id = "Bleed", Amount = 45 } }, Visual = "Harpoon" },
	WitchBolt = { Speed = 58, Gravity = 0, Range = 75, Radius = 1.6, Damage = 16, Poise = 12, Homing = 1.4,
		Statuses = { { Id = "Poison", Stacks = 1 } }, Visual = "PoisonOrb" },
}

return { Moves = Moves, Projectiles = Projectiles }
