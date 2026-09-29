--!strict
--[[
	CardArtworks — 손으로 그린 **카드 그림** 보관소.

	`CardArt`는 태그를 보고 문양을 **절차적으로** 만든다. 32개 태그에 32개 그림이라
	카드가 늘어도 그림이 저절로 생기지만, "이 카드만 이렇게 그리고 싶다"는 안 된다.

	이 모듈은 그 구멍을 메운다. 편집기(`config_editor.html`)의 그림 탭에서 도형을
	끌어다 놓아 만든 것을 이름 붙여 여기 담고, 카드가 `Art = "이름"`으로 가리킨다.
	가리키지 않은 카드는 예전처럼 태그 문양으로 그려진다.

	--------------------------------------------------------------------------
	좌표

	`CardArt.Shape`와 같다 — 한 변 1인 정사각형, 중심 기준. 메달리온 액자는
	`CardArt`가 등급을 보고 따로 깔아 주므로 여기엔 **문양만** 담는다.
]]

export type Shape = {
	X: number,
	Y: number,
	W: number,
	H: number,
	Rotation: number,
	-- "#rrggbb". 등급색과 무관하게 그대로 칠한다.
	Color: string,
	Corner: number,
	Stroke: number,
	ZIndex: number,
	Transparency: number,
}

export type Artwork = {
	Id: string,
	Name: string,
	Shapes: { Shape },
}

local CardArtworks = {}

--[[
	기본 템플릿.

	새 그림을 시작할 때 빈 화면부터 두면 무엇을 할 수 있는지 알기 어렵다.
	등급마다 어울리는 출발점을 하나씩 둔다 (요청: "희귀 카드의 경우 파란 배경에 원").

	여기 담긴 것은 **문양뿐**이다. 바탕과 액자는 `CardArt`가 등급을 보고 깐다.
]]
local TEMPLATES: { [string]: { Shape } } = {
	Common = {
		{
			X = 0.5,
			Y = 0.5,
			W = 0.42,
			H = 0.42,
			Rotation = 0,
			Color = "#ffffff",
			Corner = 0.5,
			Stroke = 0,
			ZIndex = 6,
			Transparency = 0,
		},
	},
	--[[
		희귀: **기본 원 안에 또 다른 불투명한 원**(요청). 바깥 원은 채운 반투명이
		아니라 **선으로 그은 원**(요청: "꽉 찬 원이 아니라 선으로 그은 원"),
		안쪽 원은 완전히 불투명해 "원 안의 원"이 뚜렷이 갈린다.
	]]
	Rare = {
		{
			X = 0.5,
			Y = 0.5,
			W = 0.64,
			H = 0.64,
			Rotation = 0,
			Color = "#ffffff",
			Corner = 0.5,
			Stroke = 0.03,
			ZIndex = 6,
			Transparency = 0,
		},
		{
			X = 0.5,
			Y = 0.5,
			W = 0.3,
			H = 0.3,
			Rotation = 0,
			Color = "#ffffff",
			Corner = 0.5,
			Stroke = 0,
			ZIndex = 7,
			Transparency = 0,
		},
	},
	--[[
		필수: 문양 두 겹만 담는다.

		살(반짝이는 효과)·원판·테두리 링·귀퉁이 보석은 `CardArt.luau`가 등급만
		보고 **모든 카드에 자동으로** 깐다 — 손으로 그리든 안 그리든 상관없이
		이미 있다. 여기 담으면 그 위에 또 한 겹 겹쳐 그려져 두 배로 진해진다.
		그래서 그림 그리기 탭 캔버스에 그 자동 층을 **참고용으로 비쳐 보이게**
		하고(`autoDecorShapes`), 여기 템플릿에는 문양만 남긴다.
	]]
	Essential = {
		{
			X = 0.5,
			Y = 0.5,
			W = 0.62,
			H = 0.62,
			Rotation = 45,
			Color = "#ffffff",
			Corner = 0.06,
			Stroke = 0.03,
			ZIndex = 6,
			Transparency = 0,
		},
		{
			X = 0.5,
			Y = 0.5,
			W = 0.3,
			H = 0.3,
			Rotation = 45,
			Color = "#ffffff",
			Corner = 0.04,
			Stroke = 0,
			ZIndex = 7,
			Transparency = 0,
		},
	},
}

function CardArtworks.Template(grade: string): { Shape }
	local source = TEMPLATES[grade] or TEMPLATES.Common
	local copy: { Shape } = {}
	for _, item in source do
		table.insert(copy, table.clone(item))
	end
	return copy
end

--[[
	손으로 만든 그림들.

	편집기에서 저장하면 `apply_config_edits.luau`가 이 표에 적는다.
	비어 있는 것이 정상이다 — 아무도 아직 그리지 않았다는 뜻이다.
]]
local ARTWORKS: { [string]: Artwork } = {
	["결투사_양날의_검"] = {
		Id = "결투사_양날의_검",
		Name = "결투사 - 양날의 검",
		Shapes = {
			{ X = 0.375, Y = 0.16, W = 0.101, H = 0.01, Rotation = -38, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 7, Transparency = 0 },
			{ X = 0.43, Y = 0.13, W = 0.047, H = 0.01, Rotation = 0, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 8, Transparency = 0 },
			{ X = 0.315, Y = 0.22, W = 0.089, H = 0.01, Rotation = -52, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 9, Transparency = 0 },
			{ X = 0.276, Y = 0.275, W = 0.093, H = 0.01, Rotation = -54, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 10, Transparency = 0 },
			{ X = 0.329, Y = 0.587, W = 0.58, H = 0.01, Rotation = 74, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 11, Transparency = 0 },
			{ X = 0.435, Y = 0.86, W = 0.057, H = 0.01, Rotation = 0, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 12, Transparency = 0 },
			{ X = 0.455, Y = 0.495, W = 0.74, H = 0.01, Rotation = 89, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 13, Transparency = 0 },
			{ X = 0.325, Y = 0.31, W = 0.15, H = 0.01, Rotation = 0, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 14, Transparency = 0 },
			{ X = 0.432, Y = 0.277, W = 0.045, H = 0.01, Rotation = -33, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 15, Transparency = 0 },
			{ X = 0.409, Y = 0.3, W = 0.04, H = 0.01, Rotation = -57, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 16, Transparency = 0 },
			{ X = 0.409, Y = 0.322, W = 0.04, H = 0.01, Rotation = 62, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 17, Transparency = 0 },
			{ X = 0.43, Y = 0.345, W = 0.045, H = 0.01, Rotation = 34, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 16, Transparency = 0 },
			{ X = 0.545, Y = 0.185, W = 0.053, H = 0.015, Rotation = 91, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 18, Transparency = 0 },
			{ X = 0.545, Y = 0.185, W = 0.053, H = 0.015, Rotation = 89, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 19, Transparency = 0 },
			{ X = 0.545, Y = 0.22, W = 0.025, H = 0.025, Rotation = 45, Color = "#ffffff", Corner = 0.04, Stroke = 0.005, ZIndex = 20, Transparency = 0 },
			{ X = 0.545, Y = 0.15, W = 0.025, H = 0.025, Rotation = 45, Color = "#ffffff", Corner = 0.04, Stroke = 0, ZIndex = 21, Transparency = 0 },
			{ X = 0.545, Y = 0.135, W = 0.02, H = 0.015, Rotation = 89, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 22, Transparency = 0 },
			{ X = 0.525, Y = 0.208, W = 0.025, H = 0.005, Rotation = 38, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 23, Transparency = 0 },
			{ X = 0.511, Y = 0.191, W = 0.025, H = 0.005, Rotation = 62, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 24, Transparency = 0 },
			{ X = 0.504, Y = 0.171, W = 0.025, H = 0.005, Rotation = 81, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 25, Transparency = 0 },
			{ X = 0.496, Y = 0.151, W = 0.025, H = 0.005, Rotation = 52, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 26, Transparency = 0 },
			{ X = 0.515, Y = 0.22, W = 0.03, H = 0.005, Rotation = 1, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 25, Transparency = 0 },
			{ X = 0.497, Y = 0.22, W = 0.03, H = 0.005, Rotation = 1, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 26, Transparency = 0 },
			{ X = 0.477, Y = 0.21, W = 0.025, H = 0.005, Rotation = 51, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 24, Transparency = 0 },
			{ X = 0.575, Y = 0.22, W = 0.03, H = 0.005, Rotation = 1, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 27, Transparency = 0 },
			{ X = 0.592, Y = 0.22, W = 0.03, H = 0.005, Rotation = 1, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 28, Transparency = 0 },
			{ X = 0.612, Y = 0.2275, W = 0.025, H = 0.005, Rotation = 51, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 25, Transparency = 0 },
			{ X = 0.545, Y = 0.245, W = 0.05, H = 0.05, Rotation = 0, Color = "#ffffff", Corner = 0.5, Stroke = 0.005, ZIndex = 29, Transparency = 0 },
			{ X = 0.539, Y = 0.565, W = 0.6, H = 0.005, Rotation = 89, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 30, Transparency = 0 },
			{ X = 0.552, Y = 0.565, W = 0.6, H = 0.005, Rotation = -89, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 31, Transparency = 0 },
			{ X = 0.5451, Y = 0.273, W = 0.04, H = 0.005, Rotation = 0, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 32, Transparency = 0 },
			{ X = 0.5, Y = 0.495, W = 0.463, H = 0.02, Rotation = 0, Color = "#ffffff", Corner = 0, Stroke = 0, ZIndex = 33, Transparency = 0 },
		},
	},
	["결투사의_레이피어"] = {
		Id = "결투사의_레이피어",
		Name = "결투사의 레이피어",
		Shapes = {
			{ X = 0.68, Y = 0.673, W = 0.24, H = 0.02, Rotation = 45, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 7, Transparency = 0 },
			{ X = 0.65, Y = 0.635, W = 0.199, H = 0.02, Rotation = 49, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 8, Transparency = 0 },
			{ X = 0.632, Y = 0.628, W = 0.172, H = 0.02, Rotation = 43, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 9, Transparency = 0 },
			{ X = 0.775, Y = 0.77, W = 0.05, H = 0.05, Rotation = 2, Color = "#ffffff", Corner = 0.04, Stroke = 0, ZIndex = 10, Transparency = 0 },
			{ X = 0.566, Y = 0.541, W = 0.2, H = 0.2, Rotation = -12, Color = "#ffffff", Corner = 0.5, Stroke = 0.01, ZIndex = 11, Transparency = 0 },
			{ X = 0.62, Y = 0.535, W = 0.177, H = 0.02, Rotation = -35, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 12, Transparency = 0 },
			{ X = 0.523, Y = 0.605, W = 0.147, H = 0.02, Rotation = -37, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 13, Transparency = 0 },
			{ X = 0.459, Y = 0.685, W = 0.1, H = 0.02, Rotation = -77, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 14, Transparency = 0 },
			{ X = 0.699, Y = 0.457, W = 0.094, H = 0.02, Rotation = -65, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 15, Transparency = 0 },
			{ X = 0.617, Y = 0.562, W = 0.076, H = 0.02, Rotation = -11, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 16, Transparency = 0 },
			{ X = 0.679, Y = 0.562, W = 0.076, H = 0.02, Rotation = 10, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 17, Transparency = 0 },
			{ X = 0.726, Y = 0.581, W = 0.075, H = 0.02, Rotation = 33, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 18, Transparency = 0 },
			{ X = 0.765, Y = 0.617, W = 0.081, H = 0.02, Rotation = 52, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 19, Transparency = 0 },
			{ X = 0.565, Y = 0.544, W = 0.06, H = 0.06, Rotation = 5, Color = "#ffffff", Corner = 0.04, Stroke = 0, ZIndex = 20, Transparency = 0 },
			{ X = 0.628, Y = 0.544, W = 0.106, H = 0.02, Rotation = -37, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 21, Transparency = 0 },
			{ X = 0.583, Y = 0.586, W = 0.073, H = 0.02, Rotation = 11, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 22, Transparency = 0 },
			{ X = 0.548, Y = 0.491, W = 0.1, H = 0.02, Rotation = 52, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 24, Transparency = 0 },
			{ X = 0.515, Y = 0.516, W = 0.1, H = 0.02, Rotation = 51, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 25, Transparency = 0 },
			{ X = 0.433, Y = 0.41, W = 0.206, H = 0.015, Rotation = 53, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 25, Transparency = 0 },
			{ X = 0.819, Y = 0.644, W = 0.081, H = 0.02, Rotation = -1, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 20, Transparency = 0 },
			{ X = 0.47, Y = 0.388, W = 0.206, H = 0.015, Rotation = 53, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 26, Transparency = 0 },
			{ X = 0.316, Y = 0.253, W = 0.206, H = 0.01, Rotation = 54, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 26, Transparency = 0 },
			{ X = 0.352, Y = 0.231, W = 0.206, H = 0.01, Rotation = 53, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 27, Transparency = 0 },
			{ X = 0.258, Y = 0.111, W = 0.206, H = 0.01, Rotation = 51, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 28, Transparency = 0 },
			{ X = 0.23, Y = 0.134, W = 0.206, H = 0.01, Rotation = 55, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 29, Transparency = 0 },
			{ X = 0.493, Y = 0.559, W = 0.15, H = 0.01, Rotation = -1, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 30, Transparency = 0 },
			{ X = 0.679, Y = 0.209, W = 0.256, H = 0.02, Rotation = -65, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 16, Transparency = 0 },
			{ X = 0.677, Y = 0.216, W = 0.256, H = 0.02, Rotation = 203, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 17, Transparency = 0 },
			{ X = 0.598, Y = 0.21, W = 0.119, H = 0.02, Rotation = 229, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 17, Transparency = 0 },
			{ X = 0.626, Y = 0.26, W = 0.135, H = 0.02, Rotation = 269, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 18, Transparency = 0 },
			{ X = 0.622, Y = 0.166, W = 0.135, H = 0.02, Rotation = -2, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 19, Transparency = 0 },
			{ X = 0.687, Y = 0.136, W = 0.135, H = 0.02, Rotation = -42, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 20, Transparency = 0 },
			{ X = 0.735, Y = 0.154, W = 0.135, H = 0.02, Rotation = 269, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 21, Transparency = 0 },
			{ X = 0.673, Y = 0.285, W = 0.135, H = 0.02, Rotation = -40, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 22, Transparency = 0 },
			{ X = 0.755, Y = 0.212, W = 0.135, H = 0.02, Rotation = 239, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 23, Transparency = 0 },
			{ X = 0.726, Y = 0.268, W = 0.135, H = 0.02, Rotation = -5, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 24, Transparency = 0 },
			{ X = 0.667, Y = 0.191, W = 0.135, H = 0.048, Rotation = 0, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 31, Transparency = 0 },
			{ X = 0.647, Y = 0.216, W = 0.157, H = 0.042, Rotation = 28, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 32, Transparency = 0 },
			{ X = 0.682, Y = 0.213, W = 0.162, H = 0.037, Rotation = -47, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 33, Transparency = 0 },
			{ X = 0.665, Y = 0.22, W = 0.085, H = 0.06, Rotation = 0, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 34, Transparency = 0 },
			{ X = 0.677, Y = 0.242, W = 0.117, H = 0.044, Rotation = -48, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 35, Transparency = 0 },
			{ X = 0.687, Y = 0.156, W = 0.153, H = 0.02, Rotation = -48, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 36, Transparency = 0 },
			{ X = 0.724, Y = 0.161, W = 0.089, H = 0.021, Rotation = 90, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 37, Transparency = 0 },
			{ X = 0.724, Y = 0.217, W = 0.164, H = 0.021, Rotation = 34, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 38, Transparency = 0 },
			{ X = 0.735, Y = 0.224, W = 0.08, H = 0.02, Rotation = 52, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 39, Transparency = 0 },
			{ X = 0.745, Y = 0.214, W = 0.087, H = 0.02, Rotation = 57, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 40, Transparency = 0 },
			{ X = 0.714, Y = 0.253, W = 0.136, H = 0.02, Rotation = -7, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 41, Transparency = 0 },
		},
	},
	["광속붕괴"] = {
		Id = "광속붕괴",
		Name = "광속붕괴",
		Shapes = {
			{ X = 0.274, Y = 0.467, W = 0.368, H = 0.02, Rotation = -10, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 7, Transparency = 0 },
			{ X = 0.72, Y = 0.535, W = 0.368, H = 0.02, Rotation = -10, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 8, Transparency = 0 },
			{ X = 0.539, Y = 0.711, W = 0.368, H = 0.02, Rotation = 101, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 9, Transparency = 0 },
			{ X = 0.467, Y = 0.711, W = 0.368, H = 0.02, Rotation = 79, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 9, Transparency = 0 },
			{ X = 0.28, Y = 0.535, W = 0.368, H = 0.02, Rotation = 12, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 9, Transparency = 0 },
			{ X = 0.709, Y = 0.468, W = 0.368, H = 0.02, Rotation = 12, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 9, Transparency = 0 },
			{ X = 0.465, Y = 0.295, W = 0.368, H = 0.02, Rotation = -78, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 9, Transparency = 0 },
			{ X = 0.54, Y = 0.294, W = 0.368, H = 0.02, Rotation = 79, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 9, Transparency = 0 },
			{ X = 0.492, Y = 0.498, W = 0.695, H = 0.025, Rotation = 0, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 10, Transparency = 0 },
			{ X = 0.502, Y = 0.503, W = 0.695, H = 0.025, Rotation = 90, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 11, Transparency = 0 },
			{ X = 0.488, Y = 0.479, W = 0.55, H = 0.02, Rotation = 0, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 11, Transparency = 0 },
			{ X = 0.514, Y = 0.515, W = 0.606, H = 0.02, Rotation = 0, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 12, Transparency = 0 },
			{ X = 0.485, Y = 0.505, W = 0.606, H = 0.02, Rotation = 90, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 13, Transparency = 0 },
			{ X = 0.52, Y = 0.49, W = 0.606, H = 0.02, Rotation = 90, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 13, Transparency = 0 },
			{ X = 0.494, Y = 0.501, W = 0.207, H = 0.134, Rotation = 0, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 14, Transparency = 0 },
			{ X = 0.475, Y = 0.39, W = 0.262, H = 0.052, Rotation = 101, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 15, Transparency = 0 },
			{ X = 0.529, Y = 0.624, W = 0.262, H = 0.052, Rotation = 101, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 16, Transparency = 0 },
			{ X = 0.529, Y = 0.368, W = 0.262, H = 0.052, Rotation = 84, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 16, Transparency = 0 },
			{ X = 0.475, Y = 0.595, W = 0.262, H = 0.052, Rotation = 81, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 16, Transparency = 0 },
			{ X = 0.606, Y = 0.471, W = 0.262, H = 0.052, Rotation = 193, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 16, Transparency = 0 },
			{ X = 0.624, Y = 0.526, W = 0.262, H = 0.052, Rotation = 173, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 16, Transparency = 0 },
			{ X = 0.381, Y = 0.525, W = 0.262, H = 0.052, Rotation = 190, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 16, Transparency = 0 },
			{ X = 0.381, Y = 0.476, W = 0.262, H = 0.052, Rotation = -12, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 16, Transparency = 0 },
		},
	},
	["광전사가_광광"] = {
		Id = "광전사가_광광",
		Name = "광전사가 광광",
		Shapes = {
			{ X = 0.55, Y = 0.5, W = 0.34, H = 0.34, Rotation = 0, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 7, Transparency = 0 },
			{ X = 0.479, Y = 0.322, W = 0.3, H = 0.05, Rotation = -63, Color = "#ffffff", Corner = 0, Stroke = 0, ZIndex = 8, Transparency = 0 },
			{ X = 0.621, Y = 0.324, W = 0.3, H = 0.05, Rotation = 63, Color = "#ffffff", Corner = 0, Stroke = 0, ZIndex = 9, Transparency = 0 },
			{ X = 0.551, Y = 0.179, W = 0.038, H = 0.032, Rotation = 45, Color = "#ffffff", Corner = 0.04, Stroke = 0, ZIndex = 10, Transparency = 0 },
			{ X = 0.557, Y = 0.354, W = 0.154, H = 0.234, Rotation = 0, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 11, Transparency = 0 },
			{ X = 0.251, Y = 0.588, W = 0.382, H = 0.043, Rotation = 62, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 12, Transparency = 0 },
			{ X = 0.515, Y = 0.764, W = 0.222, H = 0.02, Rotation = 0, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 13, Transparency = 0 },
			{ X = 0.21, Y = 0.58, W = 0.297, H = 0.039, Rotation = 71, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 14, Transparency = 0 },
			{ X = 0.319, Y = 0.67, W = 0.236, H = 0.029, Rotation = 37, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 15, Transparency = 0 },
			{ X = 0.507, Y = 0.759, W = 0.108, H = 0.02, Rotation = 11, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 17, Transparency = 0 },
			{ X = 0.451, Y = 0.75, W = 0.236, H = 0.029, Rotation = 21, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 16, Transparency = 0 },
			{ X = 0.293, Y = 0.625, W = 0.202, H = 0.02, Rotation = 47, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 16, Transparency = 0 },
			{ X = 0.177, Y = 0.395, W = 0.09, H = 0.02, Rotation = 93, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 18, Transparency = 0 },
			{ X = 0.183, Y = 0.426, W = 0.094, H = 0.02, Rotation = 81, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 19, Transparency = 0 },
			{ X = 0.166, Y = 0.395, W = 0.123, H = 0.02, Rotation = 98, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 20, Transparency = 0 },
			{ X = 0.178, Y = 0.321, W = 0.077, H = 0.0125, Rotation = 111, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 21, Transparency = 0 },
			{ X = 0.624, Y = 0.764, W = 0.212, H = 0.02, Rotation = -11, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 14, Transparency = 0 },
			{ X = 0.745, Y = 0.729, W = 0.077, H = 0.0125, Rotation = 150, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 22, Transparency = 0 },
			{ X = 0.299, Y = 0.75, W = 0.16, H = 0.035, Rotation = 41, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 15, Transparency = 0 },
			{ X = 0.414, Y = 0.811, W = 0.16, H = 0.035, Rotation = 16, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 16, Transparency = 0 },
			{ X = 0.53, Y = 0.822, W = 0.139, H = 0.02, Rotation = -13, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 17, Transparency = 0 },
			{ X = 0.641, Y = 0.785, W = 0.139, H = 0.02, Rotation = -24, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 18, Transparency = 0 },
			{ X = 0.733, Y = 0.741, W = 0.077, H = 0.0125, Rotation = 150, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 23, Transparency = 0 },
			{ X = 0.275, Y = 0.69, W = 0.124, H = 0.037, Rotation = 65, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 24, Transparency = 0 },
			{ X = 0.347, Y = 0.723, W = 0.12, H = 0.026, Rotation = 70, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 25, Transparency = 0 },
			{ X = 0.343, Y = 0.759, W = 0.12, H = 0.024, Rotation = 39, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 26, Transparency = 0 },
			{ X = 0.379, Y = 0.764, W = 0.125, H = 0.028, Rotation = 45, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 27, Transparency = 0 },
			{ X = 0.42, Y = 0.768, W = 0.142, H = 0.025, Rotation = 39, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 28, Transparency = 0 },
			{ X = 0.487, Y = 0.792, W = 0.159, H = 0.034, Rotation = 0, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 29, Transparency = 0 },
			{ X = 0.48, Y = 0.781, W = 0.135, H = 0.02, Rotation = 0, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 30, Transparency = 0 },
			{ X = 0.558, Y = 0.799, W = 0.155, H = 0.02, Rotation = -24, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 31, Transparency = 0 },
			{ X = 0.49, Y = 0.82, W = 0.115, H = 0.02, Rotation = 0, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 32, Transparency = 0 },
			{ X = 0.494, Y = 0.811, W = 0.116, H = 0.02, Rotation = 0, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 33, Transparency = 0 },
			{ X = 0.623, Y = 0.778, W = 0.122, H = 0.02, Rotation = -27, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 34, Transparency = 0 },
			{ X = 0.177, Y = 0.353, W = 0.065, H = 0.02, Rotation = 85, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 35, Transparency = 0 },
		},
	},
	["때리면서_섞기"] = {
		Id = "때리면서_섞기",
		Name = "때리면서 섞기",
		Shapes = {
			{ X = 0.279, Y = 0.385, W = 0.38, H = 0.02, Rotation = -62, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 7, Transparency = 0 },
			{ X = 0.57, Y = 0.254, W = 0.43, H = 0.02, Rotation = 11, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 8, Transparency = 0 },
			{ X = 0.352, Y = 0.633, W = 0.359, H = 0.02, Rotation = 29, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 9, Transparency = 0 },
			{ X = 0.64, Y = 0.503, W = 0.517, H = 0.02, Rotation = 122, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 10, Transparency = 0 },
			{ X = 0.663, Y = 0.761, W = 0.353, H = 0.02, Rotation = 15, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 11, Transparency = 0 },
			{ X = 0.847, Y = 0.475, W = 0.403, H = 0.02, Rotation = 68, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 12, Transparency = 0 },
			{ X = 0.447, Y = 0.423, W = 0.2, H = 0.567, Rotation = 31, Color = "#ffffff", Corner = 0.04, Stroke = 0.02, ZIndex = 13, Transparency = 0 },
			{ X = 0.608, Y = 0.148, W = 0.14, H = 0.075, Rotation = 37, Color = "#ffffff", Corner = 0.06, Stroke = 0, ZIndex = 14, Transparency = 0 },
			{ X = 0.407, Y = 0.487, W = 0.185, H = 0.413, Rotation = 31, Color = "#03b006", Corner = 0.06, Stroke = 0, ZIndex = 15, Transparency = 0 },
			{ X = 0.572, Y = 0.29, W = 0.112, H = 0.02, Rotation = -4, Color = "#03b006", Corner = 0.5, Stroke = 0, ZIndex = 16, Transparency = 0 },
			{ X = 0.486, Y = 0.28, W = 0.105, H = 0.02, Rotation = 16, Color = "#03b006", Corner = 0.5, Stroke = 0, ZIndex = 17, Transparency = 0 },
			{ X = 0.632, Y = 0.268, W = 0.079, H = 0.02, Rotation = -37, Color = "#03b006", Corner = 0.5, Stroke = 0, ZIndex = 18, Transparency = 0 },
			{ X = 0.557, Y = 0.365, W = 0.053, H = 0.158, Rotation = 31, Color = "#03b006", Corner = 0.04, Stroke = 0, ZIndex = 19, Transparency = 0 },
			{ X = 0.6, Y = 0.331, W = 0.198, H = 0.02, Rotation = -59, Color = "#03b006", Corner = 0.5, Stroke = 0, ZIndex = 20, Transparency = 0 },
			{ X = 0.504, Y = 0.325, W = 0.227, H = 0.052, Rotation = -8, Color = "#03b006", Corner = 0.5, Stroke = 0, ZIndex = 21, Transparency = 0 },
			{ X = 0.491, Y = 0.296, W = 0.088, H = 0.02, Rotation = 23, Color = "#03b006", Corner = 0.5, Stroke = 0, ZIndex = 22, Transparency = 0 },
		},
	},
	["블랙홀"] = {
		Id = "블랙홀",
		Name = "블랙홀",
		Shapes = {
			{ X = 0.5, Y = 0.5, W = 0.34, H = 0.34, Rotation = 0, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 7, Transparency = 0 },
			{ X = 0.361, Y = 0.665, W = 0.37, H = 0.02, Rotation = -58, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 8, Transparency = 0 },
			{ X = 0.685, Y = 0.369, W = 0.37, H = 0.02, Rotation = -59, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 9, Transparency = 0 },
			{ X = 0.646, Y = 0.338, W = 0.37, H = 0.02, Rotation = -44, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 10, Transparency = 0 },
			{ X = 0.399, Y = 0.692, W = 0.37, H = 0.02, Rotation = -43, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 10, Transparency = 0 },
			{ X = 0.38, Y = 0.617, W = 0.239, H = 0.02, Rotation = 116, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 11, Transparency = 0 },
			{ X = 0.669, Y = 0.413, W = 0.239, H = 0.02, Rotation = 114, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 12, Transparency = 0 },
			{ X = 0.441, Y = 0.666, W = 0.239, H = 0.02, Rotation = 148, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 12, Transparency = 0 },
			{ X = 0.618, Y = 0.363, W = 0.239, H = 0.02, Rotation = 136, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 12, Transparency = 0 },
			{ X = 0.384, Y = 0.664, W = 0.264, H = 0.02, Rotation = -53, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 13, Transparency = 0 },
			{ X = 0.506, Y = 0.553, W = 0.504, H = 0.033, Rotation = 135, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 14, Transparency = 0 },
			{ X = 0.621, Y = 0.397, W = 0.347, H = 0.038, Rotation = 130, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 15, Transparency = 0 },
			{ X = 0.652, Y = 0.391, W = 0.232, H = 0.02, Rotation = 122, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 16, Transparency = 0 },
			{ X = 0.614, Y = 0.384, W = 0.432, H = 0.02, Rotation = 133, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 17, Transparency = 0 },
			{ X = 0.61, Y = 0.359, W = 0.201, H = 0.02, Rotation = 142, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 18, Transparency = 0 },
			{ X = 0.423, Y = 0.591, W = 0.222, H = 0.05, Rotation = 125, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 19, Transparency = 0 },
		},
	},
	["새_그림"] = {
		Id = "새_그림",
		Name = "저울",
		Shapes = {
			{ X = 0.558, Y = 0.908, W = 0.101, H = 0.02, Rotation = 21, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 7, Transparency = 0 },
			{ X = 0.536, Y = 0.855, W = 0.15, H = 0.02, Rotation = 79, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 8, Transparency = 0 },
			{ X = 0.505, Y = 0.453, W = 0.732, H = 0.02, Rotation = 89, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 9, Transparency = 0 },
			{ X = 0.483, Y = 0.851, W = 0.15, H = 0.02, Rotation = 101, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 9, Transparency = 0 },
			{ X = 0.455, Y = 0.91, W = 0.101, H = 0.02, Rotation = 155, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 8, Transparency = 0 },
			{ X = 0.512, Y = 0.926, W = 0.22, H = 0.02, Rotation = 0, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 10, Transparency = 0 },
			{ X = 0.517, Y = 0.722, W = 0.255, H = 0.02, Rotation = 86, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 11, Transparency = 0 },
			{ X = 0.499, Y = 0.723, W = 0.255, H = 0.02, Rotation = 94, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 12, Transparency = 0 },
			{ X = 0.5, Y = 0.231, W = 0.588, H = 0.02, Rotation = 0, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 13, Transparency = 0 },
			{ X = 0.645, Y = 0.221, W = 0.291, H = 0.02, Rotation = 4, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 14, Transparency = 0 },
			{ X = 0.368, Y = 0.24, W = 0.291, H = 0.02, Rotation = 4, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 15, Transparency = 0 },
			{ X = 0.365, Y = 0.224, W = 0.291, H = 0.02, Rotation = -3, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 16, Transparency = 0 },
			{ X = 0.625, Y = 0.24, W = 0.291, H = 0.02, Rotation = -3, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 17, Transparency = 0 },
			{ X = 0.785, Y = 0.27, W = 0.091, H = 0.02, Rotation = 90, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 18, Transparency = 0 },
			{ X = 0.217, Y = 0.272, W = 0.091, H = 0.02, Rotation = 90, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 19, Transparency = 0 },
			{ X = 0.18, Y = 0.475, W = 0.383, H = 0.02, Rotation = 101, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 20, Transparency = 0 },
			{ X = 0.75, Y = 0.475, W = 0.383, H = 0.02, Rotation = 101, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 21, Transparency = 0 },
			{ X = 0.255, Y = 0.485, W = 0.383, H = 0.02, Rotation = 79, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 21, Transparency = 0 },
			{ X = 0.825, Y = 0.485, W = 0.383, H = 0.02, Rotation = 79, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 22, Transparency = 0 },
			{ X = 0.222, Y = 0.676, W = 0.239, H = 0.036, Rotation = 0, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 23, Transparency = 0 },
			{ X = 0.788, Y = 0.668, W = 0.239, H = 0.036, Rotation = 0, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 24, Transparency = 0 },
			{ X = 0.509, Y = 0.898, W = 0.049, H = 0.077, Rotation = 90, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 25, Transparency = 0 },
			{ X = 0.509, Y = 0.853, W = 0.12, H = 0.059, Rotation = 90, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 26, Transparency = 0 },
		},
	},
	["음악가_8분음표"] = {
		Id = "음악가_8분음표",
		Name = "음악가 - 8분음표",
		Shapes = {
			{ X = 0.414, Y = 0.743, W = 0.206, H = 0.129, Rotation = -15, Color = "#ffffff", Corner = 0.8, Stroke = 0, ZIndex = 7, Transparency = 0 },
			{ X = 0.5, Y = 0.47, W = 0.505, H = 0.026, Rotation = 90, Color = "#ffffff", Corner = 0, Stroke = 0, ZIndex = 8, Transparency = 0 },
			{ X = 0.523, Y = 0.295, W = 0.119, H = 0.022, Rotation = 65, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 9, Transparency = 0 },
			{ X = 0.536, Y = 0.296, W = 0.09, H = 0.02, Rotation = 48, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 10, Transparency = 0 },
			{ X = 0.533, Y = 0.372, W = 0.095, H = 0.02, Rotation = 22, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 11, Transparency = 0 },
			{ X = 0.591, Y = 0.405, W = 0.066, H = 0.02, Rotation = 39, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 12, Transparency = 0 },
			{ X = 0.663, Y = 0.508, W = 0.1, H = 0.02, Rotation = 72, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 13, Transparency = 0 },
			{ X = 0.629, Y = 0.443, W = 0.07, H = 0.02, Rotation = 51, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 14, Transparency = 0 },
			{ X = 0.671, Y = 0.575, W = 0.062, H = 0.02, Rotation = 105, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 14, Transparency = 0 },
			{ X = 0.653, Y = 0.625, W = 0.062, H = 0.01, Rotation = 113, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 15, Transparency = 0 },
			{ X = 0.659, Y = 0.62, W = 0.047, H = 0.01, Rotation = 118, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 16, Transparency = 0 },
			{ X = 0.624, Y = 0.411, W = 0.11, H = 0.02, Rotation = 62, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 17, Transparency = 0 },
			{ X = 0.574, Y = 0.339, W = 0.093, H = 0.02, Rotation = 50, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 18, Transparency = 0 },
			{ X = 0.647, Y = 0.46, W = 0.048, H = 0.02, Rotation = 65, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 19, Transparency = 0 },
			{ X = 0.694, Y = 0.252, W = 0.165, H = 0.02, Rotation = -34, Color = "#ffffff", Corner = 0, Stroke = 0, ZIndex = 20, Transparency = 0 },
			{ X = 0.672, Y = 0.549, W = 0.047, H = 0.02, Rotation = 83, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 14, Transparency = 0 },
			{ X = 0.659, Y = 0.605, W = 0.062, H = 0.01, Rotation = 106, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 16, Transparency = 0 },
			{ X = 0.538, Y = 0.332, W = 0.093, H = 0.035, Rotation = 65, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 10, Transparency = 0 },
			{ X = 0.538, Y = 0.346, W = 0.075, H = 0.047, Rotation = 26, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 11, Transparency = 0 },
			{ X = 0.586, Y = 0.382, W = 0.093, H = 0.02, Rotation = 50, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 19, Transparency = 0 },
			{ X = 0.566, Y = 0.372, W = 0.093, H = 0.02, Rotation = 49, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 19, Transparency = 0 },
			{ X = 0.762, Y = 0.282, W = 0.165, H = 0.02, Rotation = -34, Color = "#ffffff", Corner = 0, Stroke = 0, ZIndex = 21, Transparency = 0 },
			{ X = 0.257, Y = 0.565, W = 0.165, H = 0.02, Rotation = -34, Color = "#ffffff", Corner = 0, Stroke = 0, ZIndex = 21, Transparency = 0 },
			{ X = 0.324, Y = 0.59, W = 0.165, H = 0.02, Rotation = -34, Color = "#ffffff", Corner = 0, Stroke = 0, ZIndex = 21, Transparency = 0 },
		},
	},
	["포션"] = {
		Id = "포션",
		Name = "포션 버프",
		Shapes = {
			{ X = 0.485, Y = 0.531, W = 0.204, H = 0.524, Rotation = 45, Color = "#ffffff", Corner = 0.04, Stroke = 0.03, ZIndex = 7, Transparency = 0 },
			{ X = 0.693, Y = 0.326, W = 0.163, H = 0.085, Rotation = 45, Color = "#ffffff", Corner = 0.06, Stroke = 0, ZIndex = 8, Transparency = 0 },
			{ X = 0.424, Y = 0.587, W = 0.194, H = 0.365, Rotation = 45, Color = "#ffffff", Corner = 0.04, Stroke = 0, ZIndex = 9, Transparency = 0 },
			{ X = 0.575, Y = 0.428, W = 0.231, H = 0.02, Rotation = 22, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 10, Transparency = 0 },
			{ X = 0.615, Y = 0.446, W = 0.264, H = 0.02, Rotation = -9, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 11, Transparency = 0 },
			{ X = 0.549, Y = 0.452, W = 0.174, H = 0.056, Rotation = 25, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 12, Transparency = 0 },
			{ X = 0.647, Y = 0.473, W = 0.183, H = 0.043, Rotation = -26, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 13, Transparency = 0 },
			{ X = 0.624, Y = 0.485, W = 0.094, H = 0.056, Rotation = -40, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 14, Transparency = 0 },
			{ X = 0.214, Y = 0.285, W = 0.15, H = 0.047, Rotation = -45, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 15, Transparency = 0 },
			{ X = 0.306, Y = 0.396, W = 0.196, H = 0.047, Rotation = 45, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 16, Transparency = 0 },
			{ X = 0.297, Y = 0.28, W = 0.15, H = 0.047, Rotation = 45, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 17, Transparency = 0 },
			{ X = 0.197, Y = 0.396, W = 0.196, H = 0.047, Rotation = -45, Color = "#ffffff", Corner = 0.5, Stroke = 0, ZIndex = 16, Transparency = 0 },
		},
	},
}

--[[
	tools/card_art/build.py 가 그린 카드 그림(직업별 모듈 `CardArtworksGen/<직업>`).
	한 파일이 수백 KB 가 되지 않게 나눴고, 도형은 배열로 줄여 담았다 — 여기서 Shape 로 편다.
	편집기로 그린 그림(위 ARTWORKS)이 같은 Id 면 그쪽이 이긴다.
]]
local GENERATED = { "Musician", "Duelist", "Quasar", "Pulsar", "WallPilgrim", "WallMason", "WallBreaker", "Alchemist", "Berserker" }
for _, name in GENERATED do
	local ok, pack = pcall(function()
		return (require :: any)((script.Parent :: any).CardArtworksGen[name])
	end)
	if ok and type(pack) == "table" then
		for id, entry in pack do
			if not ARTWORKS[id] then
				local shapes: { Shape } = {}
				for _, s in entry[2] do
					table.insert(shapes, {
						X = s[1],
						Y = s[2],
						W = s[3],
						H = s[4],
						Rotation = s[5],
						Color = s[6],
						Corner = s[7],
						Stroke = s[8],
						ZIndex = s[9],
						Transparency = s[10],
					})
				end
				ARTWORKS[id] = { Id = id, Name = entry[1], Shapes = shapes }
			end
		end
	end
end

function CardArtworks.Get(id: string): Artwork?
	return ARTWORKS[id]
end

function CardArtworks.All(): { Artwork }
	local list: { Artwork } = {}
	for _, artwork in ARTWORKS do
		table.insert(list, artwork)
	end
	table.sort(list, function(a, b)
		return a.Id < b.Id
	end)
	return list
end

return CardArtworks
