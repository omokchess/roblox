--!strict
--[[
	WeaponDefinitions — 전투에서 드는 무기의 **모양·쥐는 법·종류**. (2026-09-28)

	사양 출처: `유저 아이디어(직업).md` 각 직업의 "사용 무기"
	  음악가 바이올린 · 결투사 레이피어 · 퀘이사 대검 · 펄서 오브 3개 · 월 필그림 석공용 못
	  월 메이슨 석공 망치 · 월 브레이커 곡괭이 모양 지팡이 · 연금술사 약병 · 광전사(문서 없음) 양손 도끼

	**다른 무기를 들어도 모션이 맞도록 하는 약속**
	  - 무기마다 `Type`(쥐는 방식의 종류)을 둔다. 모션은 무기 Id 가 아니라 이 종류에 맞춰 만든다.
	    같은 종류의 새 무기(예: 레이피어 → 세이버)는 표에 한 줄 더하면 모션을 그대로 쓴다.
	  - 무기 공간: 원점 = 손에 쥐는 점, +Y = 손잡이에서 끝(날·머리)으로 가는 방향, -Z = 날이 향하는 쪽.
	    손에 붙일 때 팔 끝(팔 공간 (0,-1,0))에서 X 로 -90° 돌려 붙인다 — 팔을 내리면 무기가 앞을 본다
	    (로블록스 기본 도구 쥐는 법과 같다).
	  - `Sockets.Tip`·`Sockets.Base` 는 궤적·이펙트가 나오는 점이다. 길이가 다른 무기도 이 두 점만
	    맞으면 궤적이 날 길이를 따라간다.
	  - 한 손/두 손/쌍수/떠 있음은 `Hold` 가 정한다. 두 손 무기는 오른손에 붙이고 왼손은 모션이 맞춘다.

	부품은 맵 양식(블록)대로 Part 로 짓는다: { 이름, 모양, 크기, 자리{x,y,z, rx,ry,rz(도)}, 색, 재질, 투명도?, 빛? }
]]

export type Part = {
	Name: string,
	Shape: "Block" | "Wedge" | "Ball" | "Cylinder",
	Size: { number },
	At: { number },
	Color: { number },
	Material: string,
	Transparency: number?,
}
export type Piece = {
	Hand: "Right" | "Left" | "Float",
	Parts: { Part },
	Sockets: { [string]: { number } },
	-- 궤적 색(없으면 궤적 없음)
	Trail: { number }?,
}
export type Weapon = {
	Id: string,
	Name: string,
	Type: string,
	Main: Piece,
	Off: Piece?,
	-- Float 무기(오브)의 개수·궤도
	Orbit: { Count: number, Radius: number, Height: number, Speed: number }?,
}

local STEEL = { 196, 202, 212 }
local STEEL_DK = { 88, 92, 104 }
local GOLD = { 212, 170, 84 }
local WOOD = { 104, 70, 44 }
local WOOD_DK = { 62, 42, 28 }
local LEATHER = { 70, 42, 30 }
local IRON = { 92, 86, 82 }

local function P(name: string, shape: any, size: { number }, at: { number }, color: { number }, material: string, transparency: number?): Part
	return { Name = name, Shape = shape, Size = size, At = at, Color = color, Material = material, Transparency = transparency }
end

local weapons: { [string]: Weapon } = {
	-- 음악가: 왼손 바이올린(턱에 괴는 악기) + 오른손 활
	Violin = {
		Id = "Violin",
		Name = "바이올린",
		Type = "Bowed",
		Main = {
			Hand = "Right",
			Parts = {
				P("BowStick", "Block", { 0.09, 2.9, 0.09 }, { 0, 1.2, 0, 0, 0, 0 }, WOOD_DK, "Wood"),
				P("BowHair", "Block", { 0.03, 2.6, 0.05 }, { 0, 1.25, -0.16, 0, 0, 0 }, { 236, 230, 214 }, "SmoothPlastic"),
				P("BowFrog", "Block", { 0.14, 0.34, 0.24 }, { 0, -0.1, -0.08, 0, 0, 0 }, { 30, 26, 24 }, "SmoothPlastic"),
				P("BowTip", "Block", { 0.12, 0.2, 0.2 }, { 0, 2.64, -0.08, 0, 0, 0 }, WOOD_DK, "Wood"),
			},
			Sockets = { Base = { 0, 0, -0.16 }, Tip = { 0, 2.6, -0.16 } },
			Trail = { 255, 214, 120 },
		},
		Off = {
			Hand = "Left",
			Parts = {
				P("Body", "Block", { 0.95, 1.4, 0.36 }, { 0, 0.55, 0, 0, 0, 0 }, { 158, 82, 36 }, "Wood"),
				P("Waist", "Block", { 0.62, 0.34, 0.36 }, { 0, 1.35, 0, 0, 0, 0 }, { 158, 82, 36 }, "Wood"),
				P("Upper", "Block", { 0.82, 0.6, 0.36 }, { 0, 1.75, 0, 0, 0, 0 }, { 158, 82, 36 }, "Wood"),
				P("Top", "Block", { 0.9, 1.9, 0.06 }, { 0, 1.12, -0.19, 0, 0, 0 }, { 176, 98, 46 }, "Wood"),
				P("Neck", "Block", { 0.18, 1.2, 0.14 }, { 0, 2.6, -0.14, 0, 0, 0 }, { 40, 30, 26 }, "SmoothPlastic"),
				P("Scroll", "Block", { 0.22, 0.34, 0.26 }, { 0, 3.3, -0.1, 0, 0, 0 }, { 120, 64, 30 }, "Wood"),
				P("Bridge", "Block", { 0.4, 0.12, 0.08 }, { 0, 0.85, -0.25, 0, 0, 0 }, { 230, 210, 170 }, "Wood"),
				P("Strings", "Block", { 0.14, 2.6, 0.02 }, { 0, 1.9, -0.25, 0, 0, 0 }, { 232, 226, 210 }, "Neon", 0.2),
				P("Chinrest", "Block", { 0.5, 0.2, 0.14 }, { 0.12, -0.12, -0.2, 0, 0, 0 }, { 30, 26, 24 }, "SmoothPlastic"),
				P("FHoleL", "Block", { 0.05, 0.45, 0.02 }, { -0.24, 1.0, -0.23, 0, 0, 12 }, { 20, 14, 10 }, "SmoothPlastic"),
				P("FHoleR", "Block", { 0.05, 0.45, 0.02 }, { 0.24, 1.0, -0.23, 0, 0, -12 }, { 20, 14, 10 }, "SmoothPlastic"),
			},
			Sockets = { Base = { 0, 0.9, -0.25 }, Tip = { 0, 3.3, -0.1 } },
		},
	},
	-- 결투사: 가는 레이피어(휘감긴 손보호 고리)
	Rapier = {
		Id = "Rapier",
		Name = "레이피어",
		Type = "Thrust1H",
		Main = {
			Hand = "Right",
			Parts = {
				P("Blade", "Block", { 0.1, 3.5, 0.05 }, { 0, 2.3, 0, 0, 0, 0 }, STEEL, "Metal"),
				P("Ricasso", "Block", { 0.14, 0.36, 0.08 }, { 0, 0.62, 0, 0, 0, 0 }, STEEL_DK, "Metal"),
				P("Point", "Wedge", { 0.05, 0.3, 0.1 }, { 0, 4.2, 0, 0, 0, 0 }, STEEL, "Metal"),
				P("Cross", "Block", { 1.1, 0.1, 0.1 }, { 0, 0.44, 0, 0, 0, 0 }, GOLD, "Metal"),
				P("RingA", "Block", { 0.08, 0.7, 0.08 }, { 0.3, 0.2, -0.22, 0, 0, 0 }, GOLD, "Metal"),
				P("RingB", "Block", { 0.5, 0.08, 0.08 }, { 0.12, -0.12, -0.22, 0, 0, 0 }, GOLD, "Metal"),
				P("Bow", "Block", { 0.08, 0.08, 0.48 }, { 0.3, 0.44, -0.12, 0, 0, 0 }, GOLD, "Metal"),
				P("Grip", "Block", { 0.2, 0.62, 0.2 }, { 0, 0.08, 0, 0, 45, 0 }, LEATHER, "Fabric"),
				P("Pommel", "Ball", { 0.3, 0.3, 0.3 }, { 0, -0.34, 0, 0, 0, 0 }, GOLD, "Metal"),
			},
			Sockets = { Base = { 0, 0.8, 0 }, Tip = { 0, 4.3, 0 } },
			Trail = { 214, 236, 255 },
		},
	},
	-- 퀘이사: 별빛이 흐르는 검은 대검(두 손)
	Greatsword = {
		Id = "Greatsword",
		Name = "사건의 지평 대검",
		Type = "Great2H",
		Main = {
			Hand = "Right",
			Parts = {
				P("Blade", "Block", { 0.72, 4.8, 0.2 }, { 0, 3.2, 0, 0, 0, 0 }, { 34, 34, 52 }, "Metal"),
				P("Edge", "Block", { 0.9, 4.6, 0.1 }, { 0, 3.2, 0, 0, 0, 0 }, { 70, 74, 104 }, "Metal"),
				P("Core", "Block", { 0.14, 4.2, 0.24 }, { 0, 3.3, 0, 0, 0, 0 }, { 140, 110, 255 }, "Neon"),
				P("Point", "Wedge", { 0.9, 0.7, 0.2 }, { 0, 5.95, 0, 0, 0, 0 }, { 70, 74, 104 }, "Metal"),
				P("Guard", "Block", { 1.9, 0.36, 0.4 }, { 0, 0.72, 0, 0, 0, 0 }, { 50, 48, 70 }, "Metal"),
				P("GuardGem", "Block", { 0.36, 0.36, 0.46 }, { 0, 0.72, 0, 0, 0, 45 }, { 170, 140, 255 }, "Neon"),
				P("Grip", "Block", { 0.28, 1.5, 0.28 }, { 0, -0.1, 0, 0, 0, 0 }, LEATHER, "Fabric"),
				P("Pommel", "Block", { 0.44, 0.44, 0.44 }, { 0, -0.95, 0, 0, 45, 45 }, { 50, 48, 70 }, "Metal"),
			},
			Sockets = { Base = { 0, 1.1, 0 }, Tip = { 0, 6.2, 0 } },
			Trail = { 150, 120, 255 },
		},
	},
	-- 펄서: 손에 쥐지 않고 몸 둘레를 도는 오브 셋
	Orbs = {
		Id = "Orbs",
		Name = "맥동 오브",
		Type = "Orbs",
		Main = {
			Hand = "Float",
			Parts = {
				P("Shell", "Ball", { 1.0, 1.0, 1.0 }, { 0, 0, 0, 0, 0, 0 }, { 110, 220, 255 }, "Glass", 0.35),
				P("Core", "Ball", { 0.52, 0.52, 0.52 }, { 0, 0, 0, 0, 0, 0 }, { 150, 240, 255 }, "Neon"),
				P("Band", "Block", { 1.18, 0.1, 0.1 }, { 0, 0, 0, 0, 0, 30 }, { 60, 110, 170 }, "Metal"),
			},
			Sockets = { Base = { 0, 0, 0 }, Tip = { 0, 0, 0 } },
			Trail = { 110, 220, 255 },
		},
		Orbit = { Count = 3, Radius = 2.6, Height = 1.6, Speed = 1.1 },
	},
	-- 월 필그림: 두 손에 쥔 석공용 큰 못(붉은 천을 감은 순례자의 못)
	PilgrimNails = {
		Id = "PilgrimNails",
		Name = "순례자의 못",
		Type = "Spike",
		Main = {
			Hand = "Right",
			Parts = {
				P("Shaft", "Block", { 0.28, 2.3, 0.28 }, { 0, 1.2, 0, 0, 0, 0 }, IRON, "CorrodedMetal"),
				P("Point", "Wedge", { 0.28, 0.5, 0.28 }, { 0, 2.6, 0, 0, 0, 0 }, IRON, "CorrodedMetal"),
				P("Head", "Block", { 0.7, 0.22, 0.7 }, { 0, -0.1, 0, 0, 45, 0 }, { 70, 66, 62 }, "CorrodedMetal"),
				P("Wrap", "Block", { 0.34, 0.5, 0.34 }, { 0, 0.35, 0, 0, 0, 0 }, { 140, 36, 36 }, "Fabric"),
				P("Ribbon", "Block", { 0.06, 0.9, 0.22 }, { 0.16, -0.2, 0.1, 0, 0, 14 }, { 150, 40, 40 }, "Fabric"),
			},
			Sockets = { Base = { 0, 0.4, 0 }, Tip = { 0, 2.85, 0 } },
			Trail = { 255, 190, 150 },
		},
		Off = {
			Hand = "Left",
			Parts = {
				P("Shaft", "Block", { 0.26, 2.0, 0.26 }, { 0, 1.05, 0, 0, 0, 0 }, IRON, "CorrodedMetal"),
				P("Point", "Wedge", { 0.26, 0.45, 0.26 }, { 0, 2.28, 0, 0, 0, 0 }, IRON, "CorrodedMetal"),
				P("Head", "Block", { 0.64, 0.2, 0.64 }, { 0, -0.1, 0, 0, 45, 0 }, { 70, 66, 62 }, "CorrodedMetal"),
				P("Wrap", "Block", { 0.32, 0.46, 0.32 }, { 0, 0.32, 0, 0, 0, 0 }, { 140, 36, 36 }, "Fabric"),
			},
			Sockets = { Base = { 0, 0.4, 0 }, Tip = { 0, 2.5, 0 } },
			Trail = { 255, 190, 150 },
		},
	},
	-- 월 메이슨: 오른손 석공 망치 + 왼손 정
	MasonHammer = {
		Id = "MasonHammer",
		Name = "석공 망치",
		Type = "Hammer1H",
		Main = {
			Hand = "Right",
			Parts = {
				P("Handle", "Block", { 0.24, 2.5, 0.24 }, { 0, 0.8, 0, 0, 0, 0 }, WOOD, "Wood"),
				P("Head", "Block", { 0.62, 0.62, 1.5 }, { 0, 2.1, 0, 0, 0, 0 }, { 120, 118, 112 }, "Slate"),
				P("Face", "Block", { 0.7, 0.7, 0.18 }, { 0, 2.1, -0.8, 0, 0, 0 }, STEEL_DK, "Metal"),
				P("Peen", "Wedge", { 0.5, 0.5, 0.5 }, { 0, 2.1, 0.95, 90, 0, 0 }, STEEL_DK, "Metal"),
				P("Band", "Block", { 0.3, 0.2, 0.3 }, { 0, 1.62, 0, 0, 0, 0 }, STEEL_DK, "Metal"),
				P("Grip", "Block", { 0.3, 0.6, 0.3 }, { 0, -0.2, 0, 0, 0, 0 }, LEATHER, "Fabric"),
			},
			Sockets = { Base = { 0, 1.6, 0 }, Tip = { 0, 2.1, -0.9 } },
			Trail = { 230, 222, 200 },
		},
		Off = {
			Hand = "Left",
			Parts = {
				P("Chisel", "Block", { 0.2, 1.2, 0.2 }, { 0, 0.6, 0, 0, 0, 0 }, STEEL, "Metal"),
				P("Bit", "Wedge", { 0.2, 0.3, 0.3 }, { 0, 1.35, 0, 0, 0, 0 }, STEEL, "Metal"),
				P("Cap", "Block", { 0.28, 0.2, 0.28 }, { 0, -0.1, 0, 0, 0, 0 }, STEEL_DK, "Metal"),
			},
			Sockets = { Base = { 0, 0, 0 }, Tip = { 0, 1.45, 0 } },
		},
	},
	-- 월 브레이커: 곡괭이 모양 지팡이(두 손)
	PickStaff = {
		Id = "PickStaff",
		Name = "허무는 곡괭이 지팡이",
		Type = "Polearm2H",
		Main = {
			Hand = "Right",
			Parts = {
				P("Staff", "Block", { 0.3, 5.4, 0.3 }, { 0, 1.3, 0, 0, 0, 0 }, WOOD_DK, "Wood"),
				P("WrapA", "Block", { 0.36, 0.5, 0.36 }, { 0, 0.1, 0, 0, 0, 0 }, LEATHER, "Fabric"),
				P("WrapB", "Block", { 0.36, 0.3, 0.36 }, { 0, 3.3, 0, 0, 0, 0 }, { 150, 132, 96 }, "Fabric"),
				P("Socket", "Block", { 0.5, 0.6, 0.5 }, { 0, 4.0, 0, 0, 0, 0 }, IRON, "Metal"),
				P("PickF", "Block", { 0.3, 0.32, 1.7 }, { 0, 4.05, -0.95, -8, 0, 0 }, IRON, "Metal"),
				P("PickFTip", "Wedge", { 0.3, 0.32, 0.6 }, { 0, 3.95, -2.0, 172, 0, 0 }, STEEL, "Metal"),
				P("PickB", "Block", { 0.3, 0.3, 1.2 }, { 0, 4.05, 0.7, 8, 0, 0 }, IRON, "Metal"),
				P("PickBTip", "Wedge", { 0.3, 0.3, 0.5 }, { 0, 3.98, 1.45, -8, 0, 0 }, STEEL, "Metal"),
				P("Crystal", "Block", { 0.34, 0.5, 0.34 }, { 0, 4.55, 0, 0, 45, 0 }, { 255, 160, 90 }, "Neon"),
				P("Butt", "Block", { 0.38, 0.4, 0.38 }, { 0, -1.35, 0, 0, 45, 0 }, IRON, "Metal"),
			},
			Sockets = { Base = { 0, 3.6, 0 }, Tip = { 0, 4.0, -2.2 } },
			Trail = { 255, 170, 100 },
		},
	},
	-- 연금술사: 오른손 약병(던지면 새 병이 손에 다시 생긴다)
	Flask = {
		Id = "Flask",
		Name = "연금 약병",
		Type = "Throwable",
		Main = {
			Hand = "Right",
			Parts = {
				-- 전투 카메라(멀리 옆에서 봄)에서 보이도록 실제보다 크게 만든다
				P("Glass", "Block", { 0.86, 0.96, 0.86 }, { 0, 0.4, -0.05, 0, 45, 0 }, { 200, 236, 230 }, "Glass", 0.45),
				P("Liquid", "Block", { 0.68, 0.6, 0.68 }, { 0, 0.24, -0.05, 0, 45, 0 }, { 120, 230, 110 }, "Neon", 0.1),
				P("Neck", "Block", { 0.3, 0.46, 0.3 }, { 0, 1.1, -0.05, 0, 0, 0 }, { 200, 236, 230 }, "Glass", 0.4),
				P("Cork", "Block", { 0.36, 0.26, 0.36 }, { 0, 1.44, -0.05, 0, 0, 0 }, { 150, 110, 70 }, "Wood"),
			},
			Sockets = { Base = { 0, 0.4, -0.05 }, Tip = { 0, 1.44, -0.05 } },
		},
		Off = {
			Hand = "Left",
			Parts = {
				P("Glass", "Block", { 0.66, 0.74, 0.66 }, { 0, 0.3, -0.05, 0, 0, 0 }, { 200, 236, 230 }, "Glass", 0.45),
				P("Liquid", "Block", { 0.52, 0.44, 0.52 }, { 0, 0.18, -0.05, 0, 0, 0 }, { 255, 120, 60 }, "Neon", 0.1),
				P("Neck", "Block", { 0.26, 0.4, 0.26 }, { 0, 0.86, -0.05, 0, 0, 0 }, { 200, 236, 230 }, "Glass", 0.4),
				P("Cork", "Block", { 0.3, 0.2, 0.3 }, { 0, 1.14, -0.05, 0, 0, 0 }, { 150, 110, 70 }, "Wood"),
			},
			Sockets = { Base = { 0, 0.3, -0.05 }, Tip = { 0, 1.14, -0.05 } },
		},
	},
	-- 광전사: 핏빛 룬이 새겨진 양손 도끼
	Greataxe = {
		Id = "Greataxe",
		Name = "피의 양손 도끼",
		Type = "Axe2H",
		Main = {
			Hand = "Right",
			Parts = {
				P("Haft", "Block", { 0.3, 4.6, 0.3 }, { 0, 1.2, 0, 0, 0, 0 }, WOOD_DK, "Wood"),
				P("Grip", "Block", { 0.36, 1.0, 0.36 }, { 0, 0.0, 0, 0, 0, 0 }, LEATHER, "Fabric"),
				P("HeadCore", "Block", { 0.4, 1.2, 0.5 }, { 0, 3.2, 0, 0, 0, 0 }, STEEL_DK, "Metal"),
				P("BitF", "Block", { 0.14, 1.8, 1.3 }, { 0, 3.2, -0.85, 0, 0, 0 }, STEEL, "Metal"),
				P("BitFEdge", "Wedge", { 0.14, 1.9, 0.5 }, { 0, 3.2, -1.7, 0, 180, 0 }, { 226, 230, 236 }, "Metal"),
				P("BitB", "Block", { 0.14, 1.3, 0.9 }, { 0, 3.2, 0.62, 0, 0, 0 }, STEEL, "Metal"),
				P("Rune", "Block", { 0.18, 0.5, 0.5 }, { 0, 3.2, -0.85, 0, 0, 45 }, { 255, 50, 40 }, "Neon"),
				P("Spike", "Wedge", { 0.26, 0.6, 0.26 }, { 0, 4.1, 0, 0, 0, 0 }, STEEL_DK, "Metal"),
				P("Pommel", "Block", { 0.4, 0.34, 0.4 }, { 0, -1.05, 0, 0, 45, 0 }, STEEL_DK, "Metal"),
			},
			Sockets = { Base = { 0, 2.6, -0.8 }, Tip = { 0, 3.8, -1.8 } },
			Trail = { 255, 70, 50 },
		},
	},
}

-- 직업 → 기본 무기(탑에서는 이것을 자동으로 든다: 추가&수정.md `#### 탑 시스템`)
local classWeapon: { [string]: string } = {
	Musician = "Violin",
	Duelist = "Rapier",
	Quasar = "Greatsword",
	Pulsar = "Orbs",
	WallPilgrim = "PilgrimNails",
	WallMason = "MasonHammer",
	WallBreaker = "PickStaff",
	Alchemist = "Flask",
	Berserker = "Greataxe",
}

local WeaponDefinitions = {}

function WeaponDefinitions.Get(id: string): Weapon?
	return weapons[id]
end

function WeaponDefinitions.ForClass(classId: string): Weapon
	return weapons[classWeapon[classId] or "Rapier"] or weapons.Rapier
end

function WeaponDefinitions.All(): { [string]: Weapon }
	return weapons
end

-- 이 직업의 모션이 만들어진 무기 종류(무기를 바꿔 들어도 이 종류면 직업 모션을 그대로 쓴다)
function WeaponDefinitions.ClassType(classId: string): string
	return WeaponDefinitions.ForClass(classId).Type
end

return WeaponDefinitions
