--!nocheck
--[[
	Roman_City.luau — 화산섬에 칼로도르 폴리스를 세운다. (2026-09-29)

	칼로도르 폴리스는 거인을 빚은 이그너스를 섬기는 로마풍 제국이다. 황제(임페라토) 한 사람 아래
	파트리키리·에퀴테르포·플레베르스·에쉬스가 살고, 길드 파빌라키니스(실리아 → 밀레우스/임모로우 →
	트리부누스 → 레가투스)가 서쪽 요새를 지켰다. 지금은 사람이 떠난 폐허다(2026-09-29: 건물은 무너지고
	빛은 바래고 굴뚝 연기·광장 불도 꺼졌다). 칼데라 석호 가운데 섬 봉인 단에는 제단만 남았다 — 거기 묶였던
	마지막 거인(오벨리스크 여덟·사슬)은 나중에 보스로 나온다. 황궁은 다리 너머로 제단을 마주 본다.

	**배치는 tools/roman_plan.py 표에 손으로 적었다.** 그 파일이 땅·겹침·길을 검사하고 자료를 뽑아
	DATA 자리표에 끼운 Roman_City_run.luau 를 만든다. 틀은 ServerStorage.RomanKit (Roman_Kit.luau).
	다시 돌리면 Workspace.Surface.Roman_칼로도르 만 새로 짓는다. 섬 지반(G_화산)은 건드리지 않는다.

	짓는 순서: 용암 호수 → 봉인 단·제단 → 광장 → 길 → 건물(9 점 실측, 기울면 현무암 기단) → 다리 내림길 →
	불의 글라디우스 → 거인 발자국 → 마른 포도밭 → 온천 못 → 분기공 → 버려진 에쉬스 마을 → 훈련 기둥 →
	남의 것과 겹침 보고(/roman_city)
]]
local D = (function()
-- tools/roman_plan.py 가 만든 칼로도르 폴리스 배치 자료. 손대지 말고 배치표를 고친 뒤 다시 돌린다.
return {
	Items = {
		{Kit = "Palatium", X = -1330, Z = -3440, Yaw = 180, Group = "Palace", Plinth = "box", B = {-60.1, 60.1, -49.2, 39.5}},
		{Kit = "Domus", X = -1330, Z = -3545, Yaw = 0, Group = "Palace", Plinth = "box", B = {-18.9, 18.9, -28.3, 24.7}},
		{Kit = "Bridge_Span", X = -1320, Z = -3340, Yaw = 90, Group = "Bridge", Plinth = "none", Y = -1, B = {-25, 20, -11, 11}},
		{Kit = "Bridge_Span", X = -1320, Z = -3300, Yaw = 90, Group = "Bridge", Plinth = "none", Y = -1, B = {-25, 20, -11, 11}},
		{Kit = "Bridge_Span", X = -1320, Z = -3260, Yaw = 90, Group = "Bridge", Plinth = "none", Y = -1, B = {-25, 20, -11, 11}},
		{Kit = "Bridge_Span", X = -1320, Z = -3220, Yaw = 90, Group = "Bridge", Plinth = "none", Y = -1, B = {-25, 20, -11, 11}},
		{Kit = "Bridge_Span", X = -1320, Z = -3180, Yaw = 90, Group = "Bridge", Plinth = "none", Y = -1, B = {-25, 20, -11, 11}},
		{Kit = "Bridge_Span", X = -1320, Z = -3140, Yaw = 90, Group = "Bridge", Plinth = "none", Y = -1, B = {-25, 20, -11, 11}},
		{Kit = "Bridge_Span", X = -1320, Z = -3100, Yaw = 90, Group = "Bridge", Plinth = "none", Y = -1, B = {-25, 20, -11, 11}},
		{Kit = "Bridge_Span", X = -1320, Z = -3060, Yaw = 90, Group = "Bridge", Plinth = "none", Y = -1, B = {-25, 20, -11, 11}},
		{Kit = "Bridge_Span", X = -1320, Z = -3020, Yaw = 90, Group = "Bridge", Plinth = "none", Y = -1, B = {-25, 20, -11, 11}},
		{Kit = "Bridge_Span", X = -1320, Z = -2980, Yaw = 90, Group = "Bridge", Plinth = "none", Y = -1, B = {-25, 20, -11, 11}},
		{Kit = "Aquila", X = -1338, Z = -3366, Yaw = 180, Group = "Bridge", Plinth = "none", B = {-2.6, 2.6, -1.2, 0.7}},
		{Kit = "Aquila", X = -1302, Z = -3366, Yaw = 180, Group = "Bridge", Plinth = "none", B = {-2.6, 2.6, -1.2, 0.7}},
		{Kit = "Brazier", X = -1334, Z = -2941, Yaw = 0, Group = "Seal", Plinth = "none", B = {-1.9, 1.7, -1.7, 1.7}},
		{Kit = "Brazier", X = -1306, Z = -2941, Yaw = 0, Group = "Seal", Plinth = "none", B = {-1.9, 1.7, -1.7, 1.7}},
		{Kit = "Temple_Ignus", X = -860, Z = -3345, Yaw = 180, Group = "Forum", Plinth = "box", B = {-24.8, 24.8, -44, 43}},
		{Kit = "Brazier", X = -886, Z = -3296, Yaw = 0, Group = "Forum", Plinth = "none", B = {-1.9, 1.7, -1.7, 1.7}},
		{Kit = "Brazier", X = -834, Z = -3296, Yaw = 0, Group = "Forum", Plinth = "none", B = {-1.9, 1.7, -1.7, 1.7}},
		{Kit = "Victory_Column", X = -860, Z = -3262, Yaw = 0, Group = "Forum", Plinth = "box", B = {-5, 5, -5, 5}},
		{Kit = "Basilica", X = -773, Z = -3220, Yaw = 90, Group = "Forum", Plinth = "box", B = {-47.2, 47.2, -31.6, 25}},
		{Kit = "Temple_Small", X = -934, Z = -3255, Yaw = -90, Group = "Forum", Plinth = "box", B = {-10.8, 10.8, -18.8, 21.7}},
		{Kit = "Temple_Small", X = -934, Z = -3185, Yaw = -90, Group = "Forum", Plinth = "box", B = {-10.8, 10.8, -18.8, 21.7}},
		{Kit = "Fountain", X = -892, Z = -3200, Yaw = 0, Group = "Forum", Plinth = "none", B = {-6, 6, -6, 6}},
		{Kit = "Fountain", X = -828, Z = -3200, Yaw = 0, Group = "Forum", Plinth = "none", B = {-6, 6, -6, 6}},
		{Kit = "Statue_Human", X = -903, Z = -3288, Yaw = -90, Group = "Forum", Plinth = "none", B = {-2.3, 2.3, -2.3, 2.3}},
		{Kit = "Statue_Human", X = -817, Z = -3288, Yaw = 90, Group = "Forum", Plinth = "none", B = {-2.3, 2.3, -2.3, 2.3}},
		{Kit = "Statue_Human", X = -903, Z = -3150, Yaw = -90, Group = "Forum", Plinth = "none", B = {-2.3, 2.3, -2.3, 2.3}},
		{Kit = "Statue_Human", X = -817, Z = -3150, Yaw = 90, Group = "Forum", Plinth = "none", B = {-2.3, 2.3, -2.3, 2.3}},
		{Kit = "Triumphal_Arch", X = -860, Z = -3118, Yaw = 0, Group = "Forum", Plinth = "box", B = {-19.8, 19.8, -7.3, 7.3}},
		{Kit = "Thermae", X = -998, Z = -3266, Yaw = -90, Group = "Forum", Plinth = "box", B = {-34, 34, -37.4, 30}},
		{Kit = "Aqueduct_Span", X = -998, Z = -3520, Yaw = 90, Group = "Aqueduct", Plinth = "piers", Level = "aqueduct", B = {-20, 20, -3.3, 3.3}},
		{Kit = "Aqueduct_Span", X = -998, Z = -3480, Yaw = 90, Group = "Aqueduct", Plinth = "piers", Level = "aqueduct", B = {-20, 20, -3.3, 3.3}},
		{Kit = "Aqueduct_Span", X = -998, Z = -3440, Yaw = 90, Group = "Aqueduct", Plinth = "piers", Level = "aqueduct", B = {-20, 20, -3.3, 3.3}},
		{Kit = "Aqueduct_Span", X = -998, Z = -3400, Yaw = 90, Group = "Aqueduct", Plinth = "piers", Level = "aqueduct", B = {-20, 20, -3.3, 3.3}},
		{Kit = "Aqueduct_Span", X = -998, Z = -3360, Yaw = 90, Group = "Aqueduct", Plinth = "piers", Level = "aqueduct", B = {-20, 20, -3.3, 3.3}},
		{Kit = "Aqueduct_Span", X = -998, Z = -3320, Yaw = 90, Group = "Aqueduct", Plinth = "piers", Level = "aqueduct", B = {-20, 20, -3.3, 3.3}},
		{Kit = "Domus_2", X = -1180, Z = -3470, Yaw = 180, Group = "Patrician", Plinth = "box", B = {-18.9, 18.9, -28.3, 24.7}},
		{Kit = "Domus", X = -1120, Z = -3470, Yaw = 180, Group = "Patrician", Plinth = "box", B = {-18.9, 18.9, -28.3, 24.7}},
		{Kit = "Domus_2", X = -1060, Z = -3470, Yaw = 180, Group = "Patrician", Plinth = "box", B = {-18.9, 18.9, -28.3, 24.7}},
		{Kit = "Insula_A", X = -791, Z = -3070, Yaw = -90, Group = "EastQuarter", Plinth = "box", B = {-16.2, 16.2, -18.6, 16.2}},
		{Kit = "Insula_B", X = -723, Z = -3070, Yaw = 90, Group = "EastQuarter", Plinth = "box", B = {-15.2, 13, -25.3, 23}},
		{Kit = "Insula_B_2", X = -797, Z = -3026, Yaw = -90, Group = "EastQuarter", Plinth = "box", B = {-15.2, 13, -25.3, 23}},
		{Kit = "Insula_A_2", X = -729, Z = -3026, Yaw = 90, Group = "EastQuarter", Plinth = "box", B = {-16.2, 16.2, -18.6, 16.2}},
		{Kit = "Insula_A", X = -791, Z = -2982, Yaw = -90, Group = "EastQuarter", Plinth = "box", B = {-16.2, 16.2, -18.6, 16.2}},
		{Kit = "Insula_A_2", X = -729, Z = -2982, Yaw = 90, Group = "EastQuarter", Plinth = "box", B = {-16.2, 16.2, -18.6, 16.2}},
		{Kit = "Insula_A", X = -791, Z = -2938, Yaw = -90, Group = "EastQuarter", Plinth = "box", B = {-16.2, 16.2, -18.6, 16.2}},
		{Kit = "Insula_B", X = -797, Z = -2894, Yaw = -90, Group = "EastQuarter", Plinth = "box", B = {-15.2, 13, -25.3, 23}},
		{Kit = "Insula_A_2", X = -729, Z = -2894, Yaw = 90, Group = "EastQuarter", Plinth = "box", B = {-16.2, 16.2, -18.6, 16.2}},
		{Kit = "Insula_A", X = -791, Z = -2850, Yaw = -90, Group = "EastQuarter", Plinth = "box", B = {-16.2, 16.2, -18.6, 16.2}},
		{Kit = "Insula_B_2", X = -723, Z = -2850, Yaw = 90, Group = "EastQuarter", Plinth = "box", B = {-15.2, 13, -25.3, 23}},
		{Kit = "Insula_A_2", X = -791, Z = -2806, Yaw = -90, Group = "EastQuarter", Plinth = "box", B = {-16.2, 16.2, -18.6, 16.2}},
		{Kit = "Insula_A", X = -729, Z = -2806, Yaw = 90, Group = "EastQuarter", Plinth = "box", B = {-16.2, 16.2, -18.6, 16.2}},
		{Kit = "City_Gate", X = -672, Z = -2938, Yaw = -90, Group = "EastGate", Plinth = "box", B = {-26.4, 26.4, -8.4, 8.4}},
		{Kit = "Wall_Seg", X = -672, Z = -2984.4, Yaw = 90, Group = "EastGate", Plinth = "box", B = {-20, 20, -3.1, 3.1}},
		{Kit = "Wall_Seg_2", X = -672, Z = -3024.4, Yaw = 90, Group = "EastGate", Plinth = "box", B = {-20, 20, -3.1, 3.1}},
		{Kit = "Wall_Seg", X = -672, Z = -2891.6, Yaw = 90, Group = "EastGate", Plinth = "box", B = {-20, 20, -3.1, 3.1}},
		{Kit = "Wall_Seg_2", X = -672, Z = -2851.6, Yaw = 90, Group = "EastGate", Plinth = "box", B = {-20, 20, -3.1, 3.1}},
		{Kit = "Wall_Tower", X = -672, Z = -3052, Yaw = 0, Group = "EastGate", Plinth = "box", B = {-7.6, 7.6, -7.6, 7.6}},
		{Kit = "Wall_Tower", X = -672, Z = -2824, Yaw = 0, Group = "EastGate", Plinth = "box", B = {-7.6, 7.6, -7.6, 7.6}},
		{Kit = "Taberna_Row", X = -880, Z = -2662, Yaw = 180, Group = "Market", Plinth = "box", B = {-19.6, 19.6, -7.4, 6.4}},
		{Kit = "Taberna_Row_2", X = -880, Z = -2558, Yaw = 0, Group = "Market", Plinth = "box", B = {-19.6, 19.6, -7.4, 6.4}},
		{Kit = "Taberna_Row", X = -934, Z = -2610, Yaw = -90, Group = "Market", Plinth = "box", B = {-19.6, 19.6, -7.4, 6.4}},
		{Kit = "Taberna_Row_2", X = -826, Z = -2610, Yaw = 90, Group = "Market", Plinth = "box", B = {-19.6, 19.6, -7.4, 6.4}},
		{Kit = "Market_Stall", X = -900, Z = -2628, Yaw = 0, Group = "Market", Plinth = "none", B = {-4.5, 3.7, -2.7, 2.7}},
		{Kit = "Market_Stall", X = -860, Z = -2628, Yaw = 0, Group = "Market", Plinth = "none", B = {-4.5, 3.7, -2.7, 2.7}},
		{Kit = "Market_Stall", X = -900, Z = -2592, Yaw = 180, Group = "Market", Plinth = "none", B = {-4.5, 3.7, -2.7, 2.7}},
		{Kit = "Market_Stall", X = -860, Z = -2592, Yaw = 180, Group = "Market", Plinth = "none", B = {-4.5, 3.7, -2.7, 2.7}},
		{Kit = "Market_Stall", X = -880, Z = -2610, Yaw = 90, Group = "Market", Plinth = "none", B = {-4.5, 3.7, -2.7, 2.7}},
		{Kit = "Amphorae", X = -912, Z = -2640, Yaw = 0, Group = "Market", Plinth = "none", B = {-2.1, 2, -2.1, 2.3}},
		{Kit = "Amphorae", X = -848, Z = -2582, Yaw = 0, Group = "Market", Plinth = "none", B = {-2.1, 2, -2.1, 2.3}},
		{Kit = "Amphorae", X = -915, Z = -2582, Yaw = 0, Group = "Market", Plinth = "none", B = {-2.1, 2, -2.1, 2.3}},
		{Kit = "Insula_A_2", X = -1020, Z = -2640, Yaw = -90, Group = "Market", Plinth = "box", B = {-16.2, 16.2, -18.6, 16.2}},
		{Kit = "Insula_B", X = -1016, Z = -2586, Yaw = -90, Group = "Market", Plinth = "box", B = {-15.2, 13, -25.3, 23}},
		{Kit = "Insula_A", X = -1030, Z = -2530, Yaw = 0, Group = "Market", Plinth = "box", B = {-16.2, 16.2, -18.6, 16.2}},
		{Kit = "Domus", X = -742, Z = -2600, Yaw = 90, Group = "Market", Plinth = "box", B = {-18.9, 18.9, -28.3, 24.7}},
		{Kit = "Insula_A_2", X = -780, Z = -2510, Yaw = 0, Group = "Market", Plinth = "box", B = {-16.2, 16.2, -18.6, 16.2}},
		{Kit = "Amph_Quarter", X = -1300, Z = -2360, Yaw = 0, Group = "Amphitheater", Plinth = "none", Level = "amph", Circle = 70, B = {-67.7, 1.6, -1.6, 67}},
		{Kit = "Amph_Quarter", X = -1300, Z = -2360, Yaw = 90, Group = "Amphitheater", Plinth = "none", Level = "amph", Circle = 70, B = {-67.7, 1.6, -1.6, 67}},
		{Kit = "Amph_Quarter", X = -1300, Z = -2360, Yaw = 180, Group = "Amphitheater", Plinth = "none", Level = "amph", Circle = 70, B = {-67.7, 1.6, -1.6, 67}},
		{Kit = "Amph_Quarter", X = -1300, Z = -2360, Yaw = 270, Group = "Amphitheater", Plinth = "none", Level = "amph", Circle = 70, B = {-67.7, 1.6, -1.6, 67}},
		{Kit = "Insula_A", X = -1560, Z = -2440, Yaw = 0, Group = "SouthQuarter", Plinth = "box", B = {-16.2, 16.2, -18.6, 16.2}},
		{Kit = "Insula_A_2", X = -1510, Z = -2440, Yaw = 0, Group = "SouthQuarter", Plinth = "box", B = {-16.2, 16.2, -18.6, 16.2}},
		{Kit = "Insula_A", X = -1460, Z = -2440, Yaw = 0, Group = "SouthQuarter", Plinth = "box", B = {-16.2, 16.2, -18.6, 16.2}},
		{Kit = "Insula_B_2", X = -1150, Z = -2405, Yaw = 0, Group = "SouthQuarter", Plinth = "box", B = {-15.2, 13, -25.3, 23}},
		{Kit = "Insula_A_2", X = -1100, Z = -2400, Yaw = 0, Group = "SouthQuarter", Plinth = "box", B = {-16.2, 16.2, -18.6, 16.2}},
		{Kit = "Taberna_Row", X = -1030, Z = -2440, Yaw = 0, Group = "SouthQuarter", Plinth = "box", B = {-19.6, 19.6, -7.4, 6.4}},
		{Kit = "Insula_A", X = -1520, Z = -2390, Yaw = 180, Group = "SouthQuarter", Plinth = "box", B = {-16.2, 16.2, -18.6, 16.2}},
		{Kit = "Insula_A_2", X = -1470, Z = -2390, Yaw = 180, Group = "SouthQuarter", Plinth = "box", B = {-16.2, 16.2, -18.6, 16.2}},
		{Kit = "Ruin_Temple", X = -1720, Z = -2600, Yaw = 20, Group = "Ruins", Plinth = "box", B = {-18, 17, -14, 11}},
		{Kit = "Ruin_Temple", X = -1560, Z = -2560, Yaw = -15, Group = "Ruins", Plinth = "box", B = {-18, 17, -14, 11}},
		{Kit = "Giant_Head", X = -1650, Z = -2652, Yaw = 40, Group = "Ruins", Plinth = "none", B = {-11, 11, -10.4, 9.2}},
		{Kit = "Giant_Hand", X = -1470, Z = -2548, Yaw = -30, Group = "Ruins", Plinth = "none", B = {-8, 8.6, -6, 6.8}},
		{Kit = "Giant_Foot", X = -1770, Z = -2570, Yaw = 10, Group = "Ruins", Plinth = "box", B = {-8, 8, -11, 11}},
		{Kit = "Column_Drums", X = -1640, Z = -2560, Yaw = 70, Group = "Ruins", Plinth = "none", B = {-8.3, 5.1, -1.6, 3.7}},
		{Kit = "Column_Drums", X = -1598, Z = -2645, Yaw = -20, Group = "Ruins", Plinth = "none", B = {-8.3, 5.1, -1.6, 3.7}},
		{Kit = "Column_Drums", X = -1690, Z = -2525, Yaw = 5, Group = "Ruins", Plinth = "none", B = {-8.3, 5.1, -1.6, 3.7}},
		{Kit = "Column_Drums", X = -1760, Z = -2650, Yaw = 35, Group = "Ruins", Plinth = "none", B = {-8.3, 5.1, -1.6, 3.7}},
		{Kit = "Principia", X = -1745, Z = -3185, Yaw = -130.3, Group = "Legion", Plinth = "box", FireGladius = true, B = {-26, 26, -26, 23}},
		{Kit = "Aquila", X = -1728.57, Z = -3157.99, Yaw = -130.3, Group = "Legion", Plinth = "none", B = {-2.6, 2.6, -1.2, 0.7}},
		{Kit = "Aquila", X = -1715.65, Z = -3173.25, Yaw = -130.3, Group = "Legion", Plinth = "none", B = {-2.6, 2.6, -1.2, 0.7}},
		{Kit = "Aquila", X = -1733.09, Z = -3152.65, Yaw = -130.3, Group = "Legion", Plinth = "none", B = {-2.6, 2.6, -1.2, 0.7}},
		{Kit = "Aquila", X = -1711.13, Z = -3178.59, Yaw = -130.3, Group = "Legion", Plinth = "none", B = {-2.6, 2.6, -1.2, 0.7}},
		{Kit = "Barracks", X = -1850.62, Z = -3149.98, Yaw = 229.7, Group = "Legion", Plinth = "box", B = {-31.1, 31.1, -9.5, 8.5}},
		{Kit = "Barracks_2", X = -1805.4, Z = -3203.39, Yaw = 229.7, Group = "Legion", Plinth = "box", B = {-31.1, 31.1, -9.5, 8.5}},
		{Kit = "Barracks", X = -1760.18, Z = -3256.8, Yaw = 229.7, Group = "Legion", Plinth = "box", B = {-31.1, 31.1, -9.5, 8.5}},
		{Kit = "Barracks_2", X = -1763.64, Z = -3076.34, Yaw = 49.7, Group = "Legion", Plinth = "box", B = {-31.1, 31.1, -9.5, 8.5}},
		{Kit = "Barracks", X = -1657.05, Z = -3202.23, Yaw = 49.7, Group = "Legion", Plinth = "box", B = {-31.1, 31.1, -9.5, 8.5}},
		{Kit = "Watchtower", X = -1888.85, Z = -3123.4, Yaw = 49.7, Group = "Legion", Plinth = "box", B = {-6, 6, -6, 6}},
		{Kit = "Watchtower", X = -1722.42, Z = -3323.07, Yaw = 49.7, Group = "Legion", Plinth = "box", B = {-6, 6, -6, 6}},
		{Kit = "Watchtower", X = -1604.38, Z = -3242.79, Yaw = 49.7, Group = "Legion", Plinth = "box", B = {-6, 6, -6, 6}},
		{Kit = "Wall_Seg", X = -1886.61, Z = -3147.7, Yaw = 49.7, Group = "Legion", Plinth = "box", B = {-20, 20, -3.1, 3.1}},
		{Kit = "Wall_Seg_2", X = -1860.77, Z = -3178.22, Yaw = 49.7, Group = "Legion", Plinth = "box", B = {-20, 20, -3.1, 3.1}},
		{Kit = "Wall_Seg", X = -1834.93, Z = -3208.74, Yaw = 49.7, Group = "Legion", Plinth = "box", B = {-20, 20, -3.1, 3.1}},
		{Kit = "Wall_Seg_2", X = -1809.09, Z = -3239.26, Yaw = 49.7, Group = "Legion", Plinth = "box", B = {-20, 20, -3.1, 3.1}},
		{Kit = "Wall_Seg", X = -1783.25, Z = -3269.78, Yaw = 49.7, Group = "Legion", Plinth = "box", B = {-20, 20, -3.1, 3.1}},
		{Kit = "Wall_Seg_2", X = -1757.41, Z = -3300.3, Yaw = 49.7, Group = "Legion", Plinth = "box", B = {-20, 20, -3.1, 3.1}},
		{Kit = "Wall_Seg", X = -1731.57, Z = -3330.82, Yaw = 49.7, Group = "Legion", Plinth = "box", B = {-20, 20, -3.1, 3.1}},
		{Kit = "City_Gate", X = -1610.59, Z = -3283.41, Yaw = -40.25, Group = "Legion", Plinth = "box", B = {-26.4, 26.4, -8.4, 8.4}},
		{Kit = "Crane", X = -1773.08, Z = -3130.18, Yaw = 49.7, Group = "Legion", Plinth = "none", B = {-4.7, 4.7, -5, 10.7}},
		{Kit = "Column_Drums", X = -1785.41, Z = -3124.9, Yaw = 10, Group = "Legion", Plinth = "none", B = {-8.3, 5.1, -1.6, 3.7}},
		{Kit = "Column_Drums", X = -1768.38, Z = -3141.92, Yaw = -25, Group = "Legion", Plinth = "none", B = {-8.3, 5.1, -1.6, 3.7}},
		{Kit = "Domus_2", X = -1560, Z = -3426, Yaw = 180, Group = "Patrician", Plinth = "box", B = {-18.9, 18.9, -28.3, 24.7}},
		{Kit = "Domus", X = -1500, Z = -3426, Yaw = 180, Group = "Patrician", Plinth = "box", B = {-18.9, 18.9, -28.3, 24.7}},
		{Kit = "Domus_2", X = -1440, Z = -3426, Yaw = 180, Group = "Patrician", Plinth = "box", B = {-18.9, 18.9, -28.3, 24.7}},
		{Kit = "Temple_Small", X = -1535, Z = -3345, Yaw = -155.65, Group = "Patrician", Plinth = "box", B = {-10.8, 10.8, -18.8, 21.7}},
		{Kit = "Colossus", X = -1480, Z = -3318, Yaw = -160.35, Group = "Colossi", Plinth = "box", B = {-14.1, 13.4, -11.3, 11.9}},
		{Kit = "Colossus", X = -1060, Z = -3330, Yaw = 150.52, Group = "Colossi", Plinth = "box", B = {-14.1, 13.4, -11.3, 11.9}},
		{Kit = "Colossus", X = -1060, Z = -2700, Yaw = 56.82, Group = "Colossi", Plinth = "box", B = {-14.1, 13.4, -11.3, 11.9}},
		{Kit = "Colossus", X = -1560, Z = -2690, Yaw = -53.13, Group = "Colossi", Plinth = "box", B = {-14.1, 13.4, -11.3, 11.9}},
	},
	Roads = {
		{Name = "Cardo_Forum", W = 14, P = {{-860, -3137}, {-860, -3095}, {-760, -3095}}},
		{Name = "East_Street", W = 12, P = {{-760, -3095}, {-760, -2780}}},
		{Name = "East_to_Market", W = 12, P = {{-760, -2780}, {-760, -2700}, {-849, -2700}, {-849, -2650}}},
		{Name = "Market_South", W = 12, P = {{-849, -2566}, {-849, -2480}, {-960, -2470}}},
		{Name = "South_Road", W = 12, P = {{-960, -2470}, {-1180, -2465}, {-1240, -2460}}},
		{Name = "Amph_North", W = 12, P = {{-1240, -2460}, {-1360, -2458}, {-1420, -2470}}},
		{Name = "SW_Road", W = 12, P = {{-1420, -2470}, {-1540, -2480}, {-1660, -2470}, {-1740, -2495}, {-1800, -2525}, {-1860, -2560}}},
		{Name = "West_Road", W = 12, P = {{-1860, -2560}, {-1880, -2700}, {-1910, -2800}, {-1905, -2960}, {-1874, -3032}, {-1833, -3050}, {-1795.99, -3064.43}}},
		{Name = "Legion_Via", W = 10, P = {{-1795.99, -3064.43}, {-1595.73, -3300.96}}},
		{Name = "NW_Road", W = 12, P = {{-1595.73, -3300.96}, {-1592, -3385}, {-1400, -3385}, {-1345, -3376}}},
		{Name = "Palace_to_Forum", W = 12, P = {{-1405, -3385}, {-1405, -3505}, {-1240, -3505}, {-1212, -3445}, {-1208, -3424}, {-1120, -3422}, {-1030, -3430}, {-966, -3430}, {-940, -3400}, {-905, -3385}, {-905, -3303}}},
		{Name = "Gate_Road", W = 12, P = {{-760, -2938}, {-640, -2938}}},
		{Name = "Ash_Path", W = 8, P = {{-1240, -3505}, {-1200, -3560}, {-1190, -3612}}},
	},
	Plazas = {
		{Name = "Forum", X = -860, Z = -3218, W = 96, D = 166, Yaw = 0},
		{Name = "Palace_Court", X = -1322, Z = -3375, W = 56, D = 28, Yaw = 0},
		{Name = "Market", X = -880, Z = -2610, W = 84, D = 88, Yaw = 0},
		{Name = "Legion_Yard", X = -1683.63, Z = -3257.49, W = 40, D = 52, Yaw = 49.7},
	},
	Lava = { Level = 43, Cell = 20, Runs = {
		{-1220, -1180, -3330},
		{-1240, -1180, -3310},
		{-1240, -1180, -3290},
		{-1280, -1200, -3270},
		{-1300, -1200, -3250},
		{-1460, -1460, -3230},
		{-1420, -1180, -3230},
		{-1480, -1180, -3210},
		{-1500, -1200, -3190},
		{-1540, -1200, -3170},
		{-1560, -1160, -3150},
		{-1580, -1120, -3130},
		{-1580, -1120, -3110},
		{-1600, -1060, -3090},
		{-1620, -1040, -3070},
		{-1620, -1040, -3050},
		{-1620, -1500, -3030},
		{-1460, -1440, -3030},
		{-1400, -1340, -3030},
		{-1260, -1240, -3030},
		{-1200, -1200, -3030},
		{-1160, -1060, -3030},
		{-1620, -1520, -3010},
		{-1140, -1040, -3010},
		{-1620, -1540, -2990},
		{-1120, -1000, -2990},
		{-960, -940, -2990},
		{-1740, -1580, -2970},
		{-1540, -1540, -2970},
		{-1080, -940, -2970},
		{-1740, -1580, -2950},
		{-1080, -920, -2950},
		{-1780, -1600, -2930},
		{-1080, -900, -2930},
		{-1780, -1600, -2910},
		{-1080, -880, -2910},
		{-1780, -1600, -2890},
		{-1080, -900, -2890},
		{-1780, -1580, -2870},
		{-1080, -880, -2870},
		{-1780, -1580, -2850},
		{-1080, -900, -2850},
		{-1740, -1580, -2830},
		{-1080, -900, -2830},
		{-1740, -1580, -2810},
		{-1080, -940, -2810},
		{-1740, -1580, -2790},
		{-1060, -940, -2790},
		{-940, -940, -2770},
		{-1480, -1460, -2690},
		{-1400, -1360, -2690},
		{-1320, -1200, -2690},
		{-1480, -1180, -2670},
		{-1480, -1180, -2650},
		{-1480, -1420, -2630},
		{-1360, -1320, -2630},
		{-1280, -1180, -2630},
		{-1240, -1180, -2610},
		{-1240, -1180, -2590},
		{-1240, -1180, -2570},
		{-1220, -1200, -2550},
		{-1240, -1240, -2530},
		{-1200, -1200, -2530},
	} },
	Seal = {X = -1320, Z = -2870, R = 62, Obelisks = {{-1296.27, -2927.28}, {-1262.72, -2893.73}, {-1262.72, -2846.27}, {-1296.27, -2812.72}, {-1343.73, -2812.72}, {-1377.28, -2846.27}, {-1377.28, -2893.73}, {-1343.73, -2927.28}}},
	Footprints = {{-1705, -2685, 60, 1}, {-1610, -2505, 60, -1}},
	Train = {X = -1683.63, Z = -3257.49, Yaw = 49.7},
	Vines = {
		{Name = "Vinea_SE", X = -785, Z = -2428, W = 96, D = 120, Yaw = 0, Sp = 7},
		{Name = "Vinea_SW", X = -1660, Z = -2390, W = 56, D = 104, Yaw = 0, Sp = 7},
	},
	Pools = {{-1000, -3582, 10}, {-986, -3603, 8}, {-1016, -3600, 6}},
	Ash = {Huts = {{-1303, -3645, 3, 9, 7, 5.5, true}, {-1276, -3641, -4, 9, 7, 5.5, false}, {-1250, -3638, 2, 11, 8, 6, false}, {-1158, -3640, -2, 10, 8, 6, false}, {-1131, -3638, 5, 9, 7, 5.5, true}, {-1103, -3641, -3, 10, 8, 6, false}, {-1289, -3666, 184, 10, 8, 5.5, false}, {-1262, -3667, 177, 9, 7, 5.5, true}, {-1232, -3665, 181, 10, 8, 6, false}, {-1150, -3666, 176, 11, 8, 6, false}, {-1121, -3667, 183, 9, 7, 5.5, false}, {-1092, -3665, 179, 10, 8, 6, true}}, Square = {-1195, -3655}, Lane = {{-1310, -3652}, {-1075, -3652}}, Stair = {{-1190, -3614}, {-1190, -3646}}},
	Fumaroles = {{-1440, -2990}, {-1200, -2992}, {-1238, -3372}, {-1512, -2692}, {-1722, -3010}, {-1566, -3244}, {-1690, -2660}, {-1612, -2525}, {-1460, -2745}, {-1175, -2760}},
}
end)()

local report = {}
local function say(fmt, ...)
	report[#report + 1] = string.format(fmt, ...)
end

local RGB = Color3.fromRGB
local M = Enum.Material
-- 폐허 빛(2026-09-29): 그을리고 바랜 돌. 틀(Roman_Kit SKIN)과 같은 톤
local C = {
	road = { RGB(66, 61, 60), M.Cobblestone },
	curb = { RGB(142, 134, 118), M.Limestone },
	found = { RGB(74, 68, 66), M.Basalt },
	trav = { RGB(158, 149, 128), M.Limestone },
	trav2 = { RGB(138, 128, 108), M.Limestone },
	travWhite = { RGB(172, 166, 152), M.Limestone },
	marble = { RGB(167, 161, 148), M.Marble },
	marble2 = { RGB(140, 134, 122), M.Marble },
	porphyry = { RGB(76, 42, 43), M.Marble },
	cobble = { RGB(92, 86, 82), M.Cobblestone },
	basalt = { RGB(47, 43, 45), M.Basalt },
	crust = { RGB(38, 30, 28), M.Basalt },
	crust2 = { RGB(66, 38, 30), M.CrackedLava },
	lava = { RGB(255, 84, 24), M.Neon },
	rune = { RGB(150, 64, 26), M.Neon }, -- 봉인 문자: 아직 빛나지만 사그라드는 중(네온은 색이 곧 밝기)
	gold = { RGB(122, 100, 64), M.Metal },
	iron = { RGB(59, 58, 62), M.Metal },
	sand = { RGB(146, 132, 104), M.Sand },
	wood = { RGB(62, 49, 40), M.WoodPlanks },
	vine = { RGB(88, 74, 56), M.Ground }, -- 말라 죽은 포도 줄
	hotwater = { RGB(74, 124, 118), M.Glass },
	sulfur = { RGB(168, 150, 70), M.Sand },
}

local function halfExtents(part, frame)
	local r = frame:ToObjectSpace(part.CFrame)
	local s = part.Size / 2
	local R, U, L = r.RightVector, r.UpVector, r.LookVector
	return Vector3.new(
		math.abs(R.X) * s.X + math.abs(U.X) * s.Y + math.abs(L.X) * s.Z,
		math.abs(R.Y) * s.X + math.abs(U.Y) * s.Y + math.abs(L.Y) * s.Z,
		math.abs(R.Z) * s.X + math.abs(U.Z) * s.Y + math.abs(L.Z) * s.Z
	), r.Position
end

local function steam(p, rate, dark, sulfur)
	local e = Instance.new("ParticleEmitter")
	e.Name = dark and "Smoke" or "Steam"
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	if dark then
		e.Color = ColorSequence.new(RGB(92, 60, 48), RGB(40, 34, 34))
	elseif sulfur then
		e.Color = ColorSequence.new(RGB(246, 240, 214), RGB(214, 212, 200))
	else
		e.Color = ColorSequence.new(RGB(240, 240, 244), RGB(210, 210, 216))
	end
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, dark and 0.45 or 0.5),
		NumberSequenceKeypoint.new(0.6, 0.8),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, dark and 4 or 1.5), NumberSequenceKeypoint.new(1, dark and 16 or 8) })
	e.Lifetime = NumberRange.new(3, 5)
	e.Rate = rate
	e.Speed = NumberRange.new(2, 4)
	e.SpreadAngle = Vector2.new(15, 15)
	e.Acceleration = Vector3.new(1, 1.2, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-15, 15)
	e.LightInfluence = 1
	e.Parent = p
	return e
end

local okRun, errRun = pcall(function()
	local SS = game:GetService("ServerStorage")
	local kit = assert(SS:FindFirstChild("RomanKit"), "ServerStorage.RomanKit 이 없다. Roman_Kit.luau 를 먼저 돌려라")
	-- 폐허 두 번째 판(Domus_2 등)이 아직 안 들어왔으면 첫 판으로 대신한다
	local function kitOf(name)
		return kit:FindFirstChild(name) or kit:FindFirstChild((name:gsub("_2$", "")))
	end
	for _, e in ipairs(D.Items) do
		assert(kitOf(e.Kit), e.Kit .. " 틀이 없다")
	end
	assert(kit:FindFirstChild("Fire_Gladius"), "Fire_Gladius 틀이 없다")

	local S = workspace.Surface
	local old = S:FindFirstChild("Roman_칼로도르")
	if old then
		old:Destroy()
	end
	local city = Instance.new("Folder")
	city.Name = "Roman_칼로도르"
	city:SetAttribute("Version", 1)
	city.Parent = S
	local function folder(path)
		local f = city
		for name in string.gmatch(path, "[^/]+") do
			local c = f:FindFirstChild(name)
			if not c then
				c = Instance.new("Folder")
				c.Name = name
				c.Parent = f
			end
			f = c
		end
		return f
	end
	local FPave = folder("바닥")

	local G = S.World["G_화산"]
	local rpG = RaycastParams.new()
	rpG.FilterType = Enum.RaycastFilterType.Include
	rpG.FilterDescendantsInstances = { G }
	local rpAll = RaycastParams.new()
	rpAll.FilterType = Enum.RaycastFilterType.Include
	rpAll.FilterDescendantsInstances = { G, FPave }
	local function groundY(x, z, rp)
		local h = workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -1200, 0), rp or rpAll)
		return h and h.Position.Y
	end

	local nParts = 0
	local function part(name, cf, size, col, parent, shape)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = col[1]
		p.Material = col[2]
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if shape then
			p.Shape = shape
		end
		p.Parent = parent
		nParts += 1
		return p
	end
	local function marker(name, pos, parent)
		local p = part(name, CFrame.new(pos), Vector3.new(0.4, 0.4, 0.4), C.iron, parent)
		p.Transparency = 1
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		return p
	end
	-- 세운 원기둥(원판). 윗면 top, 밑면 bot
	local function disc(name, x, z, r, bot, top, col, parent)
		return part(name, CFrame.new(x, (top + bot) / 2, z) * CFrame.Angles(0, 0, math.rad(90)), Vector3.new(top - bot, 2 * r, 2 * r), col, parent, Enum.PartType.Cylinder)
	end
	-- 원판 위에 얹는 가는 고리(조각 n 개). 윗면은 top + 0.06
	local function ring(name, x, z, r, w, top, col, n, parent)
		local L = 2 * r * math.sin(math.pi / n) + 0.15
		for i = 0, n - 1 do
			local a = (i + 0.5) / n * 2 * math.pi
			local cf = CFrame.new(x + r * math.sin(a), top - 0.09, z - r * math.cos(a)) * CFrame.Angles(0, -a, 0)
			part(name, cf, Vector3.new(L, 0.3, w), col, parent)
		end
	end
	-- 로컬 직사각형(cf 기준 w x d) 안 땅을 step 간격으로 잰다
	local function rectGround(cf, w, d, step, rp)
		local lo, hi = math.huge, -math.huge
		local nx, nz = math.max(1, math.ceil(w / step)), math.max(1, math.ceil(d / step))
		for i = 0, nx do
			for j = 0, nz do
				local wp = cf:PointToWorldSpace(Vector3.new(-w / 2 + w * i / nx, 0, -d / 2 + d * j / nz))
				local gy = groundY(wp.X, wp.Z, rp)
				assert(gy, string.format("(%.0f,%.0f) 아래에 땅이 없다", wp.X, wp.Z))
				lo, hi = math.min(lo, gy), math.max(hi, gy)
			end
		end
		return lo, hi
	end
	local function circleGround(x, z, r, rp)
		local c = assert(groundY(x, z, rp), string.format("(%.0f,%.0f) 아래에 땅이 없다", x, z))
		local lo, hi = c, c
		for dx = -r, r, 8 do
			for dz = -r, r, 8 do
				if dx * dx + dz * dz <= r * r then
					local gy = assert(groundY(x + dx, z + dz, rp), string.format("(%.0f,%.0f) 아래에 땅이 없다", x + dx, z + dz))
					lo, hi = math.min(lo, gy), math.max(hi, gy)
				end
			end
		end
		return lo, hi
	end

	--==================================================================== 1. 용암 호수
	-- 석호 빈 칸(20 간격)을 줄마다 빛나는 용암 판으로 메우고, 칸마다 어두운 굳은 껍질 판을 조금씩 비틀어 얹는다.
	-- 껍질 사이 틈과 비워 둔 칸으로 용암이 빛난다. 비운 칸 몇 곳에서 불길과 검은 연기가 오른다
	do
		local FL = folder("용암 호수")
		local rng = Random.new(20260929)
		local L = D.Lava
		local lvl = L.Level
		local nCrust, nOpen, nFire, nSmoke, nLight = 0, 0, 0, 0, 0
		for i, r in ipairs(L.Runs) do
			local a, b, z = r[1], r[2], r[3]
			part("Glow", CFrame.new((a + b) / 2, lvl - 0.6 - 6, z), Vector3.new(b - a + L.Cell + 2, 12, L.Cell + 0.2), C.lava, FL)
			for x = a, b, L.Cell do
				-- 칸마다 껍질 0~3 장. 크기·자리·돌림을 크게 흔들어 격자 무늬가 드러나지 않게 한다
				local k = rng:NextNumber() < 0.14 and 0 or rng:NextInteger(1, 3)
				for _ = 1, k do
					local s = k == 1 and rng:NextNumber(11, 17) or rng:NextNumber(5, 11.5)
					local cf = CFrame.new(x + rng:NextNumber(-6, 6), lvl - 0.45 + rng:NextNumber(0, 0.4), z + rng:NextNumber(-6, 6))
						* CFrame.Angles(0, math.rad(rng:NextNumber(0, 90)), 0)
					part("Crust", cf, Vector3.new(s * rng:NextNumber(0.65, 1.2), 1.2, s * rng:NextNumber(0.65, 1.2)),
						rng:NextNumber() < 0.6 and C.crust or C.crust2, FL)
					nCrust += 1
				end
				if k == 0 then
					nOpen += 1
					if nOpen % 3 == 1 then
						local m = marker("Heat", Vector3.new(x, lvl + 0.5, z), FL)
						steam(m, 2, true)
						nSmoke += 1
						if nOpen % 6 == 1 then
							local f = Instance.new("Fire")
							f.Size = 9
							f.Heat = 5
							f.Color = RGB(255, 120, 40)
							f.SecondaryColor = RGB(255, 60, 20)
							f.Parent = m
							nFire += 1
						end
					end
				end
			end
			if i % 5 == 3 then
				local l = Instance.new("PointLight")
				l.Color = RGB(255, 110, 50)
				l.Brightness = 1.6
				l.Range = 55
				l.Shadows = false
				l.Parent = marker("LavaLight", Vector3.new((a + b) / 2, lvl + 8, z), FL)
				nLight += 1
			end
		end
		say("용암: 줄 %d, 껍질 %d, 빈 칸 %d(연기 %d, 불 %d), 빛 %d, 수면 %.1f", #L.Runs, nCrust, nOpen, nSmoke, nFire, nLight, lvl)
	end
	task.wait()

	--==================================================================== 2. 봉인 단
	-- 두 단 현무암 원판. 위 단에 금 테(r 67), 봉인 문자 고리 둘(r 50, 47.5), 오벨리스크마다 고리에서 뻗는 문자 살
	local SD = D.Seal
	local sealTop
	do
		local FS = folder("바닥/봉인 단")
		local lo, hi = circleGround(SD.X, SD.Z, 76, rpG)
		sealTop = hi + 0.4
		disc("Dais_Lower", SD.X, SD.Z, 76, lo - 1, sealTop - 1.4, C.basalt, FS)
		disc("Dais", SD.X, SD.Z, 70, lo - 1, sealTop, C.basalt, FS)
		ring("GoldRing", SD.X, SD.Z, 67, 1.0, sealTop, C.gold, 64, FS)
		ring("GoldRing_Lower", SD.X, SD.Z, 74, 0.8, sealTop - 1.4, C.gold, 64, FS)
		ring("RuneRing", SD.X, SD.Z, 50, 1.4, sealTop, C.rune, 48, FS)
		ring("RuneRing_Inner", SD.X, SD.Z, 47.5, 0.6, sealTop, C.rune, 48, FS)
		for _, o in ipairs(SD.Obelisks) do
			local dx, dz = o[1] - SD.X, o[2] - SD.Z
			local a = math.atan2(dx, -dz)
			local r0, r1 = 50.7, 55.6
			local rm = (r0 + r1) / 2
			part("RuneSpoke", CFrame.new(SD.X + rm * math.sin(a), sealTop - 0.09, SD.Z - rm * math.cos(a)) * CFrame.Angles(0, -a, 0),
				Vector3.new(0.9, 0.3, r1 - r0), C.rune, FS)
		end
		say("봉인 단: 땅 %.1f..%.1f, 윗면 %.2f", lo, hi, sealTop)

		-- 제단(2026-09-29). 거인이 무릎 꿇었던 자리. 거인·오벨리스크·사슬은 나중에 보스로 낸다.
		-- 세 단 네모 기단(단마다 밝은 돌 턱) → 반암 제단(앞면에 반쯤 사그라진 봉인 문자, 위에 불씨 그릇).
		-- 첫 단 모서리 기둥 넷 가운데 북동 하나만 온전하고, 셋은 부러져 북 조각이 단과 봉인 단에 굴렀다.
		-- 참배길(북, 다리 내림길) 양옆 불화로 둘. 자리는 전부 손으로 적었다(제단 가운데 기준, 북 = -z)
		local FA = folder("Seal/제단")
		local X, Z = SD.X, SD.Z
		local S = 1.3 -- 아래 가로 자리·폭 배율(봉인 단 지름 150 에 맞춘다). 높이는 사람 키 그대로
		local function at(lx, y, lz)
			return CFrame.new(X + lx * S, y, Z + lz * S)
		end
		local y = sealTop
		for i, t in ipairs({ { 30, C.basalt }, { 23, C.found }, { 16, C.marble2 } }) do
			part("AltarStep" .. i, at(0, y + 0.5, 0), Vector3.new(t[1] * S, 1, t[1] * S), t[2], FA)
			-- 턱 윗면은 단 윗면보다 0.05 낮다(겹친 면이 깜빡이지 않게)
			part("AltarLip" .. i, at(0, y + 0.85, 0), Vector3.new(t[1] * S + 0.6, 0.2, t[1] * S + 0.6), C.trav2, FA)
			y += 1
		end
		part("AltarPlinth", at(0, y + 0.3, 0.4), Vector3.new(9.4 * S, 0.6, 6.6 * S), C.trav2, FA)
		part("AltarBody", at(0, y + 2.1, 0.4), Vector3.new(7.8 * S, 3, 5.2 * S), C.porphyry, FA)
		part("AltarBand", at(0, y + 3.25, 0.4), Vector3.new(7.8 * S + 0.3, 0.3, 5.2 * S + 0.3), C.gold, FA)
		part("AltarTop", at(0, y + 3.9, 0.4), Vector3.new(9 * S, 0.6, 6.4 * S), C.marble, FA)
		part("AltarRune", at(0, y + 1.9, 0.4) * CFrame.new(0, 0, -2.6 * S - 0.04), Vector3.new(4.6 * S, 1.4, 0.1), C.rune, FA)
		disc("OfferBowl", X, Z + 0.4 * S, 1.7 * S, y + 4.2, y + 4.75, C.gold, FA)
		local ember = disc("Embers", X, Z + 0.4 * S, 1.3 * S, y + 4.5, y + 4.8, C.lava, FA)
		local fire = Instance.new("Fire")
		fire.Size = 3
		fire.Heat = 6
		fire.Color = RGB(255, 120, 40)
		fire.SecondaryColor = RGB(255, 60, 20)
		fire.Parent = ember
		local glow = Instance.new("PointLight")
		glow.Color = RGB(255, 120, 60)
		glow.Brightness = 1.4
		glow.Range = 22
		glow.Shadows = false
		glow.Parent = ember
		-- 모서리 기둥: { x, z, 줄기 높이, 머리 얹음 }
		local b = sealTop + 1
		for _, c in ipairs({ { 13.3, -13.3, 9.0, true }, { -13.3, -13.3, 4.1 }, { 13.3, 13.3, 6.3 }, { -13.3, 13.3, 1.7 } }) do
			part("ColumnBase", at(c[1], b + 0.25, c[2]), Vector3.new(3 * S, 0.5, 3 * S), C.trav2, FA)
			disc("Column", X + c[1] * S, Z + c[2] * S, 1.25 * S, b + 0.5, b + 0.5 + c[3] * S, C.marble, FA)
			if c[4] then
				part("Capital", at(c[1], b + 0.8 + c[3] * S, c[2]), Vector3.new(3.2 * S, 0.6, 3.2 * S), C.marble2, FA)
			end
		end
		-- 굴러떨어진 북 조각(누운 원기둥 { x, 밑면 높이, z, 길이, 반지름, 돌림 }) 과 머리돌 하나
		for _, d in ipairs({
			{ -19, sealTop, -12, 3.5, 1.2, 30 }, { -22.5, sealTop, -7.5, 2.6, 1.2, 70 },
			{ 20, sealTop, 17, 3.2, 1.2, -20 }, { -13.3, b, 8, 3.6, 1.2, 90 }, { -24, sealTop, 21, 2.8, 1.2, 15 },
		}) do
			part("Drum", at(d[1], d[2] + d[5] * S, d[3]) * CFrame.Angles(0, math.rad(d[6]), 0), Vector3.new(d[4] * S, 2 * d[5] * S, 2 * d[5] * S), C.marble, FA, Enum.PartType.Cylinder)
		end
		part("Capital", at(23.5, sealTop + 0.45, 12.5) * CFrame.Angles(math.rad(8), math.rad(25), math.rad(-14)), Vector3.new(3.2 * S, 0.6, 3.2 * S), C.marble2, FA)
		-- 깨진 돌 조각 { x, z, 크기, 기울기 셋 }
		for _, r in ipairs({
			{ -17, -16, 1.2, 12, 40, -8 }, { -20.5, -14, 0.8, -20, 10, 15 }, { 16.5, 18.5, 1.0, 5, 70, 22 },
			{ 19, 14.5, 0.7, -15, 120, 0 }, { -18, 17.5, 0.9, 18, 200, -12 },
		}) do
			part("Shard", at(r[1], sealTop + r[3] * 0.3, r[2]) * CFrame.Angles(math.rad(r[4]), math.rad(r[5]), math.rad(r[6])), Vector3.new(r[3] * 1.4, r[3] * 0.8, r[3]) * S, C.marble2, FA)
		end
		for _, sx in ipairs({ -7.5, 7.5 }) do
			local br = kit.Brazier:Clone()
			br:PivotTo(at(sx, sealTop, -19))
			br.Parent = FA
		end
		say("제단: 기단 윗면 %.2f", y)
	end
	task.wait()

	--==================================================================== 3. 광장
	do
		local nTile = 0
		for _, pz in ipairs(D.Plazas) do
			local f = folder("바닥/광장/" .. pz.Name)
			local cf = CFrame.new(pz.X, 0, pz.Z) * CFrame.Angles(0, math.rad(pz.Yaw), 0)
			local lo, hi = rectGround(cf, pz.W, pz.D, 6, rpG)
			local top, bot = hi + 0.3, lo - 1
			-- 밑은 현무암 기단 한 장, 겉돌은 0.6 두께로 그 위에(옆면이 겉돌 빛깔로 깊게 드러나지 않게)
			local function slabAt(name, lx, lz, w, d, t, col, b)
				b = b or t - 0.6
				local c = cf:PointToWorldSpace(Vector3.new(lx, 0, lz))
				return part(name, CFrame.new(c.X, (t + b) / 2, c.Z) * cf.Rotation, Vector3.new(w, t - b, d), col, f)
			end
			slabAt("Base", 0, 0, pz.W + 0.3, pz.D + 0.3, top - 0.5, C.found, bot)
			if pz.Name == "Forum" or pz.Name == "Palace_Court" then
				-- 포룸은 트래버틴 두 빛깔 12 칸, 황궁 앞마당은 대리석 7 칸. 가운데 줄은 반암
				local T = pz.Name == "Forum" and 12 or 7
				local nx, nz = math.floor(pz.W / T), math.floor(pz.D / T)
				local w, d = pz.W / nx, pz.D / nz
				local A, B = pz.Name == "Forum" and C.trav or C.marble, pz.Name == "Forum" and C.trav2 or C.marble2
				for i = 0, nx - 1 do
					for j = 0, nz - 1 do
						local col = ((i + j) % 2 == 0) and A or B
						if nx % 2 == 0 and (i == nx / 2 - 1 or i == nx / 2) and pz.Name == "Forum" and j % 3 == 1 then
							col = C.porphyry
						end
						slabAt("Tile", -pz.W / 2 + (i + 0.5) * w, -pz.D / 2 + (j + 0.5) * d, w, d, top, col)
						nTile += 1
					end
				end
			elseif pz.Name == "Legion_Yard" then
				slabAt("Sand", 0, 0, pz.W, pz.D, top - 0.1, C.sand)
				for _, e in ipairs({ { 0, -pz.D / 2, pz.W + 1.6, 0.8 }, { 0, pz.D / 2, pz.W + 1.6, 0.8 }, { -pz.W / 2, 0, 0.8, pz.D }, { pz.W / 2, 0, 0.8, pz.D } }) do
					slabAt("Edge", e[1], e[2], e[3], e[4], top + 0.2, C.wood)
				end
			else
				slabAt("Cobble", 0, 0, pz.W, pz.D, top, C.cobble)
				for _, e in ipairs({ { 0, -pz.D / 2, pz.W + 1.6, 0.8 }, { 0, pz.D / 2, pz.W + 1.6, 0.8 }, { -pz.W / 2, 0, 0.8, pz.D }, { pz.W / 2, 0, 0.8, pz.D } }) do
					slabAt("Curb", e[1], e[2], e[3], e[4], top + 0.2, C.curb)
				end
			end
		end
		say("광장 %d, 포석 %d", #D.Plazas, nTile)
	end
	task.wait()

	--==================================================================== 4. 길
	-- 현무암 포장(조각 10 이하). 조각 끝 높이는 그 자리 폭 다섯 점 가운데 가장 높은 땅 + 0.4, 가운데가 더 높으면 같이 올린다.
	-- 두 옆은 트래버틴 연석. 밑이 1 넘게 뜨면 현무암 받침을 댄다. 꺾이는 점엔 둥근 이음판
	do
		local nPiece, nProp = 0, 0
		local function hAt(p, dir, width, name)
			local perp = Vector3.new(-dir.Z, 0, dir.X)
			local hi, lo = -math.huge, math.huge
			for _, s in ipairs({ -0.5, -0.25, 0, 0.25, 0.5 }) do
				local q = p + perp * (width * s)
				local gy = assert(groundY(q.X, q.Z, rpG), name .. string.format(" (%.0f,%.0f) 밑에 땅이 없다", q.X, q.Z))
				hi, lo = math.max(hi, gy), math.min(lo, gy)
			end
			return hi + 0.4, lo
		end
		for _, r in ipairs(D.Roads) do
			local f = folder("바닥/길/" .. r.Name)
			local width, pts = r.W, r.P
			local ends = {}
			for i = 1, #pts - 1 do
				local A = Vector3.new(pts[i][1], 0, pts[i][2])
				local B = Vector3.new(pts[i + 1][1], 0, pts[i + 1][2])
				local dir = (B - A).Unit
				local n = math.max(1, math.ceil((B - A).Magnitude / 10))
				for s = 0, n - 1 do
					local p0 = A + (B - A) * (s / n)
					local p1 = A + (B - A) * ((s + 1) / n)
					local h0, lo0 = hAt(p0, dir, width, r.Name)
					local h1, lo1 = hAt(p1, dir, width, r.Name)
					local hm, lom = hAt((p0 + p1) / 2, dir, width, r.Name)
					local lift = math.max(0, hm - (h0 + h1) / 2)
					h0, h1 = h0 + lift, h1 + lift
					if s == 0 then
						ends[i] = ends[i] or {}
						table.insert(ends[i], h0)
					end
					if s == n - 1 then
						ends[i + 1] = ends[i + 1] or {}
						table.insert(ends[i + 1], h1)
					end
					local a, b = Vector3.new(p0.X, h0, p0.Z), Vector3.new(p1.X, h1, p1.Z)
					local cf = CFrame.lookAt((a + b) / 2, b)
					local len = (b - a).Magnitude + 0.6
					part("Pave", cf * CFrame.new(0, -1.6, 0), Vector3.new(width, 3.2, len), C.road, f)
					for _, sd in ipairs({ -1, 1 }) do
						part("Curb", cf * CFrame.new(sd * (width / 2 - 0.4), -1.4, 0), Vector3.new(0.8, 3.2, len), C.curb, f)
					end
					nPiece += 1
					local lo = math.min(lo0, lo1, lom)
					local under = math.min(h0, h1) - 3.2
					if under - lo > 1 then
						local c = (a + b) / 2
						part("Support", CFrame.new(c.X, (under + 0.2 + lo - 1) / 2, c.Z) * CFrame.lookAt(Vector3.new(a.X, 0, a.Z), Vector3.new(b.X, 0, b.Z)).Rotation,
							Vector3.new(width - 0.4, under + 0.2 - (lo - 1), (b - a).Magnitude), C.found, f)
						nProp += 1
					end
				end
			end
			for i = 2, #pts - 1 do
				local h = math.max(table.unpack(ends[i]))
				disc("Joint", pts[i][1], pts[i][2], width / 2, h - 3.2, h - 0.02, C.road, f)
			end
		end
		say("길 %d 줄, 조각 %d, 받침 %d", #D.Roads, nPiece, nProp)
	end
	task.wait()

	--==================================================================== 5. 건물
	local placed = {}
	local foundations, maxGap = 0, 0
	local function clone(kind, x, z, yaw, parent)
		local m = kitOf(kind):Clone()
		m:PivotTo(CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(yaw), 0))
		m.Parent = parent
		return m
	end
	-- 맨 밑 층 파트들의 발자국과 그 아홉 점 땅 높이
	local function measure(m)
		local frame = m:GetPivot()
		local minY = math.huge
		local list = {}
		for _, p in ipairs(m:GetDescendants()) do
			if p:IsA("BasePart") and p.Transparency < 1 then
				local e, c = halfExtents(p, frame)
				list[#list + 1] = { e = e, c = c }
				minY = math.min(minY, c.Y - e.Y)
			end
		end
		-- 틀 바닥은 0 이다. 폐허 잔해가 조금 밑으로 묻혀(최저 −0.5) 그걸 바닥으로 삼으면 건물이 그만큼 뜬다
		minY = math.max(minY, 0)
		local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
		for _, q in ipairs(list) do
			if q.c.Y - q.e.Y < minY + 0.3 then
				x0, x1 = math.min(x0, q.c.X - q.e.X), math.max(x1, q.c.X + q.e.X)
				z0, z1 = math.min(z0, q.c.Z - q.e.Z), math.max(z1, q.c.Z + q.e.Z)
			end
		end
		local lo, hi = math.huge, -math.huge
		for _, u in ipairs({ 0.02, 0.5, 0.98 }) do
			for _, v in ipairs({ 0.02, 0.5, 0.98 }) do
				local wp = frame:PointToWorldSpace(Vector3.new(x0 + (x1 - x0) * u, 0, z0 + (z1 - z0) * v))
				local gy = groundY(wp.X, wp.Z)
				assert(gy, string.format("%s 발자국 (%.0f,%.0f) 아래에 땅이 없다", m.Name, wp.X, wp.Z))
				lo, hi = math.min(lo, gy), math.max(hi, gy)
			end
		end
		return { frame = frame, minY = minY, x0 = x0, x1 = x1, z0 = z0, z1 = z1, lo = lo, hi = hi }
	end
	local function lift(m, mm, y)
		m:PivotTo(m:GetPivot() + Vector3.new(0, y - (mm.frame.Y + mm.minY), 0))
	end
	-- 로컬 x0..x1, z0..z1 (모델 틀 기준) 밑에 lo-1 부터 top 까지 현무암 기단
	local function plinth(m, mm, x0, x1, z0, z1, lo, top)
		local c = mm.frame:PointToWorldSpace(Vector3.new((x0 + x1) / 2, 0, (z0 + z1) / 2))
		local p = part("Foundation", CFrame.new(c.X, (top + lo - 1) / 2, c.Z) * mm.frame.Rotation,
			Vector3.new(x1 - x0 + 1.0, top - (lo - 1), z1 - z0 + 1.0), C.found, m)
		foundations += 1
		maxGap = math.max(maxGap, top - lo)
		return p
	end
	local function record(m, e)
		placed[#placed + 1] = { m = m, kind = e.Kit, e = e }
	end

	-- 수도교는 한 높이로 잇는다(가장 높은 땅). 기단은 교각 밑에만 대서 길이 아치 밑으로 지나게 한다
	local aqLevel = -math.huge
	for _, e in ipairs(D.Items) do
		if e.Level == "aqueduct" then
			local m = clone(e.Kit, e.X, e.Z, e.Yaw, city)
			aqLevel = math.max(aqLevel, measure(m).hi)
			m:Destroy()
		end
	end
	local amphDone = false
	for i, e in ipairs(D.Items) do
		local parent = folder(e.Group)
		local m = clone(e.Kit, e.X, e.Z, e.Yaw, parent)
		m.Name = e.Kit
		if e.Y then
			m:PivotTo(m:GetPivot() + Vector3.new(0, e.Y, 0))
		elseif e.Level == "amph" then
			-- 네 쪽이 한 가운데를 쓴다. 땅은 한 번 재고 원판 기단 하나
			local lo, hi = circleGround(e.X, e.Z, e.Circle, rpAll)
			if not amphDone and hi - lo > 0.25 then
				disc("Amph_Foundation", e.X, e.Z, e.Circle, lo - 1, hi, C.found, parent)
				foundations += 1
				maxGap = math.max(maxGap, hi - lo)
			end
			amphDone = true
			local mm = measure(m)
			lift(m, mm, hi)
		elseif e.Level == "aqueduct" then
			local mm = measure(m)
			lift(m, mm, aqLevel)
			for _, px in ipairs({ { -20, -17 }, { -3, 3 }, { 17, 20 } }) do
				local lo = math.huge
				for _, dz in ipairs({ -3, 0, 3 }) do
					local q = mm.frame:PointToWorldSpace(Vector3.new((px[1] + px[2]) / 2, 0, dz))
					lo = math.min(lo, (assert(groundY(q.X, q.Z), "수도교 교각 밑에 땅이 없다")))
				end
				if aqLevel - lo > 0.25 then
					plinth(m, mm, px[1], px[2], -3.3, 3.3, lo, aqLevel)
				end
			end
		else
			local mm = measure(m)
			lift(m, mm, mm.hi)
			if e.Plinth == "box" and mm.hi - mm.lo > 0.25 then
				plinth(m, mm, mm.x0, mm.x1, mm.z0, mm.z1, mm.lo, mm.hi)
			end
		end
		record(m, e)
		if e.Kit == "Brazier" and e.Group ~= "Seal" then
			-- 폐허: 광장 불화로는 꺼져 식은 숯만 남았다. 봉인 단(제단 참배길) 것만 아직 탄다
			for _, d in ipairs(m:GetDescendants()) do
				if d:IsA("Fire") or d:IsA("Light") or d:IsA("ParticleEmitter") then
					d:Destroy()
				elseif d:IsA("BasePart") and d.Material == Enum.Material.Neon then
					d.Color, d.Material = C.crust[1], C.crust[2]
				end
			end
		end
		if e.FireGladius then
			-- 레가투스의 불의 글라디우스. 본부 안뜰 바닥(윗면 1.1, 가운데 z -2)에 선다
			local g = kit.Fire_Gladius:Clone()
			g:PivotTo(m:GetPivot() * CFrame.new(0, 1.1, -2))
			g.Name = "Fire_Gladius"
			g.Parent = parent
			placed[#placed + 1] = { m = g, kind = "Fire_Gladius", e = e }
		end
		if i % 8 == 0 then
			task.wait()
		end
	end
	say("건물 %d, 기단 %d (가장 큰 높이차 %.1f), 수도교 높이 %.1f", #placed, foundations, maxGap, aqLevel)

	-- 잔해(2026-09-29). 무너진 지붕·위층 잔해는 메시에 굽지 않고 여기서 **실제 바닥 위에** 얹는다 — 메시에 구웠더니
	-- 건물을 기단·비탈에 앉힐 때 잔해도 같이 떠 버렸다(사용자: "잔해들이 공중에 떠 있다").
	-- 건물 발자국을 고루 찍어 위에서 광선을 쏜다. 처음 맞는 면이 건물 바닥 +1.6 안쪽의 평평한 면이면 지붕이 사라진
	-- 자리다 → 그 건물 벽 빛의 블록 1~3 개를 기울여 반쯤 묻는다. 지붕·벽 윗면에 맞으면 건너뛴다(반쯤 무너진 랜드마크는
	-- 무너진 곳에만 잔해가 쌓인다). 다리·수도교·기둥은 길이 지나가므로 뺀다.
	do
		local SKIP = { Bridge_Span = true, Aqueduct_Span = true, Victory_Column = true, Market_Stall = true, Crane = true }
		local RUINED = {
			Domus = true, Insula_A = true, Insula_B = true, Taberna_Row = true, Barracks = true, Thermae = true, Basilica = true,
			Temple_Small = true, Watchtower = true, Wall_Seg = true, Wall_Tower = true, Principia = true, Palatium = true,
			Temple_Ignus = true, Amph_Quarter = true, City_Gate = true, Triumphal_Arch = true,
		}
		local STONE = { [M.Marble] = true, [M.Limestone] = true, [M.Plaster] = true, [M.Brick] = true, [M.ClayRoofTiles] = true,
			[M.Basalt] = true, [M.WoodPlanks] = true, [M.SmoothPlastic] = true, [M.Sand] = true }
		local rng = Random.new(92929)
		local nRubble, nSpots = 0, 0
		for i, p in ipairs(placed) do
			local base = string.gsub(p.kind, "_2$", "")
			if not RUINED[base] or SKIP[base] then
				continue
			end
			local m = p.m
			-- 이 건물의 돌·벽 빛(크기만큼 뽑힐 몫)
			local looks, total = {}, 0
			for _, q in ipairs(m:GetDescendants()) do
				if q:IsA("BasePart") and q.Transparency < 0.5 and STONE[q.Material] and q.Name ~= "Foundation" then
					local w = q.Size.Magnitude
					total += w
					looks[#looks + 1] = { w = total, col = { q.Color, q.Material } }
				end
			end
			if #looks == 0 then
				continue
			end
			local function pick()
				local r = rng:NextNumber() * total
				for _, l in ipairs(looks) do
					if r <= l.w then
						return l.col
					end
				end
				return looks[#looks].col
			end
			local mm = measure(m)
			local frame = mm.frame
			local floorY = frame.Y + mm.minY
			local rp = RaycastParams.new()
			rp.FilterType = Enum.RaycastFilterType.Include
			rp.FilterDescendantsInstances = { m, G, FPave }
			local w, d = mm.x1 - mm.x0, mm.z1 - mm.z0
			local spots = math.clamp(math.floor(w * d / 55), 3, 26)
			for _ = 1, spots do
				local lp = Vector3.new(mm.x0 + w * rng:NextNumber(0.08, 0.92), 0, mm.z0 + d * rng:NextNumber(0.08, 0.92))
				local wp = frame:PointToWorldSpace(lp)
				local hit = workspace:Raycast(Vector3.new(wp.X, floorY + 80, wp.Z), Vector3.new(0, -120, 0), rp)
				if hit and hit.Normal.Y > 0.8 and hit.Position.Y <= floorY + 1.6 then
					nSpots += 1
					for _ = 1, rng:NextInteger(1, 3) do
						local s = rng:NextNumber(0.6, 2.2)
						local at = hit.Position + Vector3.new(rng:NextNumber(-1.2, 1.2), s * 0.22, rng:NextNumber(-1.2, 1.2))
						local cf = CFrame.new(at) * CFrame.Angles(math.rad(rng:NextNumber(-22, 22)), math.rad(rng:NextNumber(0, 180)), math.rad(rng:NextNumber(-22, 22)))
						local r = part("Rubble", cf, Vector3.new(s * rng:NextNumber(1.0, 1.5), s * rng:NextNumber(0.5, 0.8), s * rng:NextNumber(0.8, 1.2)), pick(), m)
						-- 큰 덩어리만 막는다(작은 조각에 발이 걸리지 않게)
						r.CanCollide = s > 1.6
						nRubble += 1
					end
				end
			end
			if i % 10 == 0 then
				task.wait()
			end
		end
		say("잔해: 자리 %d, 조각 %d", nSpots, nRubble)
	end

	-- 샘집(카스텔룸 아쿠아이). 수도교 북쪽 끝(z -3540)에 붙은 트래버틴 탑. 꼭대기에 온천물이 괴어 김이 오르고,
	-- 북쪽 면으로 물줄기가 흘러내려 아래 온천 계단 못으로 간다
	do
		local f = folder("Aqueduct/샘집")
		local X, Z, W, Dp = -998, -3549, 14, 16
		local cf = CFrame.new(X, 0, Z)
		local lo = rectGround(cf, W, Dp, 7, rpG)
		local top = aqLevel + 43.7
		part("Castellum", CFrame.new(X, (top - 1.2 + lo - 1) / 2, Z), Vector3.new(W, top - 1.2 - (lo - 1), Dp), C.trav, f)
		part("Cornice", CFrame.new(X, top - 0.8, Z), Vector3.new(W + 1.6, 0.8, Dp + 1.6), C.travWhite, f)
		-- 층띠 셋, 모서리 기둥 넷, 동서 면의 어두운 아치 창 두 층
		for k = 1, 3 do
			local y = lo + (top - lo) * k / 4
			part("Band", CFrame.new(X, y, Z), Vector3.new(W + 0.8, 0.6, Dp + 0.8), C.travWhite, f)
		end
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				part("Pilaster", CFrame.new(X + sx * (W / 2 - 0.3), (top + lo) / 2, Z + sz * (Dp / 2 - 0.3)), Vector3.new(1.4, top - lo, 1.4), C.travWhite, f)
			end
			for k = 1, 2 do
				local y = lo + (top - lo) * (k + 1) / 4 - (top - lo) / 8
				part("Window", CFrame.new(X + sx * (W / 2 + 0.05), y, Z), Vector3.new(0.3, (top - lo) / 8, 3.2), C.basalt, f)
			end
		end
		for _, sd in ipairs({ -1, 1 }) do
			part("Parapet", CFrame.new(X + sd * (W / 2 - 0.2), top + 0.6, Z), Vector3.new(0.8, 2.0, Dp + 1.6), C.travWhite, f)
		end
		part("Parapet", CFrame.new(X, top + 0.6, Z - Dp / 2 - 0.4), Vector3.new(W + 1.6, 2.0, 0.8), C.travWhite, f)
		local w = part("Pool", CFrame.new(X, top - 0.1, Z), Vector3.new(W - 0.4, 0.3, Dp), C.hotwater, f)
		w.Transparency = 0.25
		-- 북쪽 면 아치 문과 흘러내리는 물줄기
		part("Door", CFrame.new(X, lo + 5, Z - Dp / 2 - 0.05), Vector3.new(5, 10, 0.3), C.basalt, f)
		local fall = part("Spill", CFrame.new(X, (top + lo) / 2, Z - Dp / 2 - 0.9), Vector3.new(1.6, top - lo, 0.4), C.hotwater, f)
		fall.Transparency = 0.35
		fall.CanCollide = false
		steam(marker("Steam", Vector3.new(X, top + 1, Z), f), 4)
		steam(marker("Steam_Foot", Vector3.new(X, lo + 1, Z - Dp / 2 - 2), f), 3)
		say("샘집 높이 %.1f → %.1f", lo, top)
	end

	--==================================================================== 6. 다리 내림길
	-- 다리 남쪽 끝 바닥(78 가량)에서 봉인 단 아래 단 가장자리로 완만히 내려가는 판. 밑은 현무암 받침
	do
		local last, deckTop
		for _, p in ipairs(placed) do
			if p.kind == "Bridge_Span" and (not last or p.e.Z > last.e.Z) then
				last = p
			end
		end
		assert(last, "다리가 없다")
		local rpB = RaycastParams.new()
		rpB.FilterType = Enum.RaycastFilterType.Include
		rpB.FilterDescendantsInstances = { last.m }
		local hit = assert(workspace:Raycast(Vector3.new(last.e.X, 300, last.e.Z), Vector3.new(0, -400, 0), rpB), "다리 바닥을 못 찾았다")
		deckTop = hit.Position.Y
		local zEnd = last.e.Z + 25 - 0.5 -- 다리 틀 로컬 x -25 끝(yaw 90 이라 +z)
		local zDais = SD.Z - 76 + 1.5
		local a = Vector3.new(SD.X, deckTop, zEnd)
		local b = Vector3.new(SD.X, sealTop - 1.4, zDais)
		local f = folder("바닥/내림길")
		local cf = CFrame.lookAt((a + b) / 2, b)
		part("Landing", cf * CFrame.new(0, -0.6, 0), Vector3.new(14, 1.2, (b - a).Magnitude + 1), C.trav, f)
		for _, sd in ipairs({ -1, 1 }) do
			part("Curb", cf * CFrame.new(sd * 6.6, -0.4, 0), Vector3.new(0.8, 1.2, (b - a).Magnitude + 1), C.curb, f)
		end
		local lo = math.huge
		for _, q in ipairs({ a, b, (a + b) / 2 }) do
			for _, dx in ipairs({ -7, 0, 7 }) do
				lo = math.min(lo, groundY(q.X + dx, q.Z, rpG) or lo)
			end
		end
		local under = math.min(a.Y, b.Y) - 1.2
		if under - lo > 0.5 then
			part("Support", CFrame.new(SD.X, (under + lo - 1) / 2, (a.Z + b.Z) / 2), Vector3.new(13, under - lo + 1, math.abs(b.Z - a.Z)), C.found, f)
		end
		say("다리 바닥 %.2f, 내림길 %.1f → %.1f (z %.0f → %.0f)", deckTop, a.Y, b.Y, a.Z, b.Z)
	end
	task.wait()

	--==================================================================== 8. 거인 발자국
	-- 옛 거인이 디딘 자리. 불탄 발바닥 모양(뒤꿈치·발바닥·앞꿈치·발가락 다섯)을 어두운 껍질로 깔고 가장자리가 빛난다
	do
		local FF = folder("Ruins/거인 발자국")
		-- 뒤꿈치 → 바깥쪽 발바닥(안쪽은 아치라 비었다) → 앞꿈치 둘 → 떨어진 발가락 다섯(엄지는 안쪽 -x)
		local SHAPE = { -- 로컬(발끝 = -z) x, z, 반지름. 오른발 기준, 왼발은 x 를 뒤집는다
			{ 0.5, 13, 6.5 }, { 3.0, 5, 5.0 }, { 3.4, -1, 5.2 }, { -1.5, -8, 7.5 }, { 2.8, -7, 6.0 },
			{ -5.6, -19.5, 3.3 }, { 0.2, -19.2, 2.4 }, { 4.6, -18.0, 2.2 }, { 7.6, -16.0, 2.0 }, { 10.0, -13.0, 1.8 },
		}
		local SC = 1.8
		local n = 0
		for _, fp in ipairs(D.Footprints) do
			local cf = CFrame.new(fp[1], 0, fp[2]) * CFrame.Angles(0, math.rad(fp[3]), 0)
			-- 한 발자국은 한 높이(겹친 원판끼리 빛 테가 껍질 위로 올라오지 않게)
			local lo, hi = circleGround(fp[1], fp[2], 42, rpG)
			for _, s in ipairs(SHAPE) do
				local w = cf:PointToWorldSpace(Vector3.new(s[1] * fp[4] * SC, 0, s[2] * SC))
				local r = s[3] * SC
				disc("Scorch", w.X, w.Z, r + 0.8, lo - 0.6, hi + 0.12, C.lava, FF)
				disc("Print", w.X, w.Z, r, lo - 0.5, hi + 0.3, C.crust2, FF)
				n += 2
			end
		end
		say("거인 발자국 %d, 조각 %d", #D.Footprints, n)
	end

	--==================================================================== 9. 마른 포도밭
	-- 버려져 말라 죽은 포도 줄: 낮고, 군데군데 줄이 빠지고 말뚝만 남았다
	do
		local nV = 0
		local rngV = Random.new(9)
		for _, v in ipairs(D.Vines) do
			local f = folder("지열/포도밭/" .. v.Name)
			local cf = CFrame.new(v.X, 0, v.Z) * CFrame.Angles(0, math.rad(v.Yaw), 0)
			local z = -v.D / 2 + v.Sp / 2
			while z <= v.D / 2 do
				local nseg = math.max(1, math.ceil(v.W / 10))
				local seg = v.W / nseg
				for k = 0, nseg - 1 do
					local x0 = -v.W / 2 + k * seg
					local lo, hi = math.huge, -math.huge
					for _, t in ipairs({ 0, 0.5, 1 }) do
						local w = cf:PointToWorldSpace(Vector3.new(x0 + seg * t, 0, z))
						local gy = assert(groundY(w.X, w.Z, rpG), v.Name .. " 밑에 땅이 없다")
						lo, hi = math.min(lo, gy), math.max(hi, gy)
					end
					local c = cf:PointToWorldSpace(Vector3.new(x0 + seg / 2, 0, z))
					local top, bot = hi + rngV:NextNumber(0.9, 1.6), lo - 0.3
					if rngV:NextNumber() > 0.3 then
						part("Vine", CFrame.new(c.X, (top + bot) / 2, c.Z) * cf.Rotation, Vector3.new(seg - 0.9, top - bot, 1.2), C.vine, f)
					end
					local pw = cf:PointToWorldSpace(Vector3.new(x0, 0, z))
					local py = groundY(pw.X, pw.Z, rpG)
					part("Stake", CFrame.new(pw.X, py + 1.35, pw.Z) * cf.Rotation, Vector3.new(0.35, 3.4, 0.35), C.wood, f)
					nV += 2
				end
				z += v.Sp
			end
		end
		say("포도밭 %d, 파트 %d", #D.Vines, nV)
	end

	--==================================================================== 10. 온천 계단 못
	-- 흰 트래버틴 턱 위로 물이 찰랑 넘친다(물판이 턱보다 0.05 높다). 김이 오른다
	do
		local f = folder("지열/온천 못")
		for i, p in ipairs(D.Pools) do
			local x, z, r = p[1], p[2], p[3]
			local lo, hi = circleGround(x, z, r + 1.5, rpG)
			-- 비탈 턱에 걸친 못은 아래로 넓게 퍼진 석회 퇴적(한 단 더)이 받친다 — 가는 기둥처럼 보이지 않게
			if hi - lo > 1.5 then
				disc("Apron", x, z, r + 4, lo - 1, (lo + hi) / 2, C.travWhite, f)
			end
			disc("Rim", x, z, r + 1.5, (hi - lo > 1.5) and (lo + hi) / 2 - 0.5 or lo - 1, hi + 1.2, C.travWhite, f)
			local w = disc("Water", x, z, r, hi + 0.6, hi + 1.25, C.hotwater, f)
			w.Transparency = 0.25
			w.CastShadow = false
			steam(marker("Steam_" .. i, Vector3.new(x, hi + 1.6, z), f), 5)
		end
		say("온천 못 %d", #D.Pools)
	end

	--==================================================================== 11. 분기공
	do
		local f = folder("지열/분기공")
		local rng = Random.new(77)
		for i, p in ipairs(D.Fumaroles) do
			local x, z = p[1], p[2]
			local y = assert(groundY(x, z, rpG), "분기공 밑에 땅이 없다")
			-- 유황 자국 두 겹(한쪽으로 흘러 번진 꼴) + 둘레 돌 다섯 + 가운데 검은 구멍
			local ga = rng:NextNumber(0, 2 * math.pi)
			disc("Sulfur", x, z, 6.5, y - 0.4, y + 0.1, C.sulfur, f)
			disc("Sulfur", x + 5 * math.sin(ga), z + 5 * math.cos(ga), 4.2, y - 0.4, y + 0.12, C.sulfur, f)
			disc("Vent", x, z, 1.4, y - 0.3, y + 0.16, C.basalt, f)
			for k = 1, 5 do
				local a = (k / 5 + rng:NextNumber(-0.06, 0.06)) * 2 * math.pi
				local s = rng:NextNumber(2.4, 4.6)
				part("Rock", CFrame.new(x + 3.4 * math.sin(a), y + s * 0.3, z + 3.4 * math.cos(a))
					* CFrame.Angles(math.rad(rng:NextNumber(-25, 25)), a, math.rad(rng:NextNumber(-25, 25))),
					Vector3.new(s, s * 0.8, s * 1.1), C.basalt, f)
			end
			local e = steam(marker("Vent_" .. i, Vector3.new(x, y + 0.6, z), f), 8, false, true)
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 12) })
			e.Speed = NumberRange.new(4, 7)
		end
		say("분기공 %d", #D.Fumaroles)
	end

	--==================================================================== 11b. 에쉬스 마을(버려짐)
	-- 계급 맨 아래 에쉬스가 살던 곳. 고원 밑 바닷가 턱(46)에 재 빛 판잣집 열둘, 가운데 식은 공동 화덕과 재 더미,
	-- 골목 하나, 고원 끝에서 내려오는 돌계단. 판잣집은 뒤로 기운 외쪽 지붕, 앞에 문 구멍.
	-- 사람이 떠났다: 연기는 없고, 몇 채는 지붕이 안으로 내려앉았다(배치표 일곱째 값)
	do
		local f = folder("에쉬스 마을")
		local A = D.Ash
		local ash = { RGB(122, 116, 110), M.Slate }
		local ashDark = { RGB(82, 78, 76), M.Slate }
		local plank = { RGB(84, 66, 52), M.WoodPlanks }
		local soot = { RGB(150, 146, 140), M.Sand }
		for i, hh in ipairs(A.Huts) do
			local x, z, yaw, w, d, h, fallen = hh[1], hh[2], hh[3], hh[4], hh[5], hh[6], hh[7]
			local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(yaw), 0)
			local lo, hi = rectGround(cf, w + 1, d + 1, 3, rpG)
			local base = hi + 0.4
			local function at(lx, y, lz)
				local p = cf:PointToWorldSpace(Vector3.new(lx, 0, lz))
				return CFrame.new(p.X, y, p.Z) * cf.Rotation
			end
			local m = Instance.new("Model")
			m.Name = "Hut_" .. i
			m.Parent = f
			part("Floor", at(0, (base + lo - 1) / 2, 0), Vector3.new(w + 1, base - lo + 1, d + 1), ashDark, m)
			local hf, hb = h + 0.8, h - 0.8 -- 앞벽이 높고 뒷벽이 낮다(지붕이 뒤로 기움)
			part("WallBack", at(0, base + hb / 2, d / 2 - 0.4), Vector3.new(w, hb, 0.8), ash, m)
			for _, sx in ipairs({ -1, 1 }) do
				part("WallSide", at(sx * (w / 2 - 0.4), base + h / 2, 0), Vector3.new(0.8, h, d - 1.6), ash, m)
				local pw = w / 2 - 1.5
				part("WallFront", at(sx * (1.5 + pw / 2), base + hf / 2, -d / 2 + 0.4), Vector3.new(pw, hf, 0.8), ash, m)
			end
			part("Lintel", at(0, base + 5 + (hf - 5) / 2, -d / 2 + 0.4), Vector3.new(3, hf - 5, 0.8), plank, m)
			if fallen then
				-- 내려앉은 지붕: 앞 끝은 앞벽 위에 걸리고 뒤 끝은 바닥에 닿았다. 조금 비틀렸다
				local drop = math.atan2(hf - 0.6, d)
				part("Roof", at(0.5, base + (hf - 0.6) / 2 + 0.3, 0) * CFrame.Angles(drop, math.rad(7), 0), Vector3.new(w - 1.4, 0.4, d / math.cos(drop)), plank, m)
				part("RoofAsh", at(-w * 0.2, base + 0.3, d / 2 - 1.6), Vector3.new(w * 0.4, 0.5, 1.6), soot, m)
			else
				local ang = math.atan2(hf - hb, d)
				part("Roof", at(0, base + h + 0.3, 0) * CFrame.Angles(ang, 0, 0), Vector3.new(w + 1.2, 0.4, d / math.cos(ang) + 1.4), plank, m)
				-- 지붕에 앉은 재
				part("RoofAsh", at(-w * 0.15, base + h + 0.55, 0.5) * CFrame.Angles(ang, 0, 0), Vector3.new(w * 0.55, 0.12, d * 0.6), soot, m)
			end
		end
		-- 골목(재 흙길)
		do
			local a, b = A.Lane[1], A.Lane[2]
			local len = math.abs(b[1] - a[1])
			local n = math.ceil(len / 10)
			for k = 0, n - 1 do
				local x0 = math.min(a[1], b[1]) + len * k / n
				local cfp = CFrame.new(x0 + len / n / 2, 0, a[2])
				local lo, hi = rectGround(cfp, len / n, 4, 2, rpG)
				part("Lane", CFrame.new(x0 + len / n / 2, (hi + 0.15 + lo - 0.6) / 2, a[2]), Vector3.new(len / n + 0.4, hi + 0.15 - (lo - 0.6), 4), soot, f)
			end
		end
		-- 공동 화덕(흙 둥근 가마, 불 꺼진 지 오래)과 재 더미
		do
			local sx, sz = A.Square[1], A.Square[2]
			local y = assert(groundY(sx, sz, rpG), "에쉬스 광장 밑이 비었다")
			disc("OvenBase", sx, sz, 3.2, y - 0.5, y + 0.8, ashDark, f)
			part("Oven", CFrame.new(sx, y + 1.2, sz), Vector3.new(5.6, 5.6, 5.6), { RGB(124, 76, 58), M.Brick }, f, Enum.PartType.Ball)
			part("OvenMouth", CFrame.new(sx, y + 1.6, sz - 2.6), Vector3.new(1.8, 1.4, 0.6), C.crust, f)
			for k, o in ipairs({ { 7, 3, 3.2 }, { 9, -2, 2.4 }, { -8, 4, 2.8 } }) do
				local gx, gz = sx + o[1], sz + o[2]
				local gy = groundY(gx, gz, rpG) or y
				part("AshHeap" .. k, CFrame.new(gx, gy - o[3] * 0.45, gz), Vector3.new(o[3] * 2, o[3] * 2, o[3] * 2), soot, f, Enum.PartType.Ball)
			end
		end
		-- 돌계단(고원 끝 → 턱). 칸 높이 2 이하
		do
			local s0, s1 = A.Stair[1], A.Stair[2]
			local top = assert(groundY(s0[1], s0[2], rpG), "계단 윗머리 밑이 비었다") + 0.3
			local bottom = assert(groundY(s1[1], s1[2], rpG), "계단 아래 밑이 비었다") + 0.3
			local n = math.max(1, math.ceil((top - bottom) / 1.8))
			local dz = (s1[2] - s0[2]) / n
			for k = 0, n - 1 do
				local zc = s0[2] + dz * (k + 0.5)
				local t = top - (top - bottom) * (k + 1) / n
				local g = math.min(groundY(s0[1], zc, rpG) or bottom, t) - 1
				part("Step", CFrame.new(s0[1], (t + g) / 2, zc), Vector3.new(6, t - g, math.abs(dz) + 0.05), C.basalt, f)
			end
			for _, sd in ipairs({ -1, 1 }) do
				local a = Vector3.new(s0[1] + sd * 3.4, top + 1.2, s0[2])
				local b = Vector3.new(s1[1] + sd * 3.4, bottom + 1.2, s1[2])
				part("Rail", CFrame.lookAt((a + b) / 2, b), Vector3.new(0.35, 0.35, (b - a).Magnitude), plank, f)
			end
			say("에쉬스 마을: 판잣집 %d, 계단 %d칸 (%.1f → %.1f)", #A.Huts, n, top, bottom)
		end
	end

	--==================================================================== 12. 훈련장 기둥(팔루스)
	do
		local f = folder("Legion/훈련장")
		local t = D.Train
		local cf = CFrame.new(t.X, 0, t.Z) * CFrame.Angles(0, math.rad(t.Yaw), 0)
		for _, lx in ipairs({ -13.5, -4.5, 4.5, 13.5 }) do
			for _, lz in ipairs({ -12, 0, 12 }) do
				local w = cf:PointToWorldSpace(Vector3.new(lx, 0, lz))
				local y = assert(groundY(w.X, w.Z), "훈련장 밑이 비었다")
				part("Palus", CFrame.new(w.X, y + 3, w.Z) * cf.Rotation, Vector3.new(0.9, 6, 0.9), C.wood, f)
			end
		end
	end

	--==================================================================== 13. 남의 것과 겹침
	do
		local op = OverlapParams.new()
		op.FilterType = Enum.RaycastFilterType.Exclude
		op.FilterDescendantsInstances = { city, G, workspace.Terrain }
		local byParent = {}
		for _, p in ipairs(placed) do
			local cf, size = p.m:GetBoundingBox()
			for _, q in ipairs(workspace:GetPartBoundsInBox(cf, size, op)) do
				local key = q.Parent and q.Parent:GetFullName() or "?"
				byParent[key] = (byParent[key] or 0) + 1
			end
		end
		local n = 0
		for k, v in pairs(byParent) do
			say("  남의 것 겹침: %s ×%d", k, v)
			n += 1
		end
		say("남의 것 겹침 무리 %d", n)
	end
	say("파트 %d(틀 제외)", nParts)
end)
if not okRun then
	say("ERR %s", tostring(errRun))
end
local HS = game:GetService("HttpService")
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/roman_city", table.concat(report, "\n"))
end)
print("roman_city", okRun, #report)
