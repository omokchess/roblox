--!strict
--[[
	보스 디버그 모션. (2026-09-29)

	부위마다 따로 움직인다(Client/Combat/DebugBoss.luau 가 입힌다). 채널은 슬라임과 같다:
	  Root = { x, y, z, rx, ry, rz }   부위 전체(바닥 가운데 기준). z+ = 뒤(아군 반대쪽), 회전은 도
	  Body = { sx, sy, sz }            늘고 줄기(%)
	부위마다 Idle·Windup(예고)·Hit·Death 와 제 스킬(Skills[스킬 Id])을 가진다. 스킬 Id 는 BattleSkills 보스 스킬.
	이펙트 이름(Fx·fx)은 Client/Combat/Fx/Debug.luau.
]]
local function K(t: number, e: string?, body: { number }, root: { number }?)
	return { t = t, e = e, Body = body, Root = root }
end

local Z = { 0, 0, 0, 0, 0, 0 }
local B0 = { 0, 0, 0 }

-- 맞음: 뒤로 밀리며 눌렸다가 되돌아온다(부위 공통)
local HIT = {
	Duration = 0.55,
	BlendIn = 0.02,
	Keys = {
		K(0, nil, B0, Z),
		K(0.04, "expoOut", { 8, -10, 8 }, { 0, 0, 0.6, 6, 0, 0 }),
		K(0.2, "quadOut", { -4, 5, -4 }, { 0, 0, 0.3, -2, 0, 0 }),
		K(0.55, "sineInOut", B0, Z),
	},
}

-- 부서짐: 좌우로 튀며 떨다가 무너져 가라앉는다(부위 공통, 뒤이어 연출이 흐리게 지운다)
local DEATH = {
	Duration = 1.1,
	BlendIn = 0.02,
	Keys = {
		K(0, nil, B0, Z),
		K(0.08, "linear", { 4, -4, 4 }, { 0.35, 0, 0, 0, 0, 4 }),
		K(0.16, "linear", { -4, 4, -4 }, { -0.35, 0, 0, 0, 0, -4 }),
		K(0.24, "linear", { 6, -6, 6 }, { 0.25, 0, 0.2, 2, 0, 3 }),
		K(0.9, "quadIn", { 20, -70, 20 }, { 0, -1.5, 0.4, 8, 0, 0 }),
		K(1.1, "linear", { 24, -80, 24 }, { 0, -1.8, 0.4, 8, 0, 0 }),
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
			K(0.09, "sineInOut", body, j(0.08, 2)),
			K(0.18, "sineInOut", body, j(-0.08, -2)),
			K(0.27, "sineInOut", body, j(0.05, 1)),
		},
	}
end

local HEAD_WIND = { 0, 0.4, 0.5, 10, 0, 0 }
local DEL_WIND = { 0, 1.2, 0.6, 18, 0, 0 }
local PATCH_WIND = { 0, 0.8, 1.0, 10, -12, 0 }

return {
	-- 머리: 둥실 떠서 천천히 끄덕인다. 광선은 젖혔다가 앞으로 탁 튕기며 쏜다
	Head = {
		Idle = {
			Duration = 3.1,
			Loop = true,
			Keys = {
				K(0, "sineInOut", B0, Z),
				K(1.55, "sineInOut", { 0, 2, 0 }, { 0, 0.35, 0.1, -3, 2, 0 }),
				K(3.1, "sineInOut", B0, Z),
			},
		},
		Windup = windup({ 4, -4, 4 }, HEAD_WIND),
		Hit = HIT,
		Death = DEATH,
		Skills = {
			BreakpointBeam = {
				Duration = 1.25,
				BlendIn = 0.05,
				Keys = {
					K(0, nil, { 4, -4, 4 }, HEAD_WIND),
					K(0.3, "quadIn", { 6, -6, 6 }, { 0, 0.6, 0.8, 14, 0, 0 }),
					K(0.42, "expoOut", { -6, 8, -6 }, { 0, 0.2, -0.6, -8, 0, 0 }),
					K(0.8, "sineInOut", { -2, 3, -2 }, { 0, 0.1, -0.3, -4, 0, 0 }),
					K(1.25, "sineInOut", B0, Z),
				},
				Events = {
					{ t = 0.08, k = "Fx", n = "BeamCharge" },
					{ t = 0.42, k = "Fx", n = "Beam" },
					{ t = 0.46, k = "Hit", i = 1, fx = "BeamHit" },
					{ t = 0.46, k = "Shake", a = 0.35, d = 0.25 },
				},
			},
		},
	},

	-- 삭제 팔: 느리게 흔들린다. 칸 삭제는 높이 들었다가 내리찍는다
	DeleteArm = {
		Idle = {
			Duration = 3.4,
			Loop = true,
			Keys = {
				K(0, "sineInOut", B0, Z),
				K(1.7, "sineInOut", B0, { 0, 0.2, 0.1, -3, 0, 1 }),
				K(3.4, "sineInOut", B0, Z),
			},
		},
		Windup = windup(B0, DEL_WIND),
		Hit = HIT,
		Death = DEATH,
		Skills = {
			DeleteCells = {
				Duration = 1.35,
				BlendIn = 0.05,
				Keys = {
					K(0, nil, B0, DEL_WIND),
					K(0.3, "quadOut", { -4, 6, -4 }, { 0, 2.6, 1.0, 30, 0, 0 }),
					K(0.56, "expoIn", { 10, -12, 10 }, { 0, -0.4, -1.2, -16, 0, 0 }),
					K(0.85, "sineInOut", { 4, -5, 4 }, { 0, -0.2, -0.8, -10, 0, 0 }),
					K(1.35, "sineInOut", B0, Z),
				},
				Events = {
					{ t = 0.56, k = "Fx", n = "DeleteSlam" },
					{ t = 0.58, k = "Hit", i = 1, fx = "DeleteHit" },
					{ t = 0.56, k = "Shake", a = 0.5, d = 0.3 },
				},
			},
		},
	},

	-- 패치 팔: 강제 적용은 뒤로 젖혔다가 옆으로 쓸고, 패치 적용은 손바닥을 들어 초록빛을 낸다
	PatchArm = {
		Idle = {
			Duration = 2.9,
			Loop = true,
			Keys = {
				K(0, "sineInOut", B0, Z),
				K(1.45, "sineInOut", B0, { 0, 0.18, 0.1, -2, -2, 0 }),
				K(2.9, "sineInOut", B0, Z),
			},
		},
		Windup = windup(B0, PATCH_WIND),
		Hit = HIT,
		Death = DEATH,
		Skills = {
			ForcedPatch = {
				Duration = 1.2,
				BlendIn = 0.05,
				Keys = {
					K(0, nil, B0, PATCH_WIND),
					K(0.28, "quadOut", B0, { 0, 1.2, 1.2, 12, -22, 0 }),
					K(0.46, "expoOut", { 4, -4, 4 }, { 0, 0.4, -1.0, -6, 26, 0 }),
					K(0.8, "sineInOut", B0, { 0, 0.2, -0.4, -2, 10, 0 }),
					K(1.2, "sineInOut", B0, Z),
				},
				Events = {
					{ t = 0.46, k = "Fx", n = "PatchSweep" },
					{ t = 0.5, k = "Hit", i = 1, fx = "PatchHit" },
					{ t = 0.46, k = "Shake", a = 0.3, d = 0.2 },
				},
			},
			PatchCells = {
				Duration = 1.1,
				BlendIn = 0.05,
				Keys = {
					K(0, nil, B0, Z),
					K(0.3, "backOut", { -4, 6, -4 }, { 0, 1.4, 0.2, -12, 0, 0 }),
					K(0.6, "sineInOut", { -2, 3, -2 }, { 0, 1.2, 0.2, -10, 0, 0 }),
					K(1.1, "sineInOut", B0, Z),
				},
				Events = { { t = 0.36, k = "Fx", n = "PatchApply" } },
			},
		},
	},

	-- 코어: 숨 쉬듯 부풀었다 가라앉는다. 코어 덤프는 크게 부풀었다가 터뜨린다
	Core = {
		Idle = {
			Duration = 3.6,
			Loop = true,
			Keys = {
				K(0, "sineInOut", B0, Z),
				K(1.8, "sineInOut", { 1.5, 3, 1.5 }, { 0, 0.1, 0, 0, 0, 0 }),
				K(3.6, "sineInOut", B0, Z),
			},
		},
		Windup = windup({ 6, 8, 6 }, { 0, 0.2, 0, 0, 0, 0 }),
		Hit = HIT,
		Death = DEATH,
		Skills = {
			CoreDump = {
				Duration = 1.5,
				BlendIn = 0.05,
				Keys = {
					K(0, nil, { 6, 8, 6 }, { 0, 0.2, 0, 0, 0, 0 }),
					K(0.42, "quadIn", { 12, 15, 12 }, { 0, 0.5, 0, -2, 0, 0 }),
					K(0.54, "expoOut", { -8, -10, -8 }, { 0, -0.2, -0.3, 3, 0, 0 }),
					K(0.9, "elasticOut", { 2, 2, 2 }, Z),
					K(1.5, "sineInOut", B0, Z),
				},
				Events = {
					{ t = 0.54, k = "Fx", n = "CoreDump" },
					{ t = 0.62, k = "Hit", i = 1, fx = "DumpHit" },
					{ t = 0.54, k = "Shake", a = 0.7, d = 0.4 },
				},
			},
			-- 널 포인터: 몸을 낮췄다가 결정이 붉게 번쩍, 두 라인이 무너진다
			NullPointer = {
				Duration = 1.3,
				BlendIn = 0.05,
				Keys = {
					K(0, nil, { 6, 8, 6 }, { 0, 0.2, 0, 0, 0, 0 }),
					K(0.34, "quadIn", { 8, -8, 8 }, { 0, -0.4, 0.2, 3, 0, 0 }),
					K(0.46, "expoOut", { -4, 10, -4 }, { 0, 0.4, -0.2, -3, 0, 0 }),
					K(0.8, "sineInOut", { 1, 1, 1 }, Z),
					K(1.3, "sineInOut", B0, Z),
				},
				Events = {
					{ t = 0.46, k = "Fx", n = "NullPointer" },
					{ t = 0.52, k = "Hit", i = 1, fx = "NullHit" },
					{ t = 0.46, k = "Shake", a = 0.5, d = 0.3 },
				},
			},
			-- 메모리 누수: 등 위 오류 조각이 떠올랐다가 쏟아진다
			MemoryLeak = {
				Duration = 1.4,
				BlendIn = 0.05,
				Keys = {
					K(0, nil, B0, Z),
					K(0.4, "sineOut", { -3, 6, -3 }, { 0, 0.5, 0, -2, 0, 0 }),
					K(0.6, "quadIn", { 4, -5, 4 }, { 0, -0.1, 0, 1, 0, 0 }),
					K(1.4, "sineInOut", B0, Z),
				},
				Events = {
					{ t = 0.3, k = "Fx", n = "LeakRise" },
					{ t = 0.72, k = "Hit", i = 1, fx = "LeakHit" },
					{ t = 0.72, k = "Shake", a = 0.25, d = 0.2 },
				},
			},
		},
	},
}
