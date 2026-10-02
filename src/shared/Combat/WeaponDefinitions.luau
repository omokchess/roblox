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

	**블렌더 메시(2026-10-02 사용자: 무기는 블렌더로)**: models/weapons/build_weapons.py 가 이 Part 정의를 설계도로
	곡면·디테일 메시를 짓는다(치수·쥐는 점·소켓 그대로). 스튜디오에서 tools/WeaponMeshes.luau 가
	ReplicatedStorage.WeaponMeshes.<무기Id>.<Main|Off> 로 정리하면 CombatWeapons 가 그 메시를 쓰고, 묶음마다 Skins 의 색·재질을 입힌다.
	메시가 없으면(가져오기 실패 등) 지금처럼 Parts 로 짓는다.
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
-- 블렌더 메시 묶음 하나의 겉(models/weapons/build_weapons.py 의 묶음 이름과 같다)
export type Skin = { Color: { number }, Material: string, Transparency: number? }
export type Piece = {
	Hand: "Right" | "Left" | "Float",
	Parts: { Part },
	-- 블렌더 메시가 있을 때(ReplicatedStorage.WeaponMeshes.<무기Id>.<Main|Off>) 묶음마다 입힐 색·재질. 없으면 Parts 로 짓는다
	Skins: { [string]: Skin }?,
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
local VARNISH = { 128, 58, 26 }
local SPRUCE = { 176, 96, 42 }
local MAPLE = { 150, 92, 50 }
local EBONY = { 28, 24, 22 }
local VOID = { 50, 48, 70 }

local function P(name: string, shape: any, size: { number }, at: { number }, color: { number }, material: string, transparency: number?): Part
	return { Name = name, Shape = shape, Size = size, At = at, Color = color, Material = material, Transparency = transparency }
end

local function S(color: { number }, material: string, transparency: number?): Skin
	return { Color = color, Material = material, Transparency = transparency }
end

local weapons: { [string]: Weapon } = {
	-- 음악가: 왼손 바이올린(턱에 괴는 악기) + 오른손 활. (2026-09-30 다시 만듦)
	--   실제 비율(전체 59cm·몸통 35.5cm·아래/위 울림통 20.8/16.8cm·허리 11cm, 활 75cm)을 R6 몸에 맞게 줄였다
	--   (곧은 팔이 목을 쥐면서 바닥이 목에 닿으려면 바닥→쥔 점 1.55 스터드).
	--   원점 = 왼손이 쥐는 목, +Y = 스크롤 쪽, -Z = 윗판(줄) 쪽, +X = 연주자 왼쪽(턱받침 쪽).
	--   울림통은 원통을 눕혀 둥근 판으로(아래·위 울림통), 허리(C 바우트)는 상자.
	Violin = {
		Id = "Violin",
		Name = "바이올린",
		Type = "Bowed",
		Main = {
			Hand = "Right",
			Parts = {
				P("Stick", "Block", { 0.06, 2.95, 0.06 }, { 0, 1.17, 0, 0, 0, 0 }, { 118, 52, 28 }, "Wood"),
				P("Winding", "Block", { 0.075, 0.26, 0.075 }, { 0, 0.14, 0, 0, 0, 0 }, { 200, 200, 206 }, "Metal"),
				P("Frog", "Block", { 0.09, 0.3, 0.18 }, { 0, -0.12, -0.09, 0, 0, 0 }, { 28, 24, 22 }, "SmoothPlastic"),
				P("FrogEye", "Block", { 0.1, 0.06, 0.06 }, { 0, -0.12, -0.1, 0, 0, 0 }, { 236, 236, 226 }, "SmoothPlastic"),
				P("Button", "Block", { 0.08, 0.1, 0.08 }, { 0, -0.34, 0, 0, 0, 0 }, { 200, 200, 206 }, "Metal"),
				P("Head", "Block", { 0.07, 0.2, 0.16 }, { 0, 2.7, -0.07, 0, 0, 0 }, { 118, 52, 28 }, "Wood"),
				P("TipPlate", "Block", { 0.072, 0.04, 0.16 }, { 0, 2.61, -0.07, 0, 0, 0 }, { 240, 236, 222 }, "SmoothPlastic"),
				P("Hair", "Block", { 0.06, 2.62, 0.012 }, { 0, 1.33, -0.16, 0, 0, 0 }, { 236, 230, 214 }, "SmoothPlastic"),
			},
			Sockets = { Base = { 0, 0.1, -0.16 }, Tip = { 0, 2.6, -0.16 } },
			Skins = { Wood = S({ 118, 52, 28 }, "Wood"), Ebony = S(EBONY, "SmoothPlastic"), Silver = S({ 200, 200, 206 }, "Metal"), Hair = S({ 236, 230, 214 }, "SmoothPlastic") },
			Trail = { 255, 214, 120 },
		},
		Off = {
			Hand = "Left",
			Parts = {
				P("LowerBout", "Cylinder", { 0.22, 0.78, 0.78 }, { 0, -1.16, 0, 0, 90, 0 }, VARNISH, "Wood"),
				P("Waist", "Block", { 0.44, 0.32, 0.22 }, { 0, -0.8, 0, 0, 0, 0 }, VARNISH, "Wood"),
				P("UpperBout", "Cylinder", { 0.22, 0.64, 0.64 }, { 0, -0.53, 0, 0, 90, 0 }, VARNISH, "Wood"),
				P("TopLower", "Cylinder", { 0.03, 0.72, 0.72 }, { 0, -1.16, -0.11, 0, 90, 0 }, SPRUCE, "Wood"),
				P("TopWaist", "Block", { 0.4, 0.32, 0.03 }, { 0, -0.8, -0.11, 0, 0, 0 }, SPRUCE, "Wood"),
				P("TopUpper", "Cylinder", { 0.03, 0.58, 0.58 }, { 0, -0.53, -0.11, 0, 90, 0 }, SPRUCE, "Wood"),
				P("FHoleL", "Block", { 0.035, 0.22, 0.02 }, { 0.15, -0.85, -0.125, 0, 0, 10 }, EBONY, "SmoothPlastic"),
				P("FHoleR", "Block", { 0.035, 0.22, 0.02 }, { -0.15, -0.85, -0.125, 0, 0, -10 }, EBONY, "SmoothPlastic"),
				P("Tailpiece", "Block", { 0.15, 0.34, 0.04 }, { 0, -1.3, -0.145, 0, 0, 0 }, EBONY, "SmoothPlastic"),
				P("Chinrest", "Block", { 0.3, 0.1, 0.12 }, { 0.13, -1.49, -0.16, 0, 0, 0 }, EBONY, "SmoothPlastic"),
				P("Bridge", "Block", { 0.24, 0.035, 0.1 }, { 0, -0.91, -0.175, 0, 0, 0 }, { 226, 200, 150 }, "Wood"),
				P("Fingerboard", "Block", { 0.12, 0.9, 0.05 }, { 0, -0.2, -0.15, 0, 0, 0 }, EBONY, "SmoothPlastic"),
				P("Neck", "Block", { 0.1, 0.48, 0.11 }, { 0, 0.0, -0.02, 0, 0, 0 }, MAPLE, "Wood"),
				P("Pegbox", "Block", { 0.11, 0.24, 0.12 }, { 0, 0.37, -0.02, 0, 0, 0 }, MAPLE, "Wood"),
				P("PegA", "Block", { 0.28, 0.035, 0.035 }, { 0, 0.32, 0, 0, 0, 0 }, EBONY, "SmoothPlastic"),
				P("PegB", "Block", { 0.28, 0.035, 0.035 }, { 0, 0.42, 0, 0, 0, 0 }, EBONY, "SmoothPlastic"),
				P("Scroll", "Cylinder", { 0.11, 0.16, 0.16 }, { 0, 0.53, -0.03, 0, 0, 0 }, MAPLE, "Wood"),
				P("Strings", "Block", { 0.07, 1.55, 0.012 }, { 0, -0.5, -0.19, 0, 0, 0 }, { 232, 226, 210 }, "Neon", 0.3),
			},
			Sockets = { Base = { 0, -0.85, -0.2 }, Tip = { 0, 0.53, -0.03 } },
			Skins = { Varnish = S(VARNISH, "Wood"), Spruce = S(SPRUCE, "Wood"), Maple = S(MAPLE, "Wood"), Ebony = S(EBONY, "SmoothPlastic"), Bridge = S({ 226, 200, 150 }, "Wood"), Strings = S({ 232, 226, 210 }, "Neon", 0.3) },
		},
	},
	-- 결투사: 17세기 스웹트 힐트 레이피어(카포 페로 시대) — 가늘고 긴 찌르기 날, 십자 날밑, 너클 보우(-Z 쪽 = 칼날 쪽).
	-- 컵 가드(동그란 손 보호대)는 없앰(2026-10-02 사용자)
	Rapier = {
		Id = "Rapier",
		Name = "레이피어",
		Type = "Thrust1H",
		Main = {
			Hand = "Right",
			Parts = {
				P("Blade", "Block", { 0.09, 3.62, 0.05 }, { 0, 2.45, 0, 0, 0, 0 }, STEEL, "Metal"),
				P("Fuller", "Block", { 0.03, 3.0, 0.06 }, { 0, 2.3, 0, 0, 0, 0 }, STEEL_DK, "Metal"),
				P("PointR", "Wedge", { 0.05, 0.34, 0.045 }, { 0.0225, 4.43, 0, 0, -90, 0 }, STEEL, "Metal"),
				P("PointL", "Wedge", { 0.05, 0.34, 0.045 }, { -0.0225, 4.43, 0, 0, 90, 0 }, STEEL, "Metal"),
				P("Ricasso", "Block", { 0.12, 0.3, 0.07 }, { 0, 0.62, 0, 0, 0, 0 }, STEEL_DK, "Metal"),
				P("Quillons", "Block", { 1.16, 0.08, 0.08 }, { 0, 0.44, 0, 0, 0, 0 }, GOLD, "Metal"),
				P("QuillonL", "Ball", { 0.14, 0.14, 0.14 }, { -0.6, 0.44, 0, 0, 0, 0 }, GOLD, "Metal"),
				P("QuillonR", "Ball", { 0.14, 0.14, 0.14 }, { 0.6, 0.44, 0, 0, 0, 0 }, GOLD, "Metal"),
				P("KnuckleBow", "Block", { 0.06, 0.92, 0.06 }, { 0, 0, -0.3, 0, 0, 0 }, GOLD, "Metal"),
				P("BowTop", "Block", { 0.06, 0.06, 0.3 }, { 0, 0.44, -0.15, 0, 0, 0 }, GOLD, "Metal"),
				P("BowBottom", "Block", { 0.06, 0.06, 0.3 }, { 0, -0.44, -0.15, 0, 0, 0 }, GOLD, "Metal"),
				P("Grip", "Block", { 0.17, 0.62, 0.17 }, { 0, 0.02, 0, 0, 45, 0 }, { 40, 34, 30 }, "Fabric"),
				P("WireA", "Block", { 0.19, 0.05, 0.19 }, { 0, 0.2, 0, 0, 45, 0 }, GOLD, "Metal"),
				P("WireB", "Block", { 0.19, 0.05, 0.19 }, { 0, -0.16, 0, 0, 45, 0 }, GOLD, "Metal"),
				P("Pommel", "Ball", { 0.3, 0.3, 0.3 }, { 0, -0.44, 0, 0, 0, 0 }, GOLD, "Metal"),
			},
			Sockets = { Base = { 0, 0.8, 0 }, Tip = { 0, 4.55, 0 } },
			Skins = { Steel = S(STEEL, "Metal"), Gold = S(GOLD, "Metal"), Grip = S({ 40, 34, 30 }, "Fabric") },
			Trail = { 214, 236, 255 },
		},
	},
	-- 퀘이사: 별빛이 흐르는 검은 츠바이핸더(두 손) — 긴 손잡이·가운데 고리, 끝이 처진 큰 십자 가드,
	-- 가죽 감은 리카소와 그 위 패링 훅(파리어하켄), 가운데 보라 빛줄기
	Greatsword = {
		Id = "Greatsword",
		Name = "사건의 지평 대검",
		Type = "Great2H",
		Main = {
			Hand = "Right",
			Parts = {
				P("Pommel", "Ball", { 0.5, 0.5, 0.5 }, { 0, -1.02, 0, 0, 0, 0 }, VOID, "Metal"),
				P("PommelCap", "Block", { 0.22, 0.16, 0.22 }, { 0, -1.3, 0, 0, 45, 0 }, VOID, "Metal"),
				P("Grip", "Block", { 0.3, 1.52, 0.3 }, { 0, -0.1, 0, 0, 0, 0 }, LEATHER, "Fabric"),
				P("GripCollar", "Block", { 0.36, 0.14, 0.36 }, { 0, -0.28, 0, 0, 0, 0 }, VOID, "Metal"),
				P("Cross", "Block", { 2.1, 0.24, 0.3 }, { 0, 0.77, 0, 0, 0, 0 }, VOID, "Metal"),
				P("QuillonL", "Block", { 0.26, 0.4, 0.3 }, { -1.12, 0.62, 0, 0, 0, -24 }, VOID, "Metal"),
				P("QuillonR", "Block", { 0.26, 0.4, 0.3 }, { 1.12, 0.62, 0, 0, 0, 24 }, VOID, "Metal"),
				P("GuardGem", "Block", { 0.36, 0.36, 0.44 }, { 0, 0.77, 0, 0, 0, 45 }, { 170, 140, 255 }, "Neon"),
				P("Ricasso", "Block", { 0.44, 0.9, 0.24 }, { 0, 1.35, 0, 0, 0, 0 }, LEATHER, "Fabric"),
				P("HookL", "Block", { 0.36, 0.12, 0.18 }, { -0.36, 1.86, 0, 0, 0, 30 }, VOID, "Metal"),
				P("HookR", "Block", { 0.36, 0.12, 0.18 }, { 0.36, 1.86, 0, 0, 0, -30 }, VOID, "Metal"),
				P("Blade", "Block", { 0.74, 4.3, 0.2 }, { 0, 4.05, 0, 0, 0, 0 }, { 34, 34, 52 }, "Metal"),
				P("Edge", "Block", { 0.9, 4.2, 0.1 }, { 0, 4.0, 0, 0, 0, 0 }, { 70, 74, 104 }, "Metal"),
				P("Core", "Block", { 0.14, 3.8, 0.24 }, { 0, 3.95, 0, 0, 0, 0 }, { 140, 110, 255 }, "Neon"),
				P("PointR", "Wedge", { 0.2, 0.7, 0.45 }, { 0.225, 6.55, 0, 0, -90, 0 }, { 70, 74, 104 }, "Metal"),
				P("PointL", "Wedge", { 0.2, 0.7, 0.45 }, { -0.225, 6.55, 0, 0, 90, 0 }, { 70, 74, 104 }, "Metal"),
			},
			Sockets = { Base = { 0, 2.0, 0 }, Tip = { 0, 6.8, 0 } },
			Skins = { Void = S(VOID, "Metal"), Leather = S(LEATHER, "Fabric"), Gem = S({ 170, 140, 255 }, "Neon"), Blade = S({ 34, 34, 52 }, "Metal"), Edge = S({ 70, 74, 104 }, "Metal"), Core = S({ 140, 110, 255 }, "Neon") },
			Trail = { 150, 120, 255 },
		},
	},
	-- 펄서: 손에 쥐지 않고 몸 둘레를 도는 오브 셋(유리 껍질 + 빛 핵 + 엇갈린 두 띠)
	Orbs = {
		Id = "Orbs",
		Name = "맥동 오브",
		Type = "Orbs",
		Main = {
			Hand = "Float",
			Parts = {
				P("Shell", "Ball", { 1.0, 1.0, 1.0 }, { 0, 0, 0, 0, 0, 0 }, { 110, 220, 255 }, "Glass", 0.35),
				P("Core", "Ball", { 0.52, 0.52, 0.52 }, { 0, 0, 0, 0, 0, 0 }, { 150, 240, 255 }, "Neon"),
				P("Band", "Block", { 1.18, 0.08, 0.08 }, { 0, 0, 0, 0, 0, 30 }, { 60, 110, 170 }, "Metal"),
				P("Band2", "Block", { 0.08, 0.08, 1.18 }, { 0, 0, 0, 30, 0, 0 }, { 60, 110, 170 }, "Metal"),
			},
			Sockets = { Base = { 0, 0, 0 }, Tip = { 0, 0, 0 } },
			Skins = { Shell = S({ 110, 220, 255 }, "Glass", 0.35), Core = S({ 150, 240, 255 }, "Neon"), Band = S({ 60, 110, 170 }, "Metal") },
			Trail = { 110, 220, 255 },
		},
		Orbit = { Count = 3, Radius = 2.6, Height = 1.6, Speed = 1.1 },
	},
	-- 월 필그림: 두 손에 **거꾸로(얼음송곳 쥠)** 쥔 대장간 못 — 장미 머리(각진 머리)가 주먹 위, 네모 몸이 가늘어지며
	-- 새끼손가락 쪽으로 뾰족하게. 쥔 자리는 붉은 천으로 감고, 머리에 붉은 끈이 늘어진다(순례자의 표식)
	PilgrimNails = {
		Id = "PilgrimNails",
		Name = "순례자의 못",
		Type = "Spike",
		Main = {
			Hand = "Right",
			Parts = {
				P("Head", "Block", { 0.62, 0.16, 0.62 }, { 0, -0.38, 0, 0, 45, 0 }, { 70, 66, 62 }, "CorrodedMetal"),
				P("HeadTop", "Block", { 0.36, 0.1, 0.36 }, { 0, -0.48, 0, 0, 45, 0 }, { 84, 78, 72 }, "CorrodedMetal"),
				P("Wrap", "Block", { 0.34, 0.62, 0.34 }, { 0, 0, 0, 0, 0, 0 }, { 140, 36, 36 }, "Fabric"),
				P("Shaft", "Block", { 0.26, 1.5, 0.26 }, { 0, 1.05, 0, 0, 0, 0 }, IRON, "CorrodedMetal"),
				P("ShaftLow", "Block", { 0.19, 0.7, 0.19 }, { 0, 2.1, 0, 0, 0, 0 }, IRON, "CorrodedMetal"),
				P("PointR", "Wedge", { 0.19, 0.42, 0.095 }, { 0.0475, 2.66, 0, 0, -90, 0 }, IRON, "CorrodedMetal"),
				P("PointL", "Wedge", { 0.19, 0.42, 0.095 }, { -0.0475, 2.66, 0, 0, 90, 0 }, IRON, "CorrodedMetal"),
				P("Ribbon", "Block", { 0.05, 0.9, 0.18 }, { 0.2, 0.05, 0.1, 0, 0, -8 }, { 150, 40, 40 }, "Fabric"),
			},
			Sockets = { Base = { 0, 0.4, 0 }, Tip = { 0, 2.85, 0 } },
			Skins = { Head = S({ 70, 66, 62 }, "CorrodedMetal"), Iron = S(IRON, "CorrodedMetal"), Cloth = S({ 140, 36, 36 }, "Fabric") },
			Trail = { 255, 190, 150 },
		},
		Off = {
			Hand = "Left",
			Parts = {
				P("Head", "Block", { 0.58, 0.15, 0.58 }, { 0, -0.36, 0, 0, 45, 0 }, { 70, 66, 62 }, "CorrodedMetal"),
				P("HeadTop", "Block", { 0.33, 0.09, 0.33 }, { 0, -0.46, 0, 0, 45, 0 }, { 84, 78, 72 }, "CorrodedMetal"),
				P("Wrap", "Block", { 0.32, 0.58, 0.32 }, { 0, 0, 0, 0, 0, 0 }, { 140, 36, 36 }, "Fabric"),
				P("Shaft", "Block", { 0.24, 1.3, 0.24 }, { 0, 0.95, 0, 0, 0, 0 }, IRON, "CorrodedMetal"),
				P("ShaftLow", "Block", { 0.18, 0.62, 0.18 }, { 0, 1.88, 0, 0, 0, 0 }, IRON, "CorrodedMetal"),
				P("PointR", "Wedge", { 0.18, 0.38, 0.09 }, { 0.045, 2.37, 0, 0, -90, 0 }, IRON, "CorrodedMetal"),
				P("PointL", "Wedge", { 0.18, 0.38, 0.09 }, { -0.045, 2.37, 0, 0, 90, 0 }, IRON, "CorrodedMetal"),
			},
			Sockets = { Base = { 0, 0.4, 0 }, Tip = { 0, 2.55, 0 } },
			Skins = { Head = S({ 70, 66, 62 }, "CorrodedMetal"), Iron = S(IRON, "CorrodedMetal"), Cloth = S({ 140, 36, 36 }, "Fabric") },
			Trail = { 255, 190, 150 },
		},
	},
	-- 월 메이슨: 오른손 석공 망치(짧은 자루 끝을 쥠, 네모 타격면 + 반대쪽 쐐기 날) + 왼손 정(버섯처럼 뭉개진 머리를
	-- 엄지 쪽 위로, 날은 새끼손가락 쪽 아래로 — 정은 가운데를 쥐고 머리를 망치로 친다)
	MasonHammer = {
		Id = "MasonHammer",
		Name = "석공 망치",
		Type = "Hammer1H",
		Main = {
			Hand = "Right",
			Parts = {
				P("Grip", "Block", { 0.28, 0.7, 0.28 }, { 0, 0, 0, 0, 0, 0 }, LEATHER, "Fabric"),
				P("Handle", "Block", { 0.22, 2.2, 0.22 }, { 0, 0.95, 0, 0, 0, 0 }, WOOD, "Wood"),
				P("Knob", "Block", { 0.3, 0.16, 0.3 }, { 0, -0.42, 0, 0, 0, 0 }, WOOD_DK, "Wood"),
				P("Band", "Block", { 0.3, 0.18, 0.3 }, { 0, 1.86, 0, 0, 0, 0 }, STEEL_DK, "Metal"),
				P("Head", "Block", { 0.56, 0.56, 1.3 }, { 0, 2.2, 0, 0, 0, 0 }, { 120, 118, 112 }, "Metal"),
				P("Face", "Block", { 0.66, 0.66, 0.16 }, { 0, 2.2, -0.72, 0, 0, 0 }, STEEL_DK, "Metal"),
				P("PeenTop", "Wedge", { 0.56, 0.28, 0.5 }, { 0, 2.34, 0.9, 0, 180, 0 }, STEEL_DK, "Metal"),
				P("PeenLow", "Wedge", { 0.56, 0.28, 0.5 }, { 0, 2.06, 0.9, 180, 0, 0 }, STEEL_DK, "Metal"),
			},
			Sockets = { Base = { 0, 1.6, 0 }, Tip = { 0, 2.2, -0.8 } },
			Skins = { Wood = S(WOOD, "Wood"), Leather = S(LEATHER, "Fabric"), Head = S({ 120, 118, 112 }, "Metal"), Dark = S(STEEL_DK, "Metal") },
			Trail = { 230, 222, 200 },
		},
		Off = {
			Hand = "Left",
			Parts = {
				P("Shaft", "Block", { 0.18, 1.3, 0.18 }, { 0, -0.05, 0, 0, 45, 0 }, STEEL, "Metal"),
				P("Grip", "Block", { 0.22, 0.4, 0.22 }, { 0, 0, 0, 0, 45, 0 }, LEATHER, "Fabric"),
				P("Cap", "Block", { 0.27, 0.14, 0.27 }, { 0, 0.64, 0, 0, 0, 0 }, STEEL_DK, "Metal"),
				P("Bit", "Wedge", { 0.2, 0.32, 0.2 }, { 0, -0.86, 0, 0, 0, 0 }, STEEL, "Metal"),
			},
			Sockets = { Base = { 0, 0, 0 }, Tip = { 0, -1.02, -0.1 } },
			Skins = { Steel = S(STEEL, "Metal"), Dark = S(STEEL_DK, "Metal"), Leather = S(LEATHER, "Fabric") },
		},
	},
	-- 월 브레이커: 곡괭이 머리를 단 쿼터스태프(두 손) — 앞 곡괭이 날(살짝 아래로 굽음) + 뒤 망치 면,
	-- 머리를 잡아 주는 쇠띠(랑겟), 끝의 쇠 물미, 손 자리마다 감은 가죽
	PickStaff = {
		Id = "PickStaff",
		Name = "허무는 곡괭이 지팡이",
		Type = "Polearm2H",
		Main = {
			Hand = "Right",
			Parts = {
				P("Staff", "Block", { 0.28, 5.4, 0.28 }, { 0, 1.3, 0, 0, 0, 0 }, WOOD_DK, "Wood"),
				P("WrapA", "Block", { 0.34, 0.6, 0.34 }, { 0, 0.05, 0, 0, 0, 0 }, LEATHER, "Fabric"),
				P("WrapB", "Block", { 0.34, 0.5, 0.34 }, { 0, 1.35, 0, 0, 0, 0 }, LEATHER, "Fabric"),
				P("Binding", "Block", { 0.34, 0.24, 0.34 }, { 0, 3.3, 0, 0, 0, 0 }, { 150, 132, 96 }, "Fabric"),
				P("LangetF", "Block", { 0.06, 0.8, 0.32 }, { 0, 3.55, 0, 0, 0, 0 }, IRON, "Metal"),
				P("Socket", "Block", { 0.46, 0.56, 0.46 }, { 0, 4.0, 0, 0, 0, 0 }, IRON, "Metal"),
				P("PickF", "Block", { 0.26, 0.3, 1.2 }, { 0, 4.06, -0.78, -4, 0, 0 }, IRON, "Metal"),
				P("PickF2", "Block", { 0.22, 0.26, 0.7 }, { 0, 3.94, -1.66, -16, 0, 0 }, IRON, "Metal"),
				P("PickFTip", "Wedge", { 0.22, 0.26, 0.4 }, { 0, 3.8, -2.16, 164, 0, 0 }, STEEL, "Metal"),
				P("PickB", "Block", { 0.34, 0.34, 0.7 }, { 0, 4.02, 0.55, 0, 0, 0 }, IRON, "Metal"),
				P("PickBFace", "Block", { 0.42, 0.42, 0.12 }, { 0, 4.02, 0.94, 0, 0, 0 }, STEEL, "Metal"),
				P("Crystal", "Block", { 0.3, 0.46, 0.3 }, { 0, 4.5, 0, 0, 45, 0 }, { 255, 160, 90 }, "Neon"),
				P("Ferrule", "Block", { 0.34, 0.3, 0.34 }, { 0, -1.3, 0, 0, 0, 0 }, IRON, "Metal"),
				P("ButtSpike", "Wedge", { 0.24, 0.3, 0.24 }, { 0, -1.58, 0, 180, 0, 0 }, IRON, "Metal"),
			},
			Sockets = { Base = { 0, 3.6, 0 }, Tip = { 0, 3.8, -2.3 } },
			Skins = { Wood = S(WOOD_DK, "Wood"), Leather = S(LEATHER, "Fabric"), Rope = S({ 150, 132, 96 }, "Fabric"), Iron = S(IRON, "Metal"), Steel = S(STEEL, "Metal"), Crystal = S({ 255, 160, 90 }, "Neon") },
			Trail = { 255, 170, 100 },
		},
	},
	-- 연금술사: 오른손 둥근 플라스크(목에 노끈) + 왼손 원통 약병 — 던지면 새 병이 손에 다시 생긴다
	Flask = {
		Id = "Flask",
		Name = "연금 약병",
		Type = "Throwable",
		Main = {
			Hand = "Right",
			Parts = {
				-- 전투 카메라(멀리 옆에서 봄)에서 보이도록 실제보다 크게 만든다
				P("Glass", "Ball", { 0.96, 0.96, 0.96 }, { 0, 0.42, 0, 0, 0, 0 }, { 200, 236, 230 }, "Glass", 0.45),
				P("Liquid", "Ball", { 0.74, 0.74, 0.74 }, { 0, 0.36, 0, 0, 0, 0 }, { 120, 230, 110 }, "Neon", 0.1),
				P("Neck", "Cylinder", { 0.5, 0.3, 0.3 }, { 0, 1.05, 0, 0, 0, 90 }, { 200, 236, 230 }, "Glass", 0.4),
				P("Lip", "Cylinder", { 0.08, 0.38, 0.38 }, { 0, 1.3, 0, 0, 0, 90 }, { 200, 236, 230 }, "Glass", 0.3),
				P("Twine", "Cylinder", { 0.08, 0.34, 0.34 }, { 0, 0.94, 0, 0, 0, 90 }, { 176, 146, 96 }, "Fabric"),
				P("Cork", "Cylinder", { 0.22, 0.26, 0.26 }, { 0, 1.42, 0, 0, 0, 90 }, { 150, 110, 70 }, "Wood"),
			},
			Sockets = { Base = { 0, 0.42, 0 }, Tip = { 0, 1.42, 0 } },
			Skins = { Glass = S({ 200, 236, 230 }, "Glass", 0.45), Liquid = S({ 120, 230, 110 }, "Neon", 0.1), Twine = S({ 176, 146, 96 }, "Fabric"), Cork = S({ 150, 110, 70 }, "Wood") },
		},
		Off = {
			Hand = "Left",
			Parts = {
				P("Glass", "Cylinder", { 0.8, 0.52, 0.52 }, { 0, 0.3, 0, 0, 0, 90 }, { 200, 236, 230 }, "Glass", 0.45),
				P("Liquid", "Cylinder", { 0.56, 0.42, 0.42 }, { 0, 0.2, 0, 0, 0, 90 }, { 255, 120, 60 }, "Neon", 0.1),
				P("Shoulder", "Cylinder", { 0.1, 0.4, 0.4 }, { 0, 0.74, 0, 0, 0, 90 }, { 200, 236, 230 }, "Glass", 0.4),
				P("Neck", "Cylinder", { 0.26, 0.24, 0.24 }, { 0, 0.88, 0, 0, 0, 90 }, { 200, 236, 230 }, "Glass", 0.4),
				P("Cork", "Cylinder", { 0.2, 0.22, 0.22 }, { 0, 1.08, 0, 0, 0, 90 }, { 150, 110, 70 }, "Wood"),
				P("Seal", "Cylinder", { 0.06, 0.3, 0.3 }, { 0, 1.0, 0, 0, 0, 90 }, { 150, 30, 30 }, "SmoothPlastic"),
			},
			Sockets = { Base = { 0, 0.3, 0 }, Tip = { 0, 1.08, 0 } },
			Skins = { Glass = S({ 200, 236, 230 }, "Glass", 0.45), Liquid = S({ 255, 120, 60 }, "Neon", 0.1), Cork = S({ 150, 110, 70 }, "Wood"), Seal = S({ 150, 30, 30 }, "SmoothPlastic") },
		},
	},
	-- 광전사: 데인 액스 — 긴 자루, 얇고 넓은 초승달 날(아래로 긴 턱), 머리 쪽 쇠띠, 핏빛 룬.
	-- 두 손 사이를 벌려 쥔다(아래 손 = 자루 끝, 위 손 = 머리 쪽: 데인 액스 전사의 쥐는 법)
	Greataxe = {
		Id = "Greataxe",
		Name = "피의 양손 도끼",
		Type = "Axe2H",
		Main = {
			Hand = "Right",
			Parts = {
				P("Haft", "Block", { 0.26, 4.9, 0.26 }, { 0, 1.35, 0, 0, 0, 0 }, WOOD_DK, "Wood"),
				P("GripLow", "Block", { 0.32, 0.8, 0.32 }, { 0, -0.2, 0, 0, 0, 0 }, LEATHER, "Fabric"),
				P("GripHigh", "Block", { 0.32, 0.5, 0.32 }, { 0, 1.7, 0, 0, 0, 0 }, LEATHER, "Fabric"),
				P("ButtCap", "Block", { 0.34, 0.24, 0.34 }, { 0, -1.1, 0, 0, 45, 0 }, STEEL_DK, "Metal"),
				P("Langet", "Block", { 0.3, 0.7, 0.3 }, { 0, 2.95, 0, 0, 0, 0 }, STEEL_DK, "Metal"),
				P("Eye", "Block", { 0.36, 0.72, 0.46 }, { 0, 3.45, 0, 0, 0, 0 }, STEEL_DK, "Metal"),
				P("Neck", "Block", { 0.1, 0.7, 1.07 }, { 0, 3.45, -0.765, 0, 0, 0 }, STEEL, "Metal"),
				P("FlareTop", "Wedge", { 0.1, 0.65, 1.07 }, { 0, 4.125, -0.765, 0, 180, 0 }, STEEL, "Metal"),
				P("Beard", "Wedge", { 0.1, 0.9, 1.07 }, { 0, 2.65, -0.765, 180, 0, 0 }, STEEL, "Metal"),
				P("Edge", "Block", { 0.12, 2.25, 0.14 }, { 0, 3.325, -1.3, 0, 0, 0 }, { 226, 230, 236 }, "Metal"),
				P("Rune", "Block", { 0.14, 0.42, 0.42 }, { 0, 3.45, -0.8, 0, 0, 45 }, { 255, 50, 40 }, "Neon"),
				P("Poll", "Block", { 0.3, 0.44, 0.3 }, { 0, 3.45, 0.36, 0, 0, 0 }, STEEL_DK, "Metal"),
				P("Cap", "Wedge", { 0.24, 0.34, 0.24 }, { 0, 3.98, 0, 0, 0, 0 }, STEEL_DK, "Metal"),
			},
			Sockets = { Base = { 0, 2.3, -1.3 }, Tip = { 0, 4.4, -1.3 } },
			Skins = { Wood = S(WOOD_DK, "Wood"), Leather = S(LEATHER, "Fabric"), Steel = S(STEEL, "Metal"), Dark = S(STEEL_DK, "Metal"), Edge = S({ 226, 230, 236 }, "Metal"), Rune = S({ 255, 50, 40 }, "Neon") },
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
