--!nocheck
--[[
	Jeolhwa_Interiors.luau — 2026-09-27. 절화 건물 안을 꾸민다 (걸어 들어가는 방).

	절화 건물은 앞 가운데 칸이 트인 문("open")이라 안으로 걸어 들어갈 수 있다. 같은 틀을 여러 채 쓰므로
	틀 종류마다 방 배치를 한 번 적고, 그 틀의 모든 집에 놓는다. 쓰임이 다른 집(주막, 객주, 소주방,
	동궁, 척수관)은 그 집이 든 폴더 이름으로 골라 따로 적은 배치를 쓴다.

	좌표는 건물 틀의 로컬 스터드(로블록스 축: 앞 -Z, 블렌더 x 는 부호가 뒤집힌다).
	한 줄은 { 소품, x, z, yaw(도), 바닥 위 높이 }. y 는 그 틀의 방바닥 높이 + 높이.
	높이 자리에 "drop" 을 쓰면 바닥 1.5 위에서 아래로 쏜 광선이 맞은 면(월대, 마당)에 앉히고,
	"ceil" 을 쓰면 위로 쏜 광선이 맞은 건물 천장에 소품 윗끝을 붙인다(궁등 줄).
	깔개 한 줄 { x0, x1, z0, z1, 재질, 두께 } 의 두께를 주면 그만큼 두껍게 바닥부터 올린다(전돌 위 깔개).
	자리는 벽 안쪽 선, 기둥 초석 반지름, 창 턱 높이, 문 자리를 비켜 손으로 골랐다(아래 주석에 치수).
	소품 틀은 ServerStorage.JeolhwaProps (tools/Jeolhwa_Props.luau). 방바닥에는 장판이나 마루를 깐다.
	놓은 것은 Workspace.Jeolhwa.안살림 에 넣는다. 다시 돌리면 그 폴더를 지우고 새로 놓는다.
	끝에 소품마다 건물 벽·기둥과 겹치는지(충돌 모양 기준) 재서 보고한다.
]]

local RGB = Color3.fromRGB
local JANGPAN = { RGB(172, 134, 86), Enum.Material.Plastic } -- 기름 먹인 장판지. 매끈한 재질은 등불에 번쩍여서 무광으로
local MARU = { RGB(150, 108, 70), Enum.Material.WoodPlanks } -- 마루
local CARPET = { RGB(150, 40, 38), Enum.Material.Fabric } -- 정전 붉은 깔개
local HWAMUN = { RGB(199, 172, 112), Enum.Material.Fabric } -- 경회루 화문석

-- 틀마다 방. floor 는 방바닥 윗면 높이. covers 는 바닥에 깔 것 { x0, x1, z0, z1, 재질 }
-- 방 치수(블렌더 치수 0.5 배): 벽 두께 0.9, 기둥 초석 반지름 r(아래 주석)
local HOUSEL = {
	-- 몸채 x ±13.05, z ±7.05. 날개채(부엌)는 x -13.05..-4.95, z -25.05..-7.5. 초석 r 1.5
	-- 뒷벽 가운데 칸(x ±4.5)만 막힘, 옆벽은 가운데 창(턱 높이 4.07)
	{ "Byeongpung", 0, 5.7, 0 },
	{ "Boryo", 0, 3.6, 0 },
	{ "Seoan", -0.6, 0.3, 0 },
	{ "Deungjan", 2.2, 2.0, 0 },
	{ "Hwaro", -3.2, 2.6, 0 },
	{ "Mungap", 9.0, 6.4, 0 },
	{ "Bandaji", -9.0, 6.25, 0 },
	{ "Ijeongjang", 12.35, -4.6, 90 },
	{ "Gyeongdae", 12.3, 1.0, 90 },
	-- 날개채 부엌
	{ "Buttumak", -10.4, -17.0, -90 },
	{ "Chanjang", -12.3, -11.0, -90 },
	{ "Suldok", -6.9, -13.0, 0 },
}
local function mirror(list)
	local out = {}
	for _, e in ipairs(list) do
		out[#out + 1] = { e[1], -e[2], e[3], -(e[4] or 0), e[5] }
	end
	return out
end

local ROOMS = {
	Building_House = {
		-- 안 x ±13.05, z ±8.05, 바닥 1.8. 초석 r 1.14 (x ±13.5, ±4.5 앞뒤 줄, 옆 가운데 z 0)
		-- 문 x ±3.24. 뒷벽 가운데 막힘, 옆벽 앞 반 막힘, 창 턱 높이 4.07
		floor = 1.8,
		covers = { { -13.05, 13.05, -8.05, 8.05, JANGPAN } },
		default = {
			{ "Byeongpung", 0, 7.1, 0 },
			{ "Boryo", 0, 5.0, 0 },
			{ "Seoan", -0.6, 1.7, 0 },
			{ "Deungjan", 2.0, 3.0, 0 },
			{ "Hwaro", -3.0, 3.2, 0 },
			{ "Mungap", 12.35, -4.0, 90 },
			{ "Gyeongdae", 12.3, 2.4, 90 },
			{ "Bandaji", -12.25, -5.6, -90 },
			{ "Ijeongjang", -12.35, -2.4, -90 },
		},
		-- 궁 소주방(침전 동쪽). 흙바닥 부엌
		coversBy = { ["침전"] = {} },
		["침전"] = {
			{ "Buttumak", 0, 5.2, 0 },
			{ "Chanjang", 12.4, -4.0, 90 },
			{ "Suldok", -10.2, -5.3, 0 },
			{ "Soban", 2.5, 0.5, 20 },
			{ "Soban", -1.5, -1.5, -10 },
			{ "Gwe", -11.2, 2.8, -90 },
			{ "Deungjan", 3.0, -2.0, 0 },
		},
	},
	Building_Cottage = {
		-- 안 x ±11.05, z ±7.05, 바닥 1.8. 초석 r 1.14 (x ±11.5, ±3.83 앞뒤 줄, 옆 가운데). 문 x ±2.76
		floor = 1.8,
		covers = { { -11.05, 11.05, -7.05, 7.05, JANGPAN } },
		default = {
			{ "Bandaji", -10.25, -4.6, -90 },
			{ "Meongseok", 7.6, 4.5, 0 },
			{ "Suldok", -8.6, 4.4, 0 },
			{ "Soban", -1.0, 1.5, 15 },
			{ "Deungjan", 2.0, 3.5, 0 },
			{ "Hwaro", -3.5, 2.8, 0 },
		},
	},
	Annex_Tile = {
		-- 사랑방. 안 x ±8.55, z ±5.05, 바닥 1.5. 초석 r 1.0 (x 0, ±9 앞뒤 줄). 문 x 1.26..7.74
		-- 뒷벽 x 0..9 막힘, 옆벽 막힘
		floor = 1.5,
		covers = { { -8.55, 8.55, -5.05, 5.05, JANGPAN } },
		default = {
			{ "Byeongpung", 4.5, 4.2, 0 },
			{ "Boryo", 4.5, 2.25, 0 },
			{ "Seoan", 3.9, -1.2, 0 },
			{ "Mungap", -8.0, 0, -90 },
			{ "Sabang_Takja", -7.9, 3.4, -90 },
			{ "Deungjan", -1.5, 1.5, 0 },
			{ "Hwaro", -3.0, -2.0, 0 },
		},
	},
	Annex_Thatch = {
		-- 헛간. 안 x ±7.55, z ±5.05, 바닥 1.5. 초석 r 1.0 (x 0, ±8). 문 x 1.1..6.9. 흙바닥
		floor = 1.5,
		covers = {},
		default = {
			{ "Meongseok", -3.8, 2.6, 0 },
			{ "Gamani", 4.2, 3.4, 0 },
			{ "Suldok", -5.2, -2.4, 0 },
		},
	},
	Building_HouseL = {
		floor = 1.8,
		covers = { { -13.05, 13.05, -7.05, 7.05, JANGPAN } },
		default = HOUSEL,
		-- 저잣마당 객주. 몸채는 장사 방(마루), 날개채는 부엌
		coversBy = { ["저잣마당"] = { { -13.05, 13.05, -7.05, 7.05, MARU } } },
		["저잣마당"] = {
			{ "Counter", 10.8, 0, 90 },
			{ "Sirung", 0, 6.2, 0 },
			{ "Gamani", 9.0, 5.8, 0 },
			{ "Gwe", -9.0, 5.5, 0 },
			{ "Soban", -2.0, 2.5, 10 },
			{ "Chorong", -3.0, 0, 0, 7.8 },
			{ "Chorong", 4.0, 0, 0, 7.8 },
			{ "Buttumak", -10.4, -17.0, -90 },
			{ "Chanjang", -12.3, -11.0, -90 },
			{ "Suldok", -6.9, -13.0, 0 },
		},
	},
	Building_HouseLM = {
		floor = 1.8,
		covers = { { -13.05, 13.05, -7.05, 7.05, JANGPAN } },
		default = mirror(HOUSEL),
		-- 주막. 몸채에 평상 둘과 소반, 술독, 초롱 셋(마루). 날개채(+x)는 부엌
		coversBy = { ["주막"] = { { -13.05, 13.05, -7.05, 7.05, MARU } } },
		["주막"] = {
			{ "Pyeongsang", -7.5, 3.8, 0 },
			{ "Pyeongsang", 1.5, 3.8, 0 },
			{ "Soban", -7.5, 3.6, 0, 1.32 },
			{ "Soban", 1.5, 3.9, 15, 1.32 },
			{ "Suldok", -10.8, -4.5, 0 },
			{ "Gwe", 10.2, 5.2, 0 },
			{ "Chorong", -7.5, 1.5, 0, 7.8 },
			{ "Chorong", 1.5, 1.5, 0, 7.8 },
			{ "Chorong", -3.0, -3.0, 0, 7.8 },
			{ "Buttumak", 10.4, -17.0, 90 },
			{ "Chanjang", 12.3, -11.0, 90 },
			{ "Suldok", 6.9, -13.0, 0 },
		},
	},
	Shop_Row5 = {
		-- 트인 칸(x ±3.9, z -6..5.55)은 들어가는 가게방. 바닥 1.1. 뒤 초석 r 1.0 (x ±4.5)
		-- 나머지 칸은 좌판(윗면 높이 바닥 + 1.425, 가운데 z -4.4, 폭 7.2 깊이 2.7) 위에 물건, 칸 뒤에 독이나 궤짝.
		-- 칸 가운데 x: 옹기 18, 비단 9, (트인 칸 0), 궤짝 -9, 바구니 -18
		floor = 1.1,
		covers = {},
		default = {
			{ "Sirung", 0, 4.85, 0 },
			{ "Counter", 0, -0.8, 0 },
			{ "Hwaro", -2.6, 2.0, 0 },
			{ "Chorong", 0, -4.2, 0, 5.6 },
			{ "Stall_Jars", 18, -4.4, 0, 1.425 },
			{ "Suldok", 16.5, 3.4, 0 },
			{ "Stall_Cloth", 9, -4.4, 0, 1.425 },
			{ "Gwe", 10.2, 4.2, 0 },
			{ "Stall_Crates", -9, -4.4, 0, 1.425 },
			{ "Gwe", -7.8, 4.2, 180 },
			{ "Stall_Baskets", -18, -4.4, 0, 1.425 },
			{ "Suldok", -16.5, 3.4, 0 },
		},
	},
	Shop_Row3 = {
		-- 비단 9, (트인 칸 0), 바구니 -9
		floor = 1.1,
		covers = {},
		default = {
			{ "Sirung", 0, 4.85, 0 },
			{ "Counter", 0, -0.8, 0 },
			{ "Hwaro", -2.6, 2.0, 0 },
			{ "Chorong", 0, -4.2, 0, 5.6 },
			{ "Stall_Cloth", 9, -4.4, 0, 1.425 },
			{ "Gwe", 10.2, 4.2, 0 },
			{ "Stall_Baskets", -9, -4.4, 0, 1.425 },
			{ "Suldok", -7.5, 3.4, 0 },
		},
	},
	Granary = {
		-- 안 x ±11.55, z ±6.55, 바닥 2.7. 기둥 r 0.65 (x ±12, ±4 앞뒤 줄, 옆 가운데). 문 x ±2.9
		floor = 2.7,
		covers = {},
		default = {
			{ "Gamani", -7.5, 5.4, 0 },
			{ "Gamani", 0, 5.4, 0 },
			{ "Gamani", 7.5, 5.4, 0 },
			{ "Duiju", 9.9, -2.8, 90 },
			{ "Gwe", -9.9, -3.0, -90 },
			{ "Chorong", 0, 0, 0, 4.9 },
		},
	},
	Building_Hall = {
		-- 안 x ±19.05, z ±12.55, 바닥 3.9. 초석 r 1.5 (x ±19.5, ±11.7, ±3.9 앞뒤 줄, 옆 z ±4.33). 창 턱 5.84
		floor = 3.9,
		covers = { { -19.05, 19.05, -12.55, 12.55, MARU } },
		default = {},
		-- 동궁. 세자가 글을 읽고 신하를 맞는 방
		["동궁"] = {
			{ "Byeongpung", 0, 11.0, 0 },
			{ "Boryo", 0, 8.6, 0 },
			{ "Seoan", -0.6, 5.2, 0 },
			{ "Sabang_Takja", 6.5, 11.4, 0 },
			{ "Sabang_Takja", -6.5, 11.4, 0 },
			{ "Chotdae", 3.6, 10.2, 0 },
			{ "Chotdae", -3.6, 10.2, 0 },
			{ "Hyangro", 3.2, 6.8, 0 },
			{ "Hwaro", -3.2, 7.0, 0 },
			{ "Mungap", 18.4, -8.6, 90 },
			{ "Mungap", -18.4, -8.6, -90 },
			{ "Bandaji", -18.3, 7.4, -90 },
			{ "Deungjan", 9.0, 3.0, 0 },
			{ "Deungjan", -9.0, 3.0, 0 },
		},
		-- 척수관. 짐승 표본을 갈무리해 내보내는 곳
		["척수관"] = {
			{ "Specimen_Shelf", -13.5, 10.8, 0 },
			{ "Specimen_Shelf", 0, 10.8, 0 },
			{ "Specimen_Shelf", 13.5, 10.8, 0 },
			{ "Yakjang", 18.45, 0.3, 90 },
			{ "Yakjang", -18.45, 0.3, -90 },
			{ "Haebudae", -6.0, 2.0, 0 },
			{ "Haebudae", 6.0, 2.0, 0 },
			{ "Malim", -13.5, 5.5, 0 },
			{ "Malim", 13.5, 5.5, 0 },
			{ "Gwe", -13.5, -9.5, 0 },
			{ "Gwe", 13.0, -9.5, 20 },
			{ "Deungjan", -2.5, 4.5, 0 },
			{ "Chorong", 7.0, -4.0, 0, 10.4 },
			{ "Chorong", -7.0, -4.0, 0, 10.4 },
			{ "Chorong", 7.0, 6.0, 0, 10.4 },
			{ "Chorong", -7.0, 6.0, 0, 10.4 },
		},
	},
	Palace_Main = {
		-- 정전. 안 x ±29.55, z ±17.55, 바닥 6.9. 초석 r 1.72 (뒤 줄 x ±4.29 … 가운데 칸 빈 폭 ±2.57)
		-- 일월오봉도(폭 11)는 뒷벽 초석 앞(z 15.4)에 세우고 어좌 단을 그 앞에 붙인다. 닫집은 천장에 매단다
		-- 둘레 기둥뿐이라 안은 비었다. 천장(Palace_Trim 밑) 22.1 = 바닥 + 15.2
		-- 월대: 위 단 x ±38.5 z ±25 윗면 로컬 5.0(난간 x ±38, z ±24.5, 앞 난간은 가운데 x ±10 과 옆 계단 17..27 이 빔),
		--       아래 단 x ±46 z ±32 윗면 2.5. 정전 기단 x ±32 z ±20. 품계석이 마당 x ±13, z -71..-46
		floor = 6.9,
		covers = { { -2.0, 2.0, -17.55, 7.6, CARPET, 0.12 } },
		default = {
			{ "Jeondol_Hall", 0, 0, 0, -0.05 },
			{ "Ceiling_Hall", 0, 0, 0, 14.0 },
			{ "Irworobongdo", 0, 15.4, 0 },
			{ "Throne_Dais", 0, 11.1, 0 },
			{ "Throne_Chair", 0, 11.9, 0, 2.1 },
			{ "Datjip", 0, 11.1, 0, 9.5 },
			{ "Chotdae", 6.2, 8.2, 0 },
			{ "Chotdae", -6.2, 8.2, 0 },
			{ "Hyangro", 4.0, 6.0, 0 },
			{ "Hyangro", -4.0, 6.0, 0 },
			{ "Chotdae", 27.0, -9.0, 0 },
			{ "Chotdae", -27.0, -9.0, 0 },
			{ "Chotdae", 27.0, 9.0, 0 },
			{ "Chotdae", -27.0, 9.0, 0 },
			-- 의장. 깔개 양옆 두 줄, 임금 왼쪽(-x) 청룡기·오른쪽(+x) 백호기. 깃은 바깥으로 편다(+x 줄은 돌려 세움)
			{ "Uijang_GiBlue", -6.0, -13.5, 0 },
			{ "Uijang_GiWhite", 6.0, -13.5, 180 },
			{ "Uijang_GiRed", -6.0, -8.5, 0 },
			{ "Uijang_GiRed", 6.0, -8.5, 180 },
			{ "Uijang_GiYellow", -6.0, -3.5, 0 },
			{ "Uijang_GiYellow", 6.0, -3.5, 180 },
			{ "Uijang_IlsanRed", -8.0, 5.5, 0 },
			{ "Uijang_IlsanRed", 8.0, 5.5, 0 },
			{ "Uijang_Seon", -10.0, 8.8, 0 },
			{ "Uijang_Seon", 10.0, 8.8, 0 },
			-- 아악. 뒤 양옆에 편종·편경, 앞에 악사 방석. 앞 귀에 건고
			{ "Pyeonjong", -19.5, 11.8, 0 },
			{ "Pyeongyeong", 19.5, 11.8, 0 },
			{ "Bangseok", -20.6, 9.5, 0 },
			{ "Bangseok", -18.4, 9.5, 0 },
			{ "Bangseok", 18.4, 9.5, 0 },
			{ "Bangseok", 20.6, 9.5, 0 },
			{ "Geongo", -23.5, -11.5, 0 },
			{ "Geongo", 23.5, -11.5, 0 },
			-- 사관 둘. 서안을 앞에 두고 가운데를 보고 앉는다. 뒤에 병풍
			{ "Seoan", -13.0, 2.0, -90 },
			{ "Bangseok", -14.4, 2.0, 0 },
			{ "Byeongpung", -16.2, 2.0, -90 },
			{ "Seoan", 13.0, 2.0, 90 },
			{ "Bangseok", 14.4, 2.0, 0 },
			{ "Byeongpung", 16.2, 2.0, 90 },
			-- 궁등. 천장에 매단다
			{ "Gungdeung", -11.0, -12.0, 0, "ceil" },
			{ "Gungdeung", 11.0, -12.0, 0, "ceil" },
			{ "Gungdeung", -11.0, -4.0, 0, "ceil" },
			{ "Gungdeung", 11.0, -4.0, 0, "ceil" },
			{ "Gungdeung", -11.0, 5.0, 0, "ceil" },
			{ "Gungdeung", 11.0, 5.0, 0, "ceil" },
			{ "Gungdeung", -21.0, -3.0, 0, "ceil" },
			{ "Gungdeung", 21.0, -3.0, 0, "ceil" },
			-- 월대. 위 단 네 귀 드므, 가운데 계단 양옆 정, 아래 단 앞 귀와 가운데 계단 양옆 서수
			{ "Deumeu", -35.5, -22.3, 0, "drop" },
			{ "Deumeu", 35.5, -22.3, 0, "drop" },
			{ "Deumeu", -35.5, 22.3, 0, "drop" },
			{ "Deumeu", 35.5, 22.3, 0, "drop" },
			{ "Jeong", -14.0, -22.3, 0, "drop" },
			{ "Jeong", 14.0, -22.3, 0, "drop" },
			{ "Seosu", -43.5, -29.5, 0, "drop" },
			{ "Seosu", 43.5, -29.5, 0, "drop" },
			{ "Seosu", -13.5, -28.5, 0, "drop" },
			{ "Seosu", 13.5, -28.5, 0, "drop" },
		},
	},
	Pavilion_Nugak = {
		-- 경회루 윗마루. 바닥 14.4, 난간 안 x ±22, z ±17.9. 기둥(반지름 0.85)은 x ±21, ±12.6, ±4.2 와
		-- z ±16.8, ±8.4, 0 의 모든 격자점. 계단 구멍 x ±8.4, z 9.5..15.7 (세 변 난간).
		-- 임금 자리는 -Z 끝에서 +Z(손님) 를 본다. 악사는 계단 구멍 양옆에서 임금을 본다
		floor = 14.4,
		covers = { { -12.0, 12.0, -14.2, 8.0, HWAMUN } },
		default = {
			{ "Byeongpung", 0, -14.8, 180 },
			{ "Boryo", 0, -12.8, 180 },
			{ "Soban", 0, -9.3, 0 },
			{ "Chotdae", -3.4, -11.2, 0 },
			{ "Chotdae", 3.4, -11.2, 0 },
			{ "Uijang_IlsanRed", -6.3, -12.6, 0 },
			{ "Uijang_IlsanRed", 6.3, -12.6, 0 },
			{ "Soban", -8.6, -5.0, 0 },
			{ "Bangseok", -10.0, -5.0, 0 },
			{ "Soban", -8.6, -1.7, 0 },
			{ "Bangseok", -10.0, -1.7, 0 },
			{ "Soban", -8.6, 1.6, 0 },
			{ "Bangseok", -10.0, 1.6, 0 },
			{ "Soban", -8.6, 4.9, 0 },
			{ "Bangseok", -10.0, 4.9, 0 },
			{ "Soban", 8.6, -5.0, 0 },
			{ "Bangseok", 10.0, -5.0, 0 },
			{ "Soban", 8.6, -1.7, 0 },
			{ "Bangseok", 10.0, -1.7, 0 },
			{ "Soban", 8.6, 1.6, 0 },
			{ "Bangseok", 10.0, 1.6, 0 },
			{ "Soban", 8.6, 4.9, 0 },
			{ "Bangseok", 10.0, 4.9, 0 },
			{ "Akgi_Set", -15.5, 12.6, 0 },
			{ "Akgi_Set", 15.5, 12.6, 0 },
			{ "Gungdeung_Short", -8.4, -12.6, 0, "ceil" },
			{ "Gungdeung_Short", 8.4, -12.6, 0, "ceil" },
			{ "Gungdeung_Short", -8.4, -3.3, 0, "ceil" },
			{ "Gungdeung_Short", 8.4, -3.3, 0, "ceil" },
			{ "Gungdeung_Short", -8.4, 3.3, 0, "ceil" },
			{ "Gungdeung_Short", 8.4, 3.3, 0, "ceil" },
			{ "Gungdeung_Short", 0, -2.0, 0, "ceil" },
			{ "Gungdeung_Short", -15.5, 8.8, 0, "ceil" },
			{ "Gungdeung_Short", 15.5, 8.8, 0, "ceil" },
		},
	},
	Palace_Chimjeon = {
		-- 침전. 안 x ±26.55, z ±9.55, 바닥 4.4. 초석 r 1.5 (x ±3, ±9, ±15, ±21, ±27 앞뒤 줄, 옆 가운데)
		-- 뒷벽은 모두 창(턱 5.0). 서쪽(+x) 임금 자리, 동쪽(-x) 옷장·단장
		floor = 4.4,
		covers = { { -26.55, 26.55, -9.55, 9.55, JANGPAN } },
		default = {
			{ "Byeongpung", 12.0, 8.0, 0 },
			{ "Boryo", 12.0, 5.8, 0 },
			{ "Seoan", 11.4, 2.2, 0 },
			{ "Hwaro", 8.4, 5.5, 0 },
			{ "Deungjan", 15.2, 4.4, 0 },
			{ "Sabang_Takja", 18.0, 8.0, 0 },
			{ "Ijeongjang", -6.0, 8.8, 0 },
			{ "Ijeongjang", -12.0, 8.8, 0 },
			{ "Bandaji", -18.0, 8.6, 0 },
			{ "Boryo", -12.0, 4.6, 0 },
			{ "Gyeongdae", -25.6, 3.0, -90 },
			{ "Mungap", -25.9, -4.5, -90 },
			{ "Deungjan", -8.0, 3.0, 0 },
			{ "Hwaro", -15.5, 3.5, 0 },
			{ "Chotdae", 5.0, -7.0, 0 },
			{ "Chotdae", -5.0, -7.0, 0 },
		},
	},
}

local report = {}
local function say(f, ...)
	report[#report + 1] = string.format(f, ...)
end

local ok, err = pcall(function()
	local SS = game:GetService("ServerStorage")
	local kit = assert(SS:FindFirstChild("JeolhwaProps"), "ServerStorage.JeolhwaProps 가 없다. Jeolhwa_Props.luau 를 먼저 돌려라")
	local root = assert(workspace:FindFirstChild("Jeolhwa"), "Workspace.Jeolhwa 가 없다")
	local old = root:FindFirstChild("안살림")
	if old then
		old:Destroy()
	end
	local out = Instance.new("Folder")
	out.Name = "안살림"
	out.Parent = root

	local function cover(pv, c, floorY, parent)
		local x0, x1, z0, z1, skin, t = c[1], c[2], c[3], c[4], c[5], c[6] or 0.06
		local p = Instance.new("Part")
		p.Name = "Floor"
		p.Anchored = true
		p.Size = Vector3.new(x1 - x0, t, z1 - z0)
		p.CFrame = pv * CFrame.new((x0 + x1) / 2, floorY + t / 2, (z0 + z1) / 2)
		p.Color, p.Material = skin[1], skin[2]
		p.TopSurface = Enum.SurfaceType.Smooth
		p.Parent = parent
	end

	local counts, nProps, nRooms = {}, 0, 0
	local probe = Instance.new("Part")
	probe.Anchored, probe.CanCollide, probe.CanQuery, probe.Transparency = true, false, false, 1
	probe.Parent = workspace
	local hits = {}
	local rpDrop = RaycastParams.new()
	rpDrop.FilterType = Enum.RaycastFilterType.Exclude
	rpDrop.FilterDescendantsInstances = { out }
	local rpCeil = RaycastParams.new()
	rpCeil.FilterType = Enum.RaycastFilterType.Include
	for _, m in ipairs(root:GetDescendants()) do
		local spec = m:IsA("Model") and ROOMS[m.Name]
		if spec and not m:IsDescendantOf(out) then
			local group = m.Parent and m.Parent.Name or ""
			local layout = spec[group] or spec.default
			local covers = (spec.coversBy and spec.coversBy[group]) or spec.covers
			if #layout > 0 or #covers > 0 then
				nRooms += 1
				local pv = m:GetPivot()
				local f = Instance.new("Folder")
				f.Name = string.format("%s_%s_%d", m.Name, group, nRooms)
				f.Parent = out
				for _, c in ipairs(covers) do
					cover(pv, c, spec.floor, f)
				end
				local op = OverlapParams.new()
				op.FilterType = Enum.RaycastFilterType.Include
				op.FilterDescendantsInstances = { m }
				rpCeil.FilterDescendantsInstances = { m }
				for _, e in ipairs(layout) do
					local tpl = assert(kit:FindFirstChild(e[1]), "소품 틀이 없다: " .. e[1])
					local c = tpl:Clone()
					local cf = pv * CFrame.new(e[2], spec.floor + (tonumber(e[5]) or 0), e[3]) * CFrame.Angles(0, math.rad(e[4] or 0), 0)
					if e[5] == "drop" then
						local h = workspace:Raycast(pv * Vector3.new(e[2], spec.floor + 1.5, e[3]), Vector3.new(0, -80, 0), rpDrop)
						assert(h, string.format("%s %s(%.1f, %.1f) 밑에 바닥이 없다", m.Name, e[1], e[2], e[3]))
						cf = cf - Vector3.new(0, cf.Y - h.Position.Y, 0)
					elseif e[5] == "ceil" then
						local h = workspace:Raycast(pv * Vector3.new(e[2], spec.floor + 2, e[3]), Vector3.new(0, 60, 0), rpCeil)
						assert(h, string.format("%s %s(%.1f, %.1f) 위에 천장이 없다", m.Name, e[1], e[2], e[3]))
						local bcf, bsz = tpl:GetBoundingBox() -- 틀 피벗이 원점이라 윗끝 높이가 곧 소품 키다
						cf = cf - Vector3.new(0, cf.Y - (h.Position.Y - (bcf.Y + bsz.Y / 2)), 0)
					end
					c:PivotTo(cf)
					c.Parent = f
					nProps += 1
					counts[e[1]] = (counts[e[1]] or 0) + 1
					-- 건물 벽·기둥과 겹치는지. 소품 경계 상자를 조금 줄여 재 본다
					local bcf, bsz = c:GetBoundingBox()
					probe.CFrame = bcf
					probe.Size = Vector3.new(math.max(0.1, bsz.X - 0.3), math.max(0.1, bsz.Y - 0.3), math.max(0.1, bsz.Z - 0.3))
					local names = {}
					for _, q in ipairs(workspace:GetPartsInPart(probe, op)) do
						if q.CanCollide then
							names[q.Name] = true
						end
					end
					local list = {}
					for n in pairs(names) do
						list[#list + 1] = n
					end
					if #list > 0 then
						table.sort(list)
						hits[#hits + 1] = string.format("%s %s(%.1f, %.1f) ~ %s", f.Name, e[1], e[2], e[3], table.concat(list, ","))
					end
				end
			end
		end
	end
	probe:Destroy()
	say("방 %d, 소품 %d", nRooms, nProps)
	local names = {}
	for k in pairs(counts) do
		names[#names + 1] = k
	end
	table.sort(names)
	local parts = {}
	for _, k in ipairs(names) do
		parts[#parts + 1] = k .. " " .. counts[k]
	end
	say("%s", table.concat(parts, ", "))
	say("건물과 겹침 %d 건", #hits)
	for _, h in ipairs(hits) do
		say("  %s", h)
	end
end)
if not ok then
	say("ERR %s", tostring(err))
end
local HS = game:GetService("HttpService")
local was = HS.HttpEnabled
HS.HttpEnabled = true
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/interiors", table.concat(report, "\n"))
end)
HS.HttpEnabled = was
print("interiors", #report, ok)
