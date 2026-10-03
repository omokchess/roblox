--!strict
--[[
	보스 디버그 모션. (2026-09-29, 2026-10-03 다시 짬 — 정십이면체 코어 + 위성 셋)

	부위마다 따로 움직인다(Client/Combat/DebugBoss.luau 가 입힌다). 채널은 슬라임과 같다:
	  Root = { x, y, z, rx, ry, rz }   부위 전체(다면체 가운데 기준). z+ = 뒤(아군 반대쪽), 회전은 도
	  Body = { sx, sy, sz }            늘고 줄기(%)
	다면체가 도는 것·위성이 코어 앞을 도는 것은 모션이 아니라 DebugBoss·CombatDirector 가 늘 한다(공격 중엔 궤도가 멈춰 겨눈다).
	2026-10-03 사용자: "돌아가거나, 움직이면서 투사체 같은 걸 발사하면서 공격" — 공격마다 투사체를 쏘고(Fx 의 d = 날아가는 초),
	투사체가 닿는 순간이 Hit 이다. Hit·Duration 시각은 예전 그대로(연출 박자).
	부위마다 Idle·Windup(예고)·Hit·Death 와 제 스킬(Skills[스킬 Id])을 가진다. 스킬 Id 는 BattleSkills 보스 스킬.
	이펙트 이름(Fx·fx)은 Client/Combat/Fx/Debug.luau.
]]
local function K(t: number, e: string?, body: { number }, root: { number }?)
	return { t = t, e = e, Body = body, Root = root }
end

local Z = { 0, 0, 0, 0, 0, 0 }
local B0 = { 0, 0, 0 }

-- 맞음: 뒤로 튕기며 기울었다가 되돌아온다(부위 공통)
local HIT = {
	Duration = 0.55,
	BlendIn = 0.02,
	Keys = {
		K(0, nil, B0, Z),
		K(0.04, "expoOut", { -8, -8, -8 }, { 0.2, 0.3, 0.9, 12, 0, 8 }),
		K(0.2, "quadOut", { 4, 4, 4 }, { 0, 0.1, 0.4, -3, 0, -2 }),
		K(0.55, "sineInOut", B0, Z),
	},
}

-- 부서짐(위성): 글리치로 떨다가 기울며 떨어진다(뒤이어 연출이 흐리게 지운다)
local DEATH = {
	Duration = 1.1,
	BlendIn = 0.02,
	Keys = {
		K(0, nil, B0, Z),
		K(0.08, "linear", { 6, -4, 6 }, { 0.35, 0, 0, 0, 0, 8 }),
		K(0.16, "linear", { -4, 6, -4 }, { -0.35, 0, 0, 0, 0, -8 }),
		K(0.24, "linear", { 8, 8, 8 }, { 0.25, 0.3, 0.2, 6, 0, 10 }),
		K(0.9, "quadIn", { -30, -30, -30 }, { 0.6, -7, 1.0, 50, 0, 70 }),
		K(1.1, "linear", { -40, -40, -40 }, { 0.7, -8.5, 1.1, 60, 0, 80 }),
	},
	Events = { { t = 0.1, k = "Fx", n = "Break" } },
}

-- 부서짐(코어): 크게 떨다가 안으로 무너져 줄어든다
local DEATH_CORE = {
	Duration = 1.1,
	BlendIn = 0.02,
	Keys = {
		K(0, nil, B0, Z),
		K(0.08, "linear", { 6, -6, 6 }, { 0.5, 0, 0, 0, 0, 4 }),
		K(0.16, "linear", { -6, 6, -6 }, { -0.5, 0, 0, 0, 0, -4 }),
		K(0.3, "quadOut", { 14, 14, 14 }, { 0, 0.4, 0, 4, 0, 2 }),
		K(0.9, "quadIn", { -55, -55, -55 }, { 0, -3, 0, 10, 0, 0 }),
		K(1.1, "linear", { -70, -70, -70 }, { 0, -3.5, 0, 12, 0, 0 }),
	},
	Events = { { t = 0.1, k = "Fx", n = "Break" } },
}

-- 예고(회피 QTE 동안)는 떨림 네 박자로 만든다: 기본 자세 pose 둘레를 흔든다
local function windup(body: { number }, root: { number }): any
	local function j(dx: number, rz: number): { number }
		return { root[1] + dx, root[2], root[3], root[4], root[5], root[6] + rz }
	end
	return {
		Duration = 0.36,
		Loop = true,
		Keys = {
			K(0, "sineInOut", body, j(0, 0)),
			K(0.09, "sineInOut", body, j(0.1, 3)),
			K(0.18, "sineInOut", body, j(-0.1, -3)),
			K(0.27, "sineInOut", body, j(0.06, 1)),
		},
	}
end

-- 예고 자세: 뒤로 살짝 물러나 겨눈다
local HEAD_WIND = { 0, 0.3, 0.6, -6, 0, 0 }
local DEL_WIND = { 0, 0.6, 0.8, -8, 0, 0 }
local PATCH_WIND = { 0, 0.4, 0.8, -6, 0, 0 }

-- 둥실(위성 공통 대기)
local function bob(d: number, dy: number, tilt: number): any
	return {
		Duration = d,
		Loop = true,
		Keys = {
			K(0, "sineInOut", B0, Z),
			K(d / 2, "sineInOut", { 1.5, 1.5, 1.5 }, { 0, dy, 0, tilt, 0, tilt * 0.6 }),
			K(d, "sineInOut", B0, Z),
		},
	}
end

local M = {
	-- 머리: 중단점 탄. 뒤로 당기며 부풀었다가 붉은 탄을 탁 쏘고 반동으로 밀린다
	Head = {
		Idle = bob(3.1, 0.4, -3),
		Windup = windup({ 5, 5, 5 }, HEAD_WIND),
		Hit = HIT,
		Death = DEATH,
		Skills = {
			BreakpointBeam = {
				Duration = 1.25,
				BlendIn = 0.05,
				Keys = {
					K(0, nil, { 5, 5, 5 }, HEAD_WIND),
					K(0.28, "quadIn", { 12, 12, 12 }, { 0, 0.4, 1.0, -8, 0, 0 }),
					K(0.32, "expoOut", { -10, -10, -10 }, { 0, 0.2, 1.6, 6, 0, 0 }),
					K(0.8, "sineInOut", { -2, -2, -2 }, { 0, 0.1, 0.5, 2, 0, 0 }),
					K(1.25, "sineInOut", B0, Z),
				},
				Events = {
					{ t = 0.08, k = "Fx", n = "BeamCharge" },
					{ t = 0.3, k = "Fx", n = "Bolt", d = 0.16 },
					{ t = 0.46, k = "Hit", i = 1, fx = "BeamHit" },
					{ t = 0.46, k = "Shake", a = 0.35, d = 0.25 },
				},
			},
		},
	},

	-- 삭제 팔: 위로 솟으며 거꾸로 빨리 돌고, 마젠타 삭제 조각을 한 줌 흩뿌려 칸에 꽂는다
	DeleteArm = {
		Idle = bob(3.4, 0.3, 3),
		Windup = windup(B0, DEL_WIND),
		Hit = HIT,
		Death = DEATH,
		Skills = {
			DeleteCells = {
				Duration = 1.35,
				BlendIn = 0.05,
				Keys = {
					K(0, nil, B0, DEL_WIND),
					K(0.3, "quadOut", { 10, 10, 10 }, { 0, 1.8, 0.6, -14, 0, 20 }),
					K(0.38, "expoOut", { -8, -8, -8 }, { 0, 1.2, -1.4, 10, 0, -10 }),
					K(0.85, "sineInOut", { 2, 2, 2 }, { 0, 0.4, -0.4, 4, 0, 0 }),
					K(1.35, "sineInOut", B0, Z),
				},
				Events = {
					{ t = 0.12, k = "Fx", n = "DeleteCharge" },
					{ t = 0.36, k = "Fx", n = "DeleteVolley", d = 0.2 },
					{ t = 0.56, k = "Fx", n = "DeleteSlam" },
					{ t = 0.58, k = "Hit", i = 1, fx = "DeleteHit" },
					{ t = 0.56, k = "Shake", a = 0.5, d = 0.3 },
				},
			},
		},
	},

	-- 패치 팔: 강제 적용은 옆으로 비틀었다가 초록 탄 셋을 휘어 쏘고, 패치 적용은 위로 떠올라 초록빛을 뿌린다
	PatchArm = {
		Idle = bob(2.9, 0.35, -2),
		Windup = windup(B0, PATCH_WIND),
		Hit = HIT,
		Death = DEATH,
		Skills = {
			ForcedPatch = {
				Duration = 1.2,
				BlendIn = 0.05,
				Keys = {
					K(0, nil, B0, PATCH_WIND),
					K(0.26, "quadOut", { 8, 8, 8 }, { 0, 0.6, 1.0, -6, -20, 0 }),
					K(0.32, "expoOut", { -6, -6, -6 }, { 0, 0.3, -0.8, 4, 18, 0 }),
					K(0.8, "sineInOut", B0, { 0, 0.1, -0.3, 1, 6, 0 }),
					K(1.2, "sineInOut", B0, Z),
				},
				Events = {
					{ t = 0.28, k = "Fx", n = "PatchShot", d = 0.22 },
					{ t = 0.5, k = "Hit", i = 1, fx = "PatchHit" },
					{ t = 0.5, k = "Shake", a = 0.3, d = 0.2 },
				},
			},
			PatchCells = {
				Duration = 1.1,
				BlendIn = 0.05,
				Keys = {
					K(0, nil, B0, Z),
					K(0.3, "backOut", { 10, 10, 10 }, { 0, 1.6, 0.2, -10, 0, 0 }),
					K(0.6, "sineInOut", { 4, 4, 4 }, { 0, 1.3, 0.2, -6, 0, 0 }),
					K(1.1, "sineInOut", B0, Z),
				},
				Events = { { t = 0.36, k = "Fx", n = "PatchApply" } },
			},
		},
	},

	-- 코어: 숨 쉬듯 부풀었다 가라앉는다. 큰 공격은 크게 부풀며 모았다가 쏜다
	Core = {
		Idle = {
			Duration = 3.6,
			Loop = true,
			Keys = {
				K(0, "sineInOut", B0, Z),
				K(1.8, "sineInOut", { 2.5, 2.5, 2.5 }, { 0, 0.3, 0, 0, 0, 0 }),
				K(3.6, "sineInOut", B0, Z),
			},
		},
		Windup = windup({ 6, 6, 6 }, { 0, 0.2, 0.3, 0, 0, 0 }),
		Hit = HIT,
		Death = DEATH_CORE,
		Skills = {
			-- 코어 덤프: 크게 부풀며 결정에 마젠타를 모아 큰 덩어리를 쏜다 — 닿으면 아군 진영을 쓸어 터진다
			CoreDump = {
				Duration = 1.5,
				BlendIn = 0.05,
				Keys = {
					K(0, nil, { 6, 6, 6 }, { 0, 0.2, 0.3, 0, 0, 0 }),
					K(0.4, "quadIn", { 14, 14, 14 }, { 0, 0.5, 0.6, -3, 0, 0 }),
					K(0.46, "expoOut", { -10, -10, -10 }, { 0, -0.2, 1.4, 4, 0, 0 }),
					K(0.9, "elasticOut", { 2, 2, 2 }, Z),
					K(1.5, "sineInOut", B0, Z),
				},
				Events = {
					{ t = 0.1, k = "Fx", n = "DumpCharge" },
					{ t = 0.42, k = "Fx", n = "CoreDump", d = 0.2 },
					{ t = 0.62, k = "Hit", i = 1, fx = "DumpHit" },
					{ t = 0.62, k = "Shake", a = 0.7, d = 0.4 },
				},
			},
			-- 널 포인터: 몸을 움츠렸다가 붉은 화살표 탄 둘을 쏜다 — 두 라인이 무너진다
			NullPointer = {
				Duration = 1.3,
				BlendIn = 0.05,
				Keys = {
					K(0, nil, { 6, 6, 6 }, { 0, 0.2, 0.3, 0, 0, 0 }),
					K(0.32, "quadIn", { -8, -8, -8 }, { 0, -0.3, 0.6, 3, 0, 0 }),
					K(0.38, "expoOut", { 8, 8, 8 }, { 0, 0.3, 1.0, -3, 0, 0 }),
					K(0.8, "sineInOut", { 1, 1, 1 }, Z),
					K(1.3, "sineInOut", B0, Z),
				},
				Events = {
					{ t = 0.34, k = "Fx", n = "NullPointer", d = 0.18 },
					{ t = 0.52, k = "Hit", i = 1, fx = "NullHit" },
					{ t = 0.52, k = "Shake", a = 0.5, d = 0.3 },
				},
			},
			-- 메모리 누수: 위로 오류 조각을 쏘아 올렸다가 아군 위로 쏟아붓는다
			MemoryLeak = {
				Duration = 1.4,
				BlendIn = 0.05,
				Keys = {
					K(0, nil, B0, Z),
					K(0.4, "sineOut", { 6, 6, 6 }, { 0, 0.6, 0, -3, 0, 0 }),
					K(0.6, "quadIn", { -4, -4, -4 }, { 0, -0.1, 0, 1, 0, 0 }),
					K(1.4, "sineInOut", B0, Z),
				},
				Events = {
					{ t = 0.3, k = "Fx", n = "LeakRise" },
					{ t = 0.5, k = "Fx", n = "LeakRain", d = 0.22 },
					{ t = 0.72, k = "Hit", i = 1, fx = "LeakHit" },
					{ t = 0.72, k = "Shake", a = 0.25, d = 0.2 },
				},
			},
		},
	},
}

--[[
	2026-10-03: 페이즈마다 해금되는 스킬·궁극기의 모션. 공격은 부위의 원래 공격 모션을 그대로 쓰되 이펙트(Fx 이름)만 바꾸고,
	버프·충전은 부위 공통 모션(부풀며 빛을 모았다가 터뜨림 / 떨며 빛을 모음)이다. Hit 시각은 원래 모션 그대로.
]]
local function withFx(motion: any, rename: { [string]: string }): any
	local copy = table.clone(motion)
	copy.Events = {}
	for _, ev in motion.Events or {} do
		local e = table.clone(ev)
		if e.n and rename[e.n] then
			e.n = rename[e.n]
		end
		if e.fx and rename[e.fx] then
			e.fx = rename[e.fx]
		end
		table.insert(copy.Events, e)
	end
	return copy
end

-- 버프: 부풀며 빛을 모았다가 한 번에 퍼뜨린다(피해 없음)
local BUFF = {
	Duration = 1.1,
	BlendIn = 0.05,
	Keys = {
		K(0, nil, B0, Z),
		K(0.35, "quadOut", { 12, 12, 12 }, { 0, 0.8, 0.2, -6, 0, 0 }),
		K(0.5, "expoOut", { -6, -6, -6 }, { 0, 0.4, 0, 3, 0, 0 }),
		K(1.1, "sineInOut", B0, Z),
	},
	Events = {
		{ t = 0.1, k = "Fx", n = "BuffGather" },
		{ t = 0.5, k = "Fx", n = "BuffPulse" },
	},
}
-- 충전: 떨면서 빛을 빨아들인다(다음 턴에 터진다)
local CHARGE = {
	Duration = 1.3,
	BlendIn = 0.05,
	Keys = {
		K(0, nil, B0, Z),
		K(0.3, "quadOut", { 8, 8, 8 }, { 0.15, 0.6, 0.6, 0, 0, 4 }),
		K(0.5, "linear", { 10, 10, 10 }, { -0.15, 0.6, 0.6, 0, 0, -4 }),
		K(0.7, "linear", { 12, 12, 12 }, { 0.15, 0.7, 0.6, 0, 0, 4 }),
		K(0.9, "linear", { 14, 14, 14 }, { -0.15, 0.7, 0.6, 0, 0, -4 }),
		K(1.3, "sineInOut", { 6, 6, 6 }, { 0, 0.3, 0.3, 0, 0, 0 }),
	},
	Events = {
		{ t = 0.1, k = "Fx", n = "ChargeStart" },
		{ t = 0.6, k = "Fx", n = "ChargeStart" },
	},
}

local head, del, patch, core = M.Head.Skills, M.DeleteArm.Skills, M.PatchArm.Skills, M.Core.Skills
head.StackTrace = withFx(head.BreakpointBeam, { Bolt = "StackBolt" })
head.Watchpoint = BUFF
head.BreakStorm = withFx(head.BreakpointBeam, { Bolt = "StormBolts", BeamHit = "StormHit" })
del.ForceQuit = withFx(del.DeleteCells, { DeleteSlam = "ForceSlam" })
del.Sudo = BUFF
del.Format = CHARGE
patch.Hotfix = BUFF
patch.BugPlant = withFx(patch.ForcedPatch, { PatchShot = "BugSeeds" })
patch.DependencyHell = BUFF
core.Overclock = BUFF
core.KernelPanic = CHARGE
core.KernelPanicBurst = withFx(core.CoreDump, { CoreDump = "PanicBurst", DumpHit = "PanicHit" })
core.InfiniteRecursion = withFx(core.NullPointer, { NullPointer = "RecursionShot" })
core.BlueScreen = withFx(core.CoreDump, { DumpCharge = "BlueCharge", CoreDump = "BlueScreen", DumpHit = "BlueHit" })
-- 검수를 코어가 이어 할 때(삭제 팔이 부서진 뒤)
core.DeleteCells = withFx(del.DeleteCells, {})

return M
