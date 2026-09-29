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
local ARTWORKS: { [string]: Artwork } = {}

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
