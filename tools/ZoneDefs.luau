--!nocheck
--[[
	ZoneDefs.luau — 존 9개의 지형 파라미터. 지도 생성기의 유일한 정본.

	출처: 2026-09-10 Studio 세션의 `_G.BlockWorld`(버전 LayeredWorld_20260910).
	그 빌더는 커맨드 바에 한 줄로 붙여넣어져 메모리에만 존재했고 place 에 저장되지 않았다.
	Studio 로그의 에코에서 이 표를 복구했으며, 라이브 `bw.zones` 값과 대조해 일치를 확인했다.
	(빌더의 나머지 로직은 로그가 1,023자에서 잘라 복구하지 못했다.)

	lo/hi 는 「신맵 구조도.md」 §4·§5 의 높이 범위와 아홉 개 모두 일치한다.

	i, j 는 셀 좌표 — 월드 중심은 (i * 1600, j * 1600).
]]

local M = Enum.Material
local RGB = Color3.fromRGB

export type ZoneDef = {
	name: string,
	prefix: string,
	i: number,
	j: number,
	lo: number,
	hi: number,
	base: number,
	mat: Enum.Material,
	roof: Color3,
	wall: Color3,
	-- 문화 양식이 정해진 존만 갖는다. 평원 = 조선.
	trim: Color3?,
	plinth: Color3?,
}

-- 생성 순서. 빌더가 이 순서로 존을 찍었다.
local ORDER = { "평원", "늪지대", "사막", "광산", "화산", "설원", "숲", "오염지대", "탑의성역" }

local DEFS: { ZoneDef } = {
	-- 평원은 조선 양식으로 간다 (「신맵 구조도.md」 §6).
	-- 복구 당시 원래 색은 roof RGB(108,65,42) 갈색 / wall RGB(219,204,165) 크림 — 유럽 팔레트였다.
	{
		name = "평원",
		prefix = "Pln",
		i = 0,
		j = 1,
		lo = 0,
		hi = 60,
		base = 28,
		mat = M.Grass,
		roof = RGB(72, 80, 92), -- 청회색 기와
		wall = RGB(232, 226, 212), -- 회백색 회벽
		trim = RGB(150, 64, 50), -- 주칠 기둥·단청 띠
		plinth = RGB(178, 176, 168), -- 화강 기단
	},
	{
		name = "늪지대",
		prefix = "Swp",
		i = 1,
		j = 1,
		lo = -20,
		hi = 40,
		base = 12,
		mat = M.Mud,
		roof = RGB(63, 83, 72),
		wall = RGB(95, 78, 59),
	},
	{
		name = "사막",
		prefix = "Des",
		i = 1,
		j = 0,
		lo = 20,
		hi = 120,
		base = 56,
		mat = M.Sand,
		roof = RGB(155, 93, 57),
		wall = RGB(218, 180, 117),
	},
	{
		name = "광산",
		prefix = "Min",
		i = 1,
		j = -1,
		lo = 120,
		hi = 300,
		base = 176,
		mat = M.Rock,
		roof = RGB(52, 59, 64),
		wall = RGB(114, 111, 99),
	},
	{
		name = "화산",
		prefix = "Vol",
		i = 0,
		j = -1,
		lo = 240,
		hi = 520,
		base = 292,
		mat = M.Basalt,
		roof = RGB(60, 46, 42),
		wall = RGB(104, 91, 80),
	},
	{
		name = "설원",
		prefix = "Snw",
		i = -1,
		j = -1,
		lo = 200,
		hi = 480,
		base = 280,
		mat = M.Snow,
		roof = RGB(217, 228, 232),
		wall = RGB(69, 48, 37),
	},
	{
		name = "숲",
		prefix = "For",
		i = -1,
		j = 0,
		lo = 40,
		hi = 180,
		base = 76,
		mat = M.Grass,
		roof = RGB(49, 83, 53),
		wall = RGB(130, 109, 72),
	},
	{
		name = "오염지대",
		prefix = "Cor",
		i = -1,
		j = 1,
		lo = 0,
		hi = 80,
		base = 24,
		mat = M.CrackedLava,
		roof = RGB(74, 53, 79),
		wall = RGB(83, 74, 87),
	},
	{
		name = "탑의성역",
		prefix = "Tow",
		i = 0,
		j = 0,
		lo = 60,
		hi = 120,
		base = 88,
		mat = M.Slate,
		roof = RGB(67, 77, 95),
		wall = RGB(189, 183, 170),
	},
}

-- 2026-09-10 기준 실제로 지어진 블록 수. 0 은 미착공.
local BUILT = {
	["평원"] = 786,
	["늪지대"] = 2074,
	["사막"] = 1071,
	["광산"] = 3692,
	["화산"] = 1294,
	["설원"] = 0,
	["숲"] = 0,
	["오염지대"] = 0,
	["탑의성역"] = 0,
}

local byName = {}
for _, d in ipairs(DEFS) do
	byName[d.name] = d
end

return {
	CELL = 1600,
	ORDER = ORDER,
	DEFS = DEFS,
	BUILT = BUILT,
	byName = byName,
}
