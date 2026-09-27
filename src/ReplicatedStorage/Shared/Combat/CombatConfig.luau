--!strict
-- 전투 전역 튜닝값 (서버 권위: 서버 값이 기준, 클라이언트는 예측/표시에만 사용)

local CombatConfig = {
	TickRate = 30, -- 서버 전투 루프 Hz
	AttributeRate = 12, -- 상태 복제(Attribute) Hz
	PvP = false, -- 플레이어끼리 공격 허용

	Player = {
		MaxHealth = 160,
		MaxStamina = 100,
		MaxPoise = 40,
		Defense = 0,
		Power = 1,
		WalkSpeed = 16,
		HitRadius = 1.9,
	},

	Stamina = {
		Regen = 30, -- 초당
		RegenDelay = 0.75, -- 마지막 소모 후 대기
		BlockRegenScale = 0.35, -- 방어 중 회복 배율
		ExhaustedLock = 0.9, -- 0이 되면 이 시간 동안 스태미나 행동 불가
	},

	Poise = {
		RegenDelay = 2.4,
		RegenRate = 30,
		StaggerTime = 0.9,
	},

	Dodge = {
		Cost = 22,
		Duration = 0.44,
		IFrameStart = 0.02,
		IFrameEnd = 0.34,
		Speed = 44, -- 구르기 초기 속도 (stud/s)
		Cooldown = 0.55,
	},

	Block = {
		HalfAngle = 75, -- 정면 방어 반각(도)
		ParryWindow = 0.2, -- 방어 시작 후 패링 판정 시간
		ParryLatencyGrace = 0.08,
		StaminaPerDamage = 0.9,
		SpeedScale = 0.5,
		GuardBreakStagger = 1.4,
		ReleaseCooldown = 0.25,
	},

	Parry = {
		AttackerStagger = 1.1,
		RiposteWindow = 1.8,
		RiposteMult = 1.8,
	},

	Crit = { Chance = 0.08, Mult = 1.5 },
	Backstab = { HalfAngle = 55, Mult = 1.35 },

	LagComp = {
		MaxRewind = 0.35,
		InterpDelay = 0.1,
		History = 1.0,
		PositionTolerance = 14, -- 클라 보고 위치와 서버 위치 허용 오차
	},

	Combo = {
		BufferWindow = 0.35, -- 모션 종료 전 다음 입력을 미리 받아두는 시간
		ResetTime = 0.9, -- 연타가 끊겼다고 보는 시간
	},

	Heavy = {
		MinCharge = 0.28, -- 이보다 짧게 누르면 약공격
		MaxCharge = 1.2,
		ChargeDamageBonus = 0.6, -- 최대 충전 시 +60%
	},

	AttackMoveSpeed = 0.35, -- 공격 중 이동속도 배율
	CombatTagTime = 6, -- 교전 상태 유지 시간
	HitRadiusSlack = 1.15, -- 서버 판정 관용
	KnockbackMax = 90,
	RespawnInvuln = 2.5,
}

return CombatConfig
