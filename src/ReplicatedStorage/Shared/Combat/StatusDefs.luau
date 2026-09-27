--!strict
-- 상태이상 정의

export type StatusDef = {
	Name: string,
	Icon: string,
	Color: Color3,
	Kind: string, -- "Dot" | "Buildup" | "Slow" | "Stun" | "Buff"
	Duration: number,
	MaxStacks: number,
	Tick: number?,
	DamagePct: number?, -- 최대 체력 대비 (틱당, 스택당)
	SpeedMult: number?,
	Threshold: number?, -- 누적형 발동치
	Decay: number?, -- 누적형 초당 감소
	BurstPct: number?,
	Debuff: boolean,
}

local StatusDefs: { [string]: StatusDef } = {
	Poison = {
		Name = "중독",
		Icon = "☠",
		Color = Color3.fromRGB(128, 224, 92),
		Kind = "Dot",
		Duration = 6,
		MaxStacks = 5,
		Tick = 1,
		DamagePct = 0.011,
		Debuff = true,
	},
	Bleed = {
		Name = "출혈",
		Icon = "🩸",
		Color = Color3.fromRGB(214, 48, 48),
		Kind = "Buildup",
		Duration = 8,
		MaxStacks = 1,
		Threshold = 100,
		Decay = 10,
		BurstPct = 0.12,
		Debuff = true,
	},
	Burn = {
		Name = "화상",
		Icon = "🔥",
		Color = Color3.fromRGB(255, 132, 48),
		Kind = "Dot",
		Duration = 4,
		MaxStacks = 3,
		Tick = 0.5,
		DamagePct = 0.008,
		Debuff = true,
	},
	Slow = {
		Name = "둔화",
		Icon = "🐌",
		Color = Color3.fromRGB(120, 170, 220),
		Kind = "Slow",
		Duration = 3,
		MaxStacks = 1,
		SpeedMult = 0.6,
		Debuff = true,
	},
	Rooted = {
		Name = "속박",
		Icon = "🌿",
		Color = Color3.fromRGB(96, 170, 80),
		Kind = "Slow",
		Duration = 1.4,
		MaxStacks = 1,
		SpeedMult = 0,
		Debuff = true,
	},
	Stun = {
		Name = "기절",
		Icon = "💫",
		Color = Color3.fromRGB(255, 230, 120),
		Kind = "Stun",
		Duration = 1,
		MaxStacks = 1,
		Debuff = true,
	},
	Riposte = {
		Name = "반격 기회",
		Icon = "⚔",
		Color = Color3.fromRGB(255, 214, 120),
		Kind = "Buff",
		Duration = 1.8,
		MaxStacks = 1,
		Debuff = false,
	},
	Enraged = {
		Name = "격노",
		Icon = "😡",
		Color = Color3.fromRGB(255, 80, 60),
		Kind = "Buff",
		Duration = 9999,
		MaxStacks = 1,
		Debuff = false,
	},
}

return StatusDefs
