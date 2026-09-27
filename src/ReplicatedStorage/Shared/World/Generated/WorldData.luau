--!strict
-- 자동 생성 파일 (blender/level/layout.py). 직접 수정하지 마세요.
return {
	TerrainModules = { "Mistmire", "Harbor", "LighthouseRock" },
	MaterialNames = { "Sand", "Mud", "Ground", "LeafyGrass", "Grass", "Rock", "Slate", "Pebble", "Limestone" },
	SeaFloor = -36,
	SeaBounds = { MinX = -1700, MaxX = 1700, MinZ = -1000, MaxZ = 1000 },
	SpawnPoints = {
		{ Name = "Harbor", P = { -705, 3.2, 14 } },
		{ Name = "Mistmire", P = { 460, 7.2, 12 } },
	},
	EnemySpawns = {
		{ Type = "BogCrawler", P = { 700, 0.24, 160 }, Radius = 40, Count = 4 },
		{ Type = "BogCrawler", P = { 790, 0.99, 60 }, Radius = 36, Count = 3 },
		{ Type = "BogCrawler", P = { 640, 0.29, 230 }, Radius = 40, Count = 4 },
		{ Type = "BogCrawler", P = { 830, -1.06, -40 }, Radius = 30, Count = 3 },
		{ Type = "MudBrute", P = { 815, -0.46, 250 }, Radius = 22, Count = 1 },
		{ Type = "MudBrute", P = { 960, 2.56, 110 }, Radius = 22, Count = 1 },
		{ Type = "MudBrute", P = { 720, 0.27, 300 }, Radius = 22, Count = 1 },
		{ Type = "BogWitch", P = { 855, 11.67, -190 }, Radius = 26, Count = 2 },
		{ Type = "BogWitch", P = { 945, 2.49, -120 }, Radius = 22, Count = 1 },
		{ Type = "MireLord", P = { 900, 3.2, 188 }, Radius = 30, Count = 1, Boss = true, ArenaRadius = 34 },
	},
	Zones = {
		{ Name = "Shrine", Kind = "Sphere", P = { 900, 0, 200 }, Radius = 75, Priority = 3 },
		{ Name = "Village", Kind = "Box", P = { 445, 10, 0 }, Size = { 300, 80, 220 }, Priority = 2 },
		{ Name = "Swamp", Kind = "Ellipse", P = { 700, 0, 0 }, Size = { 1000, 200, 840 }, Priority = 1 },
		{ Name = "Harbor", Kind = "Ellipse", P = { -900, 0, 0 }, Size = { 650, 200, 560 }, Priority = 1 },
		{ Name = "Lighthouse", Kind = "Sphere", P = { -80, 0, -330 }, Radius = 120, Priority = 1 },
	},
	Buoys = {
		{ P = { 179.4, 0, -130.75 } },
		{ P = { -322.46, 0, -260.81 } },
		{ P = { -567, 0, -110.01 } },
		{ P = { -531.06, 0, 177.07 } },
		{ P = { -278.26, 0, 303.07 } },
		{ P = { -5.28, 0, 304.35 } },
		{ P = { 184.29, 0, 88.12 } },
	},
}
