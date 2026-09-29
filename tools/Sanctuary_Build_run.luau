--!nocheck
--[[
	Sanctuary_Build.luau — 2026-09-27. 탑의 성역 리메이크를 짓는다.

	배치는 tools/sanctuary_plan.py 의 표(→ Sanctuary_data.luau), 모델은 ServerStorage.SanctuaryKit(Sanctuary_Kit.luau),
	탑 계단 점은 Sanctuary_steps.luau. python tools/sanctuary_run.py 가 셋을 합쳐 Sanctuary_Build_run.luau 를 만든다.

	하는 일
	  1. 옛 성역(Ruins_·Fill_·Struct_탑의성역)을 ServerStorage.탑의성역_옛것 으로 옮긴다(지우지 않는다)
	  2. 섬 땅 조각(World.G_탑의성역 의 Gs_) 중 모래 아닌 것을 잔디로. 원래 빛은 OrigColor/OrigMat 속성에
	  3. Surface.Sanctuary_탑의성역 에 새로 짓는다 (다시 돌리면 지우고 새로)
	     Floor     안뜰 단(흰 돌 원판, 청화·금 띠, 나침 무늬), 네 계단, 길 포석과 청화 연석, 반사지, 큰 문 앞마당
	     Tower     기단, 탑 여섯 토막, 코어·껍질·도는 파편(Spin 스크립트), 보이지 않는 충돌(기둥 원통, 계단 비탈)
	     Colonnade 열주와 인방
	     Items     나머지(표대로 땅에 광선을 쏴 앉힌다)
	되돌리기: Sanctuary_탑의성역 을 지우고 옛것 셋을 Surface 로, 땅 조각은 속성으로 되칠한다.
]]

local D = (function()
-- sanctuary_plan.py 가 적은 표. 손으로 고치지 말고 sanctuary_plan.py 를 고쳐 다시 뽑는다
local D = {}
D.CX, D.CZ, D.TT = 400, -1467, 16.65
D.TERRACE_R, D.RING_R, D.PLINTH_R = 178, 172, 98
D.ITEMS = {
	{"Great_Gate", 400, -799, 180, 0},
	{"Guardian", 381, -1205, -90, 0},
	{"Guardian", 419, -1205, 90, 0},
	{"Guardian", 381, -1085, -90, 0},
	{"Guardian", 419, -1085, 90, 0},
	{"Guardian", 381, -965, -90, 0},
	{"Guardian", 419, -965, 90, 0},
	{"Guardian", 381, -845, -90, 0},
	{"Guardian", 419, -845, 90, 0},
	{"Obelisk", 356, -1253, 0, 0},
	{"Obelisk", 444, -1253, 0, 0},
	{"Obelisk", 356, -851, 0, 0},
	{"Obelisk", 444, -851, 0, 0},
	{"Bench", 371.6, -1167, 90, 0},
	{"Bench", 428.4, -1167, -90, 0},
	{"Bench", 371.6, -927, 90, 0},
	{"Bench", 428.4, -927, -90, 0},
	{"Tholos", 870, -1467, 90, 0},
	{"Tholos", -70, -1467, -90, 0},
	{"Pavilion", 400, -1917, 0, 0},
	{"Blossom", 372, -1889, 0, 0},
	{"Blossom_B", 428, -1889, 40, 0},
	{"Blossom_B", 372, -1945, 200, 0},
	{"Blossom", 428, -1945, 120, 0},
	{"Bench", 380, -1917, 90, 0},
	{"Bench", 420, -1917, -90, 0},
	{"Obelisk", 386, -1871, 0, 0},
	{"Obelisk", 414, -1871, 0, 0},
	{"Cypress_Tall", 604, -1445, 0, 0},
	{"Cypress_Tall", 604, -1489, 0, 0},
	{"Cypress_Tall", 196, -1445, 0, 0},
	{"Cypress_Tall", 196, -1489, 0, 0},
	{"Cypress_Tall", 422, -1671, 0, 0},
	{"Cypress_Tall", 378, -1671, 0, 0},
	{"Chunk_Rib", 596, -1111, 30, 3},
	{"Chunk_Block", 830, -1167, 15, 1},
	{"Blossom", 662, -1231, 0, 0},
	{"Blossom_B", 696, -1211, 60, 0},
	{"Blossom", 638, -1167, 140, 0},
	{"Statue_Broken", 550, -947, 200, 0},
	{"Bench", 680, -1277, 180, 0},
	{"Chunk_Block", 204, -997, -20, 1},
	{"Chunk_Rib", 64, -1231, 150, 3},
	{"Blossom_B", 148, -1131, 0, 0},
	{"Blossom", 104, -1083, 80, 0},
	{"Blossom", 190, -1075, 160, 0},
	{"Statue_Broken", 250, -1167, 160, 0},
	{"Chunk_Rib", 662, -1703, -60, 3},
	{"Blossom", 736, -1767, 0, 0},
	{"Blossom_B", 776, -1717, 90, 0},
	{"Statue_Broken", 550, -1797, 20, 0},
	{"Chunk_Block", 840, -1853, 40, 1},
	{"Chunk_Block", 150, -1751, 70, 1},
	{"Blossom", 66, -1801, 0, 0},
	{"Blossom_B", 108, -1851, 30, 0},
	{"Statue_Broken", 240, -1729, -30, 0},
	{"Chunk_Rib", -62, -1673, 100, 3},
	{"Obelisk", 697, -1170, 45, 0},
	{"Obelisk", 103, -1170, -45, 0},
	{"Obelisk", 103, -1764, 45, 0},
	{"Obelisk", 697, -1764, -45, 0},
	{"Blossom", 718, -1137, 0, 0},
	{"Blossom_B", 70, -1149, 0, 0},
	{"Blossom", 82, -1729, 0, 0},
	{"Blossom_B", 662, -1785, 0, 0},
	{"Cypress_Tall", 760, -997, 0, 0},
	{"Cypress", 780, -967, 0, 0},
	{"Cypress", 740, -961, 0, 0},
	{"Blossom", 796, -1015, 30, 0},
	{"Blossom_B", 730, -1027, 90, 0},
	{"Cypress", 920, -1297, 0, 0},
	{"Cypress_Tall", 948, -1277, 0, 0},
	{"Blossom", 960, -1327, 0, 0},
	{"Cypress", 910, -1247, 0, 0},
	{"Cypress_Tall", 28, -987, 0, 0},
	{"Cypress", 0, -1017, 0, 0},
	{"Blossom_B", 54, -1015, 60, 0},
	{"Cypress", -6, -957, 0, 0},
	{"Cypress", -140, -1271, 0, 0},
	{"Cypress_Tall", -120, -1307, 0, 0},
	{"Blossom", -166, -1297, 0, 0},
	{"Blossom_B", -100, -1255, 0, 0},
	{"Cypress_Tall", 820, -1937, 0, 0},
	{"Cypress", 792, -1967, 0, 0},
	{"Blossom_B", 852, -1967, 120, 0},
	{"Cypress", 940, -1657, 0, 0},
	{"Cypress_Tall", 966, -1681, 0, 0},
	{"Blossom", 930, -1707, 0, 0},
	{"Cypress_Tall", -10, -1937, 0, 0},
	{"Cypress", 20, -1967, 0, 0},
	{"Blossom", -40, -1973, 200, 0},
	{"Cypress", -36, -1907, 0, 0},
	{"Cypress", -140, -1637, 0, 0},
	{"Blossom_B", -166, -1667, 0, 0},
	{"Cypress_Tall", -120, -1693, 0, 0},
	{"Lantern_Blue", 515.5, -1419.2, 0, 0},
	{"Lantern_Blue", 447.8, -1351.5, 0, 0},
	{"Lantern_Blue", 352.2, -1351.5, 0, 0},
	{"Lantern_Blue", 284.5, -1419.2, 0, 0},
	{"Lantern_Blue", 284.5, -1514.8, 0, 0},
	{"Lantern_Blue", 352.2, -1582.5, 0, 0},
	{"Lantern_Blue", 447.8, -1582.5, 0, 0},
	{"Lantern_Blue", 515.5, -1514.8, 0, 0},
	{"Col_Intact", 570.918, -1447.742, -6.429, 0},
	{"Col_Intact", 562.348, -1410.192, -19.286, 0},
	{"Col_Intact", 545.637, -1375.491, -32.143, 0},
	{"Col_BrokenA", 521.623, -1345.378, -45, 0},
	{"Col_Intact", 491.511, -1321.364, -57.857, 0},
	{"Col_Intact", 456.81, -1304.653, -70.714, 0},
	{"Col_Intact", 419.26, -1296.082, -83.571, 0},
	{"Col_Intact", 380.745, -1296.081, -96.428, 0},
	{"Col_Intact", 343.195, -1304.651, -109.285, 0},
	{"Col_Intact", 308.494, -1321.361, -122.142, 0},
	{"Col_Intact", 278.381, -1345.375, -134.999, 0},
	{"Col_Intact", 254.366, -1375.487, -147.856, 0},
	{"Col_Fallen", 215.001, -1402.26, -160.713, 0},
	{"Col_Intact", 229.082, -1447.737, -173.57, 0},
	{"Col_Intact", 229.081, -1486.252, -186.427, 0},
	{"Col_BrokenB", 237.65, -1523.802, -199.284, 0},
	{"Col_BrokenA", 254.36, -1558.504, -212.141, 0},
	{"Col_Intact", 278.373, -1588.617, -224.998, 0},
	{"Col_Intact", 308.484, -1612.633, -237.855, 0},
	{"Col_Fallen", 335.257, -1651.998, -250.712, 0},
	{"Col_BrokenB", 380.734, -1637.918, -263.569, 0},
	{"Col_BrokenA", 419.249, -1637.919, -276.426, 0},
	{"Col_Intact", 456.799, -1629.351, -289.283, 0},
	{"Col_Intact", 491.501, -1612.642, -302.14, 0},
	{"Col_BrokenB", 521.615, -1588.63, -314.997, 0},
	{"Col_Intact", 545.631, -1558.519, -327.854, 0},
	{"Col_Fallen", 584.997, -1531.747, -340.711, 0},
	{"Col_Intact", 570.917, -1486.269, -353.568, 0},
	{"Cypress", 330, -1231, 0, 0},
	{"Cypress_Tall", 330, -1195, 47, 0},
	{"Cypress", 330, -1159, 94, 0},
	{"Cypress_Tall", 330, -1123, 141, 0},
	{"Cypress", 330, -1087, 188, 0},
	{"Cypress_Tall", 330, -1051, 235, 0},
	{"Cypress", 330, -1015, 282, 0},
	{"Cypress_Tall", 330, -979, 329, 0},
	{"Cypress", 330, -943, 16, 0},
	{"Cypress_Tall", 330, -907, 63, 0},
	{"Cypress", 330, -871, 110, 0},
	{"Cypress_Tall", 470, -1231, 157, 0},
	{"Cypress", 470, -1195, 204, 0},
	{"Cypress_Tall", 470, -1159, 251, 0},
	{"Cypress", 470, -1123, 298, 0},
	{"Cypress_Tall", 470, -1087, 345, 0},
	{"Cypress", 470, -1051, 32, 0},
	{"Cypress_Tall", 470, -1015, 79, 0},
	{"Cypress", 470, -979, 126, 0},
	{"Cypress_Tall", 470, -943, 173, 0},
	{"Cypress", 470, -907, 220, 0},
	{"Cypress_Tall", 470, -871, 267, 0},
	{"Lantern_Blue", 384.5, -1265, 0, 0},
	{"Lantern_Blue", 415.5, -1265, 0, 0},
	{"Lantern_Blue", 384.5, -1145, 0, 0},
	{"Lantern_Blue", 415.5, -1145, 0, 0},
	{"Lantern_Blue", 384.5, -1025, 0, 0},
	{"Lantern_Blue", 415.5, -1025, 0, 0},
	{"Lantern_Blue", 384.5, -905, 0, 0},
	{"Lantern_Blue", 415.5, -905, 0, 0},
	{"Lantern_Blue", 384.5, -821, 0, 0},
	{"Lantern_Blue", 415.5, -821, 0, 0},
	{"Lantern_Blue", 705, -1178, 0, 0},
	{"Lantern_Blue", 689, -1162, 0, 0},
	{"Lantern_Blue", 95, -1178, 0, 0},
	{"Lantern_Blue", 111, -1162, 0, 0},
	{"Lantern_Blue", 95, -1756, 0, 0},
	{"Lantern_Blue", 111, -1772, 0, 0},
	{"Lantern_Blue", 705, -1756, 0, 0},
	{"Lantern_Blue", 689, -1772, 0, 0},
	{"Lantern_Blue", 640, -1456, 0, 0},
	{"Lantern_Blue", 640, -1478, 0, 0},
	{"Lantern_Blue", 160, -1456, 0, 0},
	{"Lantern_Blue", 160, -1478, 0, 0},
	{"Lantern_Blue", 411, -1707, 0, 0},
	{"Lantern_Blue", 389, -1707, 0, 0},
	{"Lantern_Blue", 700, -1456, 0, 0},
	{"Lantern_Blue", 700, -1478, 0, 0},
	{"Lantern_Blue", 100, -1456, 0, 0},
	{"Lantern_Blue", 100, -1478, 0, 0},
	{"Lantern_Blue", 411, -1767, 0, 0},
	{"Lantern_Blue", 389, -1767, 0, 0},
	{"Lantern_Blue", 760, -1456, 0, 0},
	{"Lantern_Blue", 760, -1478, 0, 0},
	{"Lantern_Blue", 40, -1456, 0, 0},
	{"Lantern_Blue", 40, -1478, 0, 0},
	{"Lantern_Blue", 411, -1827, 0, 0},
	{"Lantern_Blue", 389, -1827, 0, 0},
	{"Balustrade", 1030.679, -1358.171, -9.79, 0},
	{"Balustrade", 1022.65, -1318.991, -13.371, 0},
	{"Balustrade", 1012.19, -1280.39, -16.952, 0},
	{"Balustrade", 999.339, -1242.517, -20.533, 0},
	{"Balustrade", 984.148, -1205.521, -24.114, 0},
	{"Balustrade", 966.676, -1169.546, -27.695, 0},
	{"Balustrade", 946.99, -1134.733, -31.276, 0},
	{"Balustrade", 925.169, -1101.217, -34.857, 0},
	{"Balustrade", 829.98, -992.956, -47.79, 0},
	{"Balustrade", 799.532, -967.026, -51.371, 0},
	{"Balustrade", 767.524, -943.047, -54.952, 0},
	{"Balustrade", 734.08, -921.115, -58.533, 0},
	{"Balustrade", 699.333, -901.315, -62.114, 0},
	{"Balustrade", 663.416, -883.723, -65.695, 0},
	{"Balustrade", 626.47, -868.409, -69.276, 0},
	{"Balustrade", 588.641, -855.433, -72.857, 0},
	{"Balustrade", 550.074, -844.844, -76.438, 0},
	{"Balustrade", 510.922, -836.686, -80.019, 0},
	{"Balustrade", 291.171, -836.321, -99.79, 0},
	{"Balustrade", 251.991, -844.35, -103.371, 0},
	{"Balustrade", 213.39, -854.81, -106.952, 0},
	{"Balustrade", 175.517, -867.661, -110.533, 0},
	{"Balustrade", 138.521, -882.852, -114.114, 0},
	{"Balustrade", 102.546, -900.324, -117.695, 0},
	{"Balustrade", 67.733, -920.01, -121.276, 0},
	{"Balustrade", 34.217, -941.831, -124.857, 0},
	{"Balustrade", -102.883, -1071.135, -141.79, 0},
	{"Balustrade", -126.626, -1103.318, -145.371, 0},
	{"Balustrade", -148.313, -1136.921, -148.952, 0},
	{"Balustrade", -167.859, -1171.812, -152.533, 0},
	{"Balustrade", -185.188, -1207.857, -156.114, 0},
	{"Balustrade", -200.231, -1244.913, -159.695, 0},
	{"Balustrade", -212.931, -1282.837, -163.276, 0},
	{"Balustrade", -223.237, -1321.48, -166.857, 0},
	{"Balustrade", -230.679, -1575.829, -189.79, 0},
	{"Balustrade", -222.65, -1615.009, -193.371, 0},
	{"Balustrade", -212.19, -1653.61, -196.952, 0},
	{"Balustrade", -199.339, -1691.483, -200.533, 0},
	{"Balustrade", -184.148, -1728.479, -204.114, 0},
	{"Balustrade", -166.676, -1764.454, -207.695, 0},
	{"Balustrade", -146.99, -1799.267, -211.276, 0},
	{"Balustrade", -29.98, -1941.044, -227.79, 0},
	{"Balustrade", 0.468, -1966.974, -231.371, 0},
	{"Balustrade", 32.476, -1990.953, -234.952, 0},
	{"Balustrade", 65.92, -2012.885, -238.533, 0},
	{"Balustrade", 100.667, -2032.685, -242.114, 0},
	{"Balustrade", 136.584, -2050.277, -245.695, 0},
	{"Balustrade", 173.53, -2065.591, -249.276, 0},
	{"Balustrade", 211.359, -2078.567, -252.857, 0},
	{"Balustrade", 249.926, -2089.156, -256.438, 0},
	{"Balustrade", 289.078, -2097.314, -260.019, 0},
	{"Balustrade", 508.829, -2097.679, -279.79, 0},
	{"Balustrade", 548.009, -2089.65, -283.371, 0},
	{"Balustrade", 586.61, -2079.19, -286.952, 0},
	{"Balustrade", 624.483, -2066.339, -290.533, 0},
	{"Balustrade", 661.479, -2051.148, -294.114, 0},
	{"Balustrade", 697.454, -2033.676, -297.695, 0},
	{"Balustrade", 842.895, -1929, -313.79, 0},
	{"Balustrade", 870.886, -1900.435, -317.371, 0},
	{"Balustrade", 897.039, -1870.178, -320.952, 0},
	{"Balustrade", 921.251, -1838.346, -324.533, 0},
	{"Balustrade", 943.427, -1805.064, -328.114, 0},
	{"Balustrade", 963.481, -1770.461, -331.695, 0},
	{"Balustrade", 981.335, -1734.674, -335.276, 0},
	{"Balustrade", 996.919, -1697.842, -338.857, 0},
	{"Balustrade", 1010.172, -1660.108, -342.438, 0},
	{"Balustrade", 1021.042, -1621.62, -346.019, 0},
	{"Balustrade", 1029.486, -1582.528, -349.6, 0},
}
D.LINTELS = {
	{566.633, -1428.967, -102.857},
	{553.993, -1392.842, -115.714},
	{474.16, -1313.009, -154.285},
	{438.035, -1300.367, -167.142},
	{400.003, -1296.081, -179.999},
	{361.97, -1300.366, -192.856},
	{325.844, -1313.006, -205.713},
	{293.437, -1333.368, -218.57},
	{266.373, -1360.431, -231.427},
	{229.081, -1466.994, -269.998},
	{293.428, -1600.625, -321.426},
	{474.15, -1620.996, -385.711},
	{570.919, -1467.012, -449.996},
}
D.WAYS = {
	{"북 큰길", 90, 191, 660, 24},
	{"동 길", 0, 191, 436, 16},
	{"서 길", 180, 191, 436, 16},
	{"남 길", 270, 191, 402, 16},
}
D.POOLS = {
	{-44, 230, 600, 22},
	{44, 230, 600, 22},
}
return D
end)()
local STEPS = (function()
-- build_kit_sanctuary.py 가 적은 탑 계단 윗면 점. 탑 발치 원점, 로블록스 축. 손으로 고치지 말 것
return {
	{ 0, 1.192, 2.000, 24.638, 22.579 },
	{ 1, 3.559, 4.000, 24.374, 22.558 },
	{ 2, 5.887, 6.000, 23.884, 22.537 },
	{ 3, 8.153, 8.000, 23.173, 22.515 },
	{ 4, 10.338, 10.000, 22.247, 22.494 },
	{ 5, 12.420, 12.000, 21.117, 22.473 },
	{ 6, 14.380, 14.000, 19.792, 22.452 },
	{ 7, 16.201, 16.000, 18.287, 22.431 },
	{ 8, 17.865, 18.000, 16.615, 22.410 },
	{ 9, 19.359, 20.000, 14.793, 22.388 },
	{ 10, 20.667, 22.000, 12.837, 22.367 },
	{ 11, 21.780, 24.000, 10.768, 22.346 },
	{ 12, 22.686, 26.000, 8.604, 22.325 },
	{ 13, 23.378, 28.000, 6.365, 22.304 },
	{ 14, 23.850, 30.000, 4.073, 22.283 },
	{ 15, 24.098, 32.000, 1.750, 22.262 },
	{ 16, 24.121, 34.000, -0.583, 22.240 },
	{ 17, 23.919, 36.000, -2.904, 22.219 },
	{ 18, 23.494, 38.000, -5.192, 22.198 },
	{ 19, 22.851, 40.000, -7.425, 22.177 },
	{ 20, 21.997, 42.000, -9.582, 22.156 },
	{ 21, 20.940, 44.000, -11.644, 22.135 },
	{ 22, 19.691, 46.000, -13.591, 22.113 },
	{ 23, 18.261, 48.000, -15.407, 22.092 },
	{ 24, 16.666, 50.000, -17.073, 22.071 },
	{ 25, 14.919, 52.000, -18.576, 22.050 },
	{ 26, 13.038, 54.000, -19.901, 22.029 },
	{ 27, 11.041, 56.000, -21.036, 22.008 },
	{ 28, 8.946, 58.000, -21.973, 21.987 },
	{ 29, 6.774, 60.000, -22.701, 21.965 },
	{ 30, 4.545, 62.000, -23.216, 21.944 },
	{ 31, 2.280, 64.000, -23.513, 21.923 },
	{ 32, 0.000, 66.000, -23.589, 21.902 },
	{ 33, -2.273, 68.000, -23.446, 21.881 },
	{ 34, -4.519, 70.000, -23.084, 21.860 },
	{ 35, -6.716, 72.000, -22.508, 21.838 },
	{ 36, -8.845, 74.000, -21.723, 21.817 },
	{ 37, -10.884, 76.000, -20.738, 21.796 },
	{ 38, -12.817, 78.000, -19.563, 21.775 },
	{ 39, -14.624, 80.000, -18.208, 21.754 },
	{ 40, -16.289, 82.000, -16.688, 21.733 },
	{ 41, -17.798, 84.000, -15.016, 21.712 },
	{ 42, -19.137, 86.000, -13.209, 21.690 },
	{ 43, -20.293, 88.000, -11.284, 21.669 },
	{ 44, -21.256, 90.000, -9.259, 21.648 },
	{ 45, -22.019, 92.000, -7.154, 21.627 },
	{ 46, -22.574, 94.000, -4.989, 21.606 },
	{ 47, -22.916, 96.000, -2.783, 21.585 },
	{ 48, -23.044, 98.000, -0.557, 21.563 },
	{ 49, -22.957, 100.000, 1.667, 21.542 },
	{ 50, -22.656, 102.000, 3.869, 21.521 },
	{ 51, -22.144, 104.000, 6.029, 21.500 },
	{ 52, -21.427, 106.000, 8.126, 21.479 },
	{ 53, -20.513, 108.000, 10.141, 21.458 },
	{ 54, -19.410, 110.000, 12.056, 21.437 },
	{ 55, -18.129, 112.000, 13.853, 21.415 },
	{ 56, -16.682, 114.000, 15.515, 21.394 },
	{ 57, -15.085, 116.000, 17.027, 21.373 },
	{ 58, -13.351, 118.000, 18.376, 21.352 },
	{ 59, -11.498, 120.000, 19.550, 21.331 },
	{ 60, -9.544, 122.000, 20.538, 21.310 },
	{ 61, -7.506, 124.000, 21.332, 21.288 },
	{ 62, -5.404, 126.000, 21.924, 21.267 },
	{ 63, -3.258, 128.000, 22.310, 21.246 },
	{ 64, -1.088, 130.000, 22.486, 21.225 },
	{ 65, 1.086, 132.000, 22.453, 21.204 },
	{ 66, 3.243, 134.000, 22.210, 21.183 },
	{ 67, 5.363, 136.000, 21.760, 21.162 },
	{ 68, 7.427, 138.000, 21.109, 21.140 },
	{ 69, 9.416, 140.000, 20.263, 21.119 },
	{ 70, 11.311, 142.000, 19.231, 21.098 },
	{ 71, 13.094, 144.000, 18.022, 21.077 },
	{ 72, 14.750, 146.000, 16.649, 21.056 },
	{ 73, 16.263, 148.000, 15.125, 21.035 },
	{ 74, 17.621, 150.000, 13.464, 21.013 },
	{ 75, 18.809, 152.000, 11.683, 20.992 },
	{ 76, 19.819, 154.000, 9.798, 20.971 },
	{ 77, 20.640, 156.000, 7.828, 20.950 },
	{ 78, 21.267, 158.000, 5.790, 20.929 },
	{ 79, 21.694, 160.000, 3.705, 20.908 },
	{ 80, 21.916, 162.000, 1.592, 20.887 },
	{ 81, 21.934, 164.000, -0.530, 20.865 },
	{ 82, 21.747, 166.000, -2.641, 20.844 },
	{ 83, 21.358, 168.000, -4.720, 20.823 },
	{ 84, 20.771, 170.000, -6.749, 20.802 },
	{ 85, 19.991, 172.000, -8.708, 20.781 },
	{ 86, 19.028, 174.000, -10.581, 20.760 },
	{ 87, 17.890, 176.000, -12.349, 20.738 },
	{ 88, 16.589, 178.000, -13.996, 20.717 },
	{ 89, 15.138, 180.000, -15.508, 20.696 },
	{ 90, 13.549, 182.000, -16.870, 20.675 },
	{ 91, 11.839, 184.000, -18.071, 20.654 },
	{ 92, 10.024, 186.000, -19.099, 20.633 },
	{ 93, 8.121, 188.000, -19.947, 20.612 },
	{ 94, 6.149, 190.000, -20.605, 20.590 },
	{ 95, 4.125, 192.000, -21.069, 20.569 },
	{ 96, 2.069, 194.000, -21.336, 20.548 },
	{ 97, 0.000, 196.000, -21.402, 20.527 },
	{ 98, -2.062, 198.000, -21.269, 20.506 },
	{ 99, -4.099, 200.000, -20.937, 20.485 },
	{ 100, -6.091, 202.000, -20.412, 20.463 },
	{ 101, -8.020, 204.000, -19.697, 20.442 },
	{ 102, -9.868, 206.000, -18.801, 20.421 },
	{ 103, -11.618, 208.000, -17.733, 20.400 },
	{ 104, -13.254, 210.000, -16.503, 20.379 },
	{ 105, -14.761, 212.000, -15.123, 20.358 },
	{ 106, -16.126, 214.000, -13.606, 20.337 },
	{ 107, -17.336, 216.000, -11.967, 20.315 },
	{ 108, -18.381, 218.000, -10.221, 20.294 },
	{ 109, -19.251, 219.463, -8.386, 20.273 },
	{ 110, -19.938, 221.565, -6.478, 20.252 },
	{ 112, -20.745, 225.584, -2.519, 20.210 },
	{ 114, -20.775, 229.856, 1.509, 20.167 },
	{ 115, -20.499, 231.852, 3.501, 20.146 },
	{ 117, -19.382, 235.350, 7.351, 20.104 },
	{ 119, -17.551, 239.659, 10.902, 20.062 },
	{ 120, -16.390, 241.997, 12.524, 20.040 },
	{ 122, -13.634, 245.576, 15.390, 19.998 },
	{ 124, -10.389, 249.863, 17.665, 19.956 },
	{ 125, -8.622, 251.856, 18.554, 19.935 },
	{ 127, -4.880, 255.520, 19.800, 19.892 },
	{ 129, -0.982, 259.556, 20.301, 19.850 },
	{ 130, 0.980, 261.562, 20.268, 19.829 },
	{ 132, 4.840, 265.376, 19.636, 19.787 },
	{ 134, 8.494, 269.232, 18.280, 19.744 },
	{ 135, 10.202, 271.344, 17.345, 19.723 },
	{ 137, 13.299, 275.238, 15.012, 19.681 },
	{ 139, 15.882, 279.809, 12.136, 19.638 },
	{ 140, 16.951, 281.321, 10.529, 19.617 },
	{ 142, 18.595, 285.280, 7.052, 19.575 },
	{ 144, 19.537, 289.463, 3.337, 19.533 },
	{ 145, 19.735, 291.469, 1.433, 19.512 },
	{ 149, 18.690, 299.421, -6.073, 19.427 },
	{ 152, 16.090, 305.703, -11.106, 19.363 },
	{ 154, 13.610, 309.965, -13.942, 19.321 },
	{ 155, 12.179, 311.875, -15.165, 19.300 },
	{ 157, 9.008, 315.512, -17.163, 19.258 },
	{ 160, 3.705, 321.463, -18.923, 19.194 },
	{ 164, -3.679, 329.633, -18.790, 19.110 },
	{ 167, -8.851, 335.562, -16.865, 19.046 },
	{ 169, -11.884, 339.877, -14.797, 19.004 },
	{ 170, -13.233, 341.205, -13.557, 18.983 },
}
end)()

local RGB = Color3.fromRGB
local M = Enum.Material
local SS = game:GetService("ServerStorage")
local S = workspace.Surface
local kit = assert(SS:FindFirstChild("SanctuaryKit"), "ServerStorage.SanctuaryKit 이 없다. Sanctuary_Kit.luau 를 먼저")
local report = {}
local function say(f, ...)
	report[#report + 1] = string.format(f, ...)
end

local CX, CZ, TT = D.CX, D.CZ, D.TT
local TR = D.TERRACE_R
local CENTER = Vector3.new(CX, 0, CZ)
local MARBLE = { RGB(233, 230, 220), M.Marble }
local MARBLE2 = { RGB(224, 221, 210), M.Marble }
local COBALT = { RGB(36, 71, 143), M.SmoothPlastic }
local GOLD = { RGB(201, 162, 74), M.Metal }
local BLUE = RGB(122, 202, 255)

-- 1. 옛것
local bak = SS:FindFirstChild("탑의성역_옛것")
if not bak then
	bak = Instance.new("Folder")
	bak.Name = "탑의성역_옛것"
	bak.Parent = SS
end
for _, n in ipairs({ "Ruins_탑의성역", "Fill_탑의성역", "Struct_탑의성역" }) do
	local f = S:FindFirstChild(n)
	if f then
		f.Parent = bak
		say("옛것 옮김 %s", n)
	end
end

-- 3. 새 폴더
local root = S:FindFirstChild("Sanctuary_탑의성역")
if root then
	root:Destroy()
end
root = Instance.new("Folder")
root.Name = "Sanctuary_탑의성역"
root.Parent = S
local function sub(name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = root
	return f
end
local fFloor, fTower, fCol, fItems = sub("Floor"), sub("Tower"), sub("Colonnade"), sub("Items")

local function part(parent, name, cf, size, skin, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color, p.Material = skin[1], skin[2]
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local CYL = Enum.PartType.Cylinder
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- 원통 축(X)을 세운다

-- 2. 땅 빛
local G = assert(S.World:FindFirstChild("G_탑의성역"), "World.G_탑의성역 이 없다")
local nGrass = 0
for i, p in ipairs(G:GetChildren()) do
	if p:IsA("BasePart") and p.Name:match("^Gs_") then
		if p:GetAttribute("OrigMat") == nil then
			p:SetAttribute("OrigColor", p.Color)
			p:SetAttribute("OrigMat", p.Material.Name)
		end
		if p:GetAttribute("OrigMat") ~= "Sand" then
			local k = (i * 37) % 11 - 5
			p.Color = RGB(88 + k, 128 + k, 68 + math.floor(k / 2))
			p.Material = M.Grass
			nGrass += 1
		end
	end
end
say("잔디로 칠한 땅 조각 %d", nGrass)

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { G, fFloor }
local function groundY(x, z)
	local h = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -400, 0), rp)
	return h and h.Position.Y
end
local function flat(x, y, z, dir)
	-- dir 쪽을 보는(로컬 Z 가 dir) 수평 CFrame
	return CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(x + dir.X, y, z + dir.Z))
end

-- 4. 안뜰 단
local BOT = 2
part(fFloor, "Terrace", CFrame.new(CX, (TT + BOT) / 2, CZ) * UPRIGHT, Vector3.new(TT - BOT, TR * 2, TR * 2), MARBLE, CYL)
part(fFloor, "TerraceBand", CFrame.new(CX, TT - 2.6, CZ) * UPRIGHT, Vector3.new(1.6, TR * 2 + 0.8, TR * 2 + 0.8), COBALT, CYL)
part(fFloor, "TerraceGold", CFrame.new(CX, TT - 1.4, CZ) * UPRIGHT, Vector3.new(0.3, TR * 2 + 0.9, TR * 2 + 0.9), GOLD, CYL)
part(fFloor, "TerraceFoot", CFrame.new(CX, BOT + 1.0, CZ) * UPRIGHT, Vector3.new(2.0, TR * 2 + 2.4, TR * 2 + 2.4), MARBLE2, CYL)
-- 나침 무늬: 네 길 쪽 청화 띠와 r 140 고리(짧은 띠 48 개)
for q = 0, 3 do
	local a = math.rad(q * 90)
	local dir = Vector3.new(math.cos(a), 0, math.sin(a))
	local c = CENTER + dir * 138
	part(fFloor, "Compass", flat(c.X, TT, c.Z, dir), Vector3.new(3, 0.2, 76), COBALT)
end
for k = 0, 47 do
	local a = math.rad(k * 7.5 + 3.75)
	local dir = Vector3.new(-math.sin(a), 0, math.cos(a))
	local c = CENTER + Vector3.new(math.cos(a), 0, math.sin(a)) * 140
	part(fFloor, "CompassRing", flat(c.X, TT, c.Z, dir), Vector3.new(1.6, 0.2, 2 * math.pi * 140 / 48 - 1.2), COBALT)
end

-- 5. 네 계단 (안뜰 가장자리에서 땅까지)
for _, w in ipairs(D.WAYS) do
	local a = math.rad(w[2])
	local width = w[5]
	local dir = Vector3.new(math.cos(a), 0, math.sin(a))
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local foot = CENTER + dir * (TR + 16)
	local g0 = assert(groundY(foot.X, foot.Z), "계단 발치에 땅이 없다 " .. w[1])
	local rise = TT - g0
	local n = math.ceil(rise / 0.72)
	local tread = 1.5
	for k = 1, n do
		local top = g0 + rise * k / n
		local rIn = TR + (n - k) * tread
		local c = CENTER + dir * (rIn + tread / 2)
		part(fFloor, "Step", flat(c.X, (top + g0 - 1) / 2, c.Z, dir), Vector3.new(width, top - g0 + 1, tread), MARBLE)
		local e = CENTER + dir * (rIn + tread - 0.15)
		part(fFloor, "Nose", flat(e.X, top + 0.05, e.Z, dir), Vector3.new(width, 0.14, 0.3), COBALT)
	end
	for _, s in ipairs({ -1, 1 }) do
		local len = n * tread
		local c = CENTER + dir * (TR + len / 2) + side * s * (width / 2 + 1)
		local h = TT + 0.8 - (g0 - 1)
		part(fFloor, "Cheek", flat(c.X, g0 - 1 + h / 2, c.Z, dir), Vector3.new(2, h, len), MARBLE)
		part(fFloor, "CheekCap", flat(c.X, TT + 0.9, c.Z, dir), Vector3.new(2.2, 0.2, len + 0.2), COBALT)
	end
	say("%s 계단 %d 단, 오름 %.1f", w[1], n, rise)
end

-- 6. 길 포석과 청화 연석
local nPave = 0
for _, w in ipairs(D.WAYS) do
	local a = math.rad(w[2])
	local r0, r1, width = w[3], w[4], w[5]
	local dir = Vector3.new(math.cos(a), 0, math.sin(a))
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local nseg = math.ceil((r1 - r0) / 30)
	local seg = (r1 - r0) / nseg
	for j = 0, nseg - 1 do
		local c = CENTER + dir * (r0 + seg * (j + 0.5))
		local gy = groundY(c.X, c.Z) or 8
		local top = gy + 0.35
		part(fFloor, "Pave", flat(c.X, top - 0.6, c.Z, dir), Vector3.new(width, 1.2, seg), j % 2 == 0 and MARBLE or MARBLE2)
		for _, s in ipairs({ -1, 1 }) do
			local e = c + side * s * (width / 2 + 0.5)
			part(fFloor, "Curb", flat(e.X, top - 0.55, e.Z, dir), Vector3.new(1.0, 1.3, seg), COBALT)
		end
		nPave += 1
	end
end
-- 큰 문 밖 앞마당
do
	local c = CENTER + Vector3.new(0, 0, 700)
	local gy = groundY(c.X, c.Z) or 8
	part(fFloor, "GateCourt", CFrame.new(c.X, gy + 0.35 - 0.6, c.Z), Vector3.new(44, 1.2, 44), MARBLE)
	for _, s in ipairs({ -1, 1 }) do
		part(fFloor, "GateCourtCurb", CFrame.new(c.X + s * 22.5, gy + 0.35 - 0.55, c.Z), Vector3.new(1.0, 1.3, 44), COBALT)
	end
end
say("포석 %d 토막", nPave)

-- 7. 반사지
for _, pl in ipairs(D.POOLS) do
	local u, v0, v1, w = pl[1], pl[2], pl[3], pl[4]
	local cx, cz, L = CX + u, CZ + (v0 + v1) / 2, v1 - v0
	local gy = groundY(cx, cz) or 8
	part(fFloor, "PoolBed", CFrame.new(cx, gy - 0.2, cz), Vector3.new(w, 0.5, L), { RGB(24, 44, 60), M.Slate })
	local wtr = part(fFloor, "PoolWater", CFrame.new(cx, gy + 0.2, cz), Vector3.new(w, 0.3, L), { RGB(70, 118, 150), M.Glass })
	wtr.Transparency = 0.3
	wtr.Reflectance = 0.3
	wtr.CanCollide = false
	for _, s in ipairs({ -1, 1 }) do
		part(fFloor, "PoolRim", CFrame.new(cx + s * (w / 2 + 0.8), gy + 0.45, cz), Vector3.new(1.6, 1.3, L + 3.2), MARBLE)
		part(fFloor, "PoolRimLine", CFrame.new(cx + s * (w / 2 + 0.8), gy + 1.15, cz), Vector3.new(0.5, 0.12, L + 3.2), COBALT)
		part(fFloor, "PoolRim", CFrame.new(cx, gy + 0.45, cz + s * (L / 2 + 0.8)), Vector3.new(w, 1.3, 1.6), MARBLE)
	end
end

-- 8. 탑
local foot = CFrame.new(CX, TT, CZ)
local function put(name, cf, parent)
	local c = assert(kit:FindFirstChild(name), "틀이 없다 " .. name):Clone()
	c:PivotTo(cf)
	c.Parent = parent
	return c
end
put("Tower_Plinth", foot, fTower)
for k = 1, 6 do
	put("Tower_S" .. k, foot * CFrame.new(0, 12, 0), fTower)
end
local fHit = Instance.new("Folder")
fHit.Name = "Collision"
fHit.Parent = fTower
local function hitPart(name, cf, size, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Transparency = 1
	p.CastShadow = false
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Parent = fHit
	return p
end
for z = 0, 390, 26 do
	local r = 14 - 6 * (z + 13) / 520
	hitPart("ColumnHit", foot * CFrame.new(0, 12 + z + 13, 0) * UPRIGHT, Vector3.new(26, r * 2, r * 2), CYL)
end
local nRamp = 0
local base = foot.Position + Vector3.new(0, 12, 0)
-- 기단 윗면에서 첫 계단으로: 첫 두 계단이 오르는 쪽 반대로 한 칸 물린 자리
local p0 = base + Vector3.new(STEPS[1][2], STEPS[1][3], STEPS[1][4])
local p1 = base + Vector3.new(STEPS[2][2], STEPS[2][3], STEPS[2][4])
local q = p0 + (p0 - p1)
local prev = { Vector3.new(q.X, base.Y, q.Z), STEPS[1][1] - 1, STEPS[1][5] }
for _, st in ipairs(STEPS) do
	local p = base + Vector3.new(st[2], st[3], st[4])
	if st[1] - prev[2] == 1 then
		local a, b = prev[1], p
		local len = (b - a).Magnitude
		hitPart("StairRamp", CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, -0.3, 0), Vector3.new(st[5], 0.6, len + 0.4))
		nRamp += 1
	end
	prev = { p, st[1], st[5] }
end
say("계단 비탈 %d", nRamp)

-- 코어, 껍질, 도는 것
local topY = TT + 12 + 560
local at = Vector3.new(CX, topY, CZ)
local core = part(fTower, "Core", CFrame.new(at) * CFrame.Angles(0.5, 0.4, 0.2), Vector3.new(21, 21, 21), { BLUE, M.Neon })
core.CanCollide = false
local cl = Instance.new("PointLight")
cl.Color, cl.Range, cl.Brightness, cl.Shadows = BLUE, 60, 4, false
cl.Parent = core
local shell = part(fTower, "CoreShell", CFrame.new(at) * CFrame.Angles(0.2, 0.9, 0.6), Vector3.new(37, 37, 37), { BLUE, M.Neon })
shell.CanCollide = false
shell.Transparency = 0.78
local orb = Instance.new("Folder")
orb.Name = "Orbit"
orb.Parent = fTower
local function orbitAt(r, ph, tl)
	return CFrame.Angles(tl, 0, 0) * Vector3.new(math.cos(ph) * r, 0, math.sin(ph) * r)
end
local SUB = { { 32, 0.22, 12, 4.3 }, { 43, -0.15, -34, 3.3 }, { 25, 0.31, 58, 3.0 }, { 53, 0.11, 24, 3.7 }, { 37, -0.26, -70, 2.7 } }
for i, sc in ipairs(SUB) do
	local ph, tl = i * 1.3, math.rad(sc[3])
	local p = part(orb, "SubCore" .. i, CFrame.new(at + orbitAt(sc[1], ph, tl)), Vector3.new(sc[4] * 2, sc[4] * 2, sc[4] * 2), { BLUE, M.Neon })
	p.CanCollide = false
	p:SetAttribute("R", sc[1])
	p:SetAttribute("S", sc[2])
	p:SetAttribute("P", ph)
	p:SetAttribute("T", tl)
	p:SetAttribute("SP", 0.25)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows = BLUE, 24, 2, false
	l.Parent = p
end
local rng = Random.new(51774)
local KINDS = { "Debris_Rib", "Debris_Step", "Debris_Drum" }
for i = 1, 36 do
	local c = kit[KINDS[i % 3 + 1]]:Clone()
	c:ScaleTo(rng:NextNumber(0.35, 0.8))
	local r = rng:NextNumber(55, 165)
	local ph, tl = rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.75, 0.75)
	c:SetAttribute("R", r)
	c:SetAttribute("S", (rng:NextNumber() < 0.5 and -1 or 1) * (20 / r))
	c:SetAttribute("P", ph)
	c:SetAttribute("T", tl)
	c:SetAttribute("SP", rng:NextNumber(0.15, 0.6))
	c:PivotTo(CFrame.new(at + orbitAt(r, ph, tl)) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), rng:NextNumber(0, 3)))
	c.Name = "Debris" .. i
	c.Parent = orb
end
local spin = Instance.new("Script")
spin.Name = "Spin"
spin.Source = [==[
-- 탑 꼭대기 코어와 도는 파편. 플레이 때만 돈다 (Sanctuary_Build.luau 가 넣었다)
local RS = game:GetService("RunService")
local root = script.Parent
local core = root:WaitForChild("Core")
local shell = root:WaitForChild("CoreShell")
local orbit = root:WaitForChild("Orbit")
local origin = core.Position
local list = {}
for _, p in ipairs(orbit:GetChildren()) do
	if p:GetAttribute("R") then
		list[#list + 1] = {
			p = p, model = p:IsA("Model"), r = p:GetAttribute("R"), s = p:GetAttribute("S"),
			ph = p:GetAttribute("P"), tl = p:GetAttribute("T"), sp = p:GetAttribute("SP"),
		}
	end
end
RS.Heartbeat:Connect(function()
	local t = time()
	core.CFrame = CFrame.new(origin) * CFrame.Angles(t * 0.12, t * 0.18, t * 0.09)
	shell.CFrame = CFrame.new(origin) * CFrame.Angles(-t * 0.07, -t * 0.11, t * 0.05)
	for _, e in ipairs(list) do
		local a = e.ph + t * e.s
		local v = CFrame.Angles(e.tl, 0, 0) * Vector3.new(math.cos(a) * e.r, 0, math.sin(a) * e.r)
		local cf = CFrame.new(origin + v) * CFrame.Angles(t * e.sp * 0.7, t * e.sp, t * e.sp * 0.4)
		if e.model then
			e.p:PivotTo(cf)
		else
			e.p.CFrame = cf
		end
	end
end)
]==]
spin.Parent = fTower

-- 9. 열주 인방, 10. 놓을 것
for _, l in ipairs(D.LINTELS) do
	put("Lintel", CFrame.new(l[1], TT + 35.2, l[2]) * CFrame.Angles(0, math.rad(l[3]), 0), fCol)
end
local counts = {}
local miss = 0
for _, it in ipairs(D.ITEMS) do
	local m, x, z, yaw, sink = it[1], it[2], it[3], it[4], it[5]
	local y = groundY(x, z)
	if not y then
		miss += 1
		y = 8
	end
	put(m, CFrame.new(x, y - sink, z) * CFrame.Angles(0, math.rad(yaw), 0), m:match("^Col_") and fCol or fItems)
	counts[m] = (counts[m] or 0) + 1
end
local t = {}
for k, v in pairs(counts) do
	t[#t + 1] = k .. " " .. v
end
table.sort(t)
say("놓은 것 %d (땅 못 찾음 %d): %s", #D.ITEMS, miss, table.concat(t, ", "))
say("인방 %d, 안뜰 윗면 %.2f, 코어 높이 %.1f", #D.LINTELS, TT, topY)

local HS = game:GetService("HttpService")
pcall(function()
	HS:PostAsync("http://127.0.0.1:34999/sancbuild", table.concat(report, "\n"))
end)
print("sancbuild", #report)
