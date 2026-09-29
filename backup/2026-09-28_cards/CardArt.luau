--!strict
--[[
	CardArt — 능력 카드의 **그림**을 만드는 곳.

	요청: "희귀, 필수, 일반 카드들 그림 그리고".

	--------------------------------------------------------------------------
	왜 이미지 파일이 아니라 도형인가

	로블록스에서 그림을 쓰려면 PNG를 업로드해 에셋 ID를 받아야 한다. 카드가 340장이라
	업로드도 관리도 감당이 안 되고, 무엇보다 이 저장소만으로는 재현이 안 된다.
	그래서 **GUI 도형을 코드로 조립해** 그린다. 파일이 늘지 않고, 카드를 추가하면
	그림도 자동으로 생긴다.

	--------------------------------------------------------------------------
	무엇을 기준으로 다르게 그리나

	  등급(Grade) → 테두리 장식과 광채. 필수 > 희귀 > 일반 순으로 화려하다.
	  태그(Tags)  → 문양. 카드의 기믹 축이 곧 그림이 된다. 40종이 있다.
	  Id          → 같은 태그라도 회전·개수·색조가 조금씩 달라진다.

	즉 한눈에 "이건 필수구나 / 이건 화상 계열이구나"가 읽히고, 그러면서 카드마다
	다르게 보인다.

	--------------------------------------------------------------------------
	출력은 **순수한 표**다

	Roblox 인스턴스를 여기서 만들지 않는다. 좌표 0~1의 도형 목록만 돌려주고,
	실제 Frame 생성은 `TowerBattleController`가 한다.
	`BattleGrid`(논리) ↔ `BattleArena`(월드)를 나눈 것과 같은 이유로,
	이렇게 해 두면 Lune에서 그림을 검사할 수 있다.
]]

export type Shape = {
	-- 그림 영역을 한 변 1인 정사각형으로 본다. 중심 기준 좌표다.
	X: number,
	Y: number,
	W: number,
	H: number,
	Rotation: number,
	Color: Color3,
	Transparency: number,
	-- 모서리 둥글기 비율. 0.5면 원(또는 캡슐)이 된다.
	Corner: number,
	-- 0이면 채운 도형, 양수면 그 두께의 테두리만 그린다.
	Stroke: number,
	ZIndex: number,
}

export type Art = {
	Background: Color3,
	Accent: Color3,
	Shapes: { Shape },
}

local CardArtworks = require(script.Parent.CardArtworks)

local CardArt = {}

--=== 결정적 난수 ===--

--[[
	카드 Id에서 뽑는 변주값.

	Random을 쓰지 않는 이유는 **같은 카드가 항상 같은 그림**이어야 하기 때문이다.
	보상 화면을 다시 열 때마다 문양이 돌아가면 카드를 못 알아본다.
]]
--[[
	djb2. 비트 연산을 쓰지 않는 이유는 두 가지다.
	  - Luau에는 `~`(XOR) 연산자가 없다. bit32.bxor를 불러야 한다.
	  - 곱셈만 쓰면 Lune 테스트 환경에서도 그대로 돈다.

	31비트 안에서 굴려 배정밀도(2^53) 정밀도를 넘지 않게 한다.
]]
local MODULUS = 2147483647

local function hash(text: string): number
	local value = 5381
	for index = 1, #text do
		value = (value * 33 + string.byte(text, index)) % MODULUS
	end
	return value
end

-- hash에서 0~1 실수를 여러 개 뽑는다. stream을 바꾸면 서로 독립인 값이 나온다.
local function unit(seed: number, stream: number): number
	local mixed = (seed + stream * 374761) % MODULUS
	mixed = (mixed * 48271) % MODULUS
	return mixed / MODULUS
end

--=== 색 ===--

type Palette = { R: number, G: number, B: number }

local function rgb(r: number, g: number, b: number): Palette
	return { R = r, G = g, B = b }
end

-- "#rrggbb" 를 Color3 으로. 손으로 그린 그림이 색을 글자로 들고 있어서 필요하다.
local function fromHex(text: string): Color3
	local r, g, b = text:match("^#(%x%x)(%x%x)(%x%x)$")
	if not r then
		return Color3.fromRGB(255, 255, 255)
	end
	return Color3.fromRGB(tonumber(r, 16) :: number, tonumber(g, 16) :: number, tonumber(b, 16) :: number)
end

local function toColor(palette: Palette, scale: number): Color3
	return Color3.fromRGB(
		math.clamp(math.floor(palette.R * scale), 0, 255),
		math.clamp(math.floor(palette.G * scale), 0, 255),
		math.clamp(math.floor(palette.B * scale), 0, 255)
	)
end

--=== 문양 ===--

local function shape(
	x: number,
	y: number,
	w: number,
	h: number,
	rotation: number,
	color: Color3,
	corner: number,
	stroke: number,
	zIndex: number,
	transparency: number?
): Shape
	return {
		X = x,
		Y = y,
		W = w,
		H = h,
		Rotation = rotation,
		Color = color,
		Transparency = transparency or 0,
		Corner = corner,
		Stroke = stroke,
		ZIndex = zIndex,
	}
end

--[[
	문양 하나를 그리는 함수들.

	쓸 수 있는 도형은 **직사각형과 링 둘뿐**이다. 로블록스 GUI는 이미지 없이는
	삼각형을 그릴 수 없어서, 45도 돌린 사각형(마름모)과 캡슐형 막대를 겹쳐
	칼날·화살촉·불꽃을 만든다.

	--------------------------------------------------------------------------
	완성도를 위해 지키는 네 가지

	  1. **깊이**   모든 획은 어두운 그림자를 한 겹 깔고 그 위에 얹는다(`paint`).
	                납작한 흰 막대가 아니라 세워진 물체로 읽힌다.
	  2. **굵기**   획을 얇게 여러 개 늘어놓지 않고 굵게 적게 쓴다. 작게 줄여도
	                실루엣이 남는다.
	  3. **꽉 채움** 메달리온 안쪽(대략 0.2~0.8)을 채운다. 예전에는 문양이 작고
	                배경 무늬가 넓어 무엇이 주인공인지 흐렸다.
	  4. **한 초점** 장식을 흩뿌리지 않고 가운데 하나에 모은다.

	  rest = 변주값 (0~1). 같은 문양이라도 카드마다 조금씩 달라진다.
]]

-- 획 밑에 깔리는 그림자. 등급색 위에서 깊이를 만든다.
local SHADOW = Color3.fromRGB(18, 14, 30)
-- 그림자를 아래로 얼마나 밀지.
local SHADOW_DROP = 0.018

--[[
	획 하나를 **그림자 + 본체** 두 겹으로 찍는다.

	그림자를 따로 부르지 않고 여기 묶어 두는 이유: 한 군데서만 관리하면 문양을
	새로 추가할 때 깊이를 빼먹을 수 없다.
]]
local function paint(
	out: { Shape },
	x: number,
	y: number,
	w: number,
	h: number,
	rotation: number,
	color: Color3,
	corner: number,
	zIndex: number,
	transparency: number?
): ()
	table.insert(out, shape(x, y + SHADOW_DROP, w, h, rotation, SHADOW, corner, 0, zIndex - 1, 0.45))
	table.insert(out, shape(x, y, w, h, rotation, color, corner, 0, zIndex, transparency))
end

-- 테두리만 있는 링. 링은 그림자를 얕게 준다(속이 비어 있어 짙으면 탁해진다).
local function ring(
	out: { Shape },
	x: number,
	y: number,
	size: number,
	thickness: number,
	color: Color3,
	zIndex: number,
	transparency: number?
): ()
	table.insert(out, shape(x, y + SHADOW_DROP, size, size, 0, SHADOW, 0.5, thickness, zIndex - 1, 0.55))
	table.insert(out, shape(x, y, size, size, 0, color, 0.5, thickness, zIndex, transparency))
end

type Glyph = (color: Color3, dim: Color3, rest: (number) -> number) -> { Shape }

-- 문양은 이 z부터 쌓는다. 아래는 배경·메달리온 자리다.
local GZ = 6

--[[
	문양 32개. **태그 하나에 문양 하나**다.

	예전에는 14개 문양을 32개 태그가 나눠 썼다. "같은 축이면 같은 그림"이 읽히기를
	바랐지만, 실제로는 벽 부수는 자의 희귀·일반과 연금술사의 희귀가 똑같아 보였다.
	카드를 그림으로 구분하려는 것이 목적이므로, 축을 읽히게 하는 쪽보다 **카드가
	서로 달라 보이는 쪽**을 택한다. 축은 바탕색(등급)과 부호 보석이 맡는다.

	--------------------------------------------------------------------------
	그리는 규칙 (전부 사각형과 링으로만 만든다)

	  1. **깊이**   모든 획은 `paint`로 그림자를 한 겹 깔고 올린다.
	  2. **굵기**   획을 얇게 여러 개 늘어놓지 않는다. 작게 줄여도 실루엣이 남게.
	  3. **꽉 채움** 메달리온 안쪽(대략 0.15~0.85)을 채운다.
	  4. **한 초점** 장식을 흩뿌리지 않는다.

	  rest = 변주값 (0~1). 같은 문양이라도 카드마다 조금씩 달라진다.
]]

--=== 방어 계열 ===--

-- 방패(Guard): 몸판 + 아래 꼭지 + 중앙 보스 + 세로 리브.
local function shield(color: Color3, dim: Color3, rest: (number) -> number): { Shape }
	local out: { Shape } = {}
	local wide = 0.56 + rest(1) * 0.05

	paint(out, 0.5, 0.42, wide, 0.42, 0, color, 0.2, GZ)
	paint(out, 0.5, 0.66, wide * 0.78, wide * 0.78, 45, color, 0.14, GZ)
	table.insert(out, shape(0.5, 0.5, wide * 0.74, 0.62, 0, dim, 0.18, 0.022, GZ + 2, 0.25))
	paint(out, 0.5, 0.48, 0.055, 0.42, 0, dim, 0.5, GZ + 3)
	paint(out, 0.5, 0.44, 0.17, 0.17, 0, color, 0.5, GZ + 4)
	paint(out, 0.5, 0.44, 0.08, 0.08, 0, dim, 0.5, GZ + 5)
	return out
end

--[[
	이지스(Aegis): 겹겹이 두른 돔.

	살(spoke)을 쓰지 않는다 — 결계(Ward)가 링 + 살 + 마름모라서, 여기에 살을 두면
	둘이 같은 그림이 된다. 대신 **속이 찬 원을 겹쳐 쌓고** 아래를 받침으로 잘라
	돔으로 읽히게 한다.
]]
local function aegis(color: Color3, dim: Color3, rest: (number) -> number): { Shape }
	local out: { Shape } = {}
	local lift = rest(1) * 0.05

	ring(out, 0.5, 0.56 - lift, 0.92, 0.05, dim, GZ, 0.4)
	paint(out, 0.5, 0.56 - lift, 0.72, 0.72, 0, color, 0.5, GZ + 2)
	paint(out, 0.5, 0.56 - lift, 0.5, 0.5, 0, dim, 0.5, GZ + 3)
	paint(out, 0.5, 0.56 - lift, 0.3, 0.3, 45, color, 0.05, GZ + 4)
	paint(out, 0.5, 0.92, 0.94, 0.18, 0, color, 0.1, GZ + 5)
	return out
end

-- 도금(Plating): 비늘 갑옷 세 줄. 겹쳐 놓아 층이 보이게 한다.
local function plating(color: Color3, dim: Color3, rest: (number) -> number): { Shape }
	local out: { Shape } = {}
	local drift = rest(1) * 0.03

	for row = 1, 3 do
		local y = 0.34 + (row - 1) * 0.21 + drift
		local count = if row % 2 == 1 then 3 else 2
		for index = 1, count do
			local x = 0.5 + (index - (count + 1) / 2) * 0.25
			paint(out, x, y, 0.23, 0.27, 0, if row == 2 then color else dim, 0.4, GZ + row)
		end
	end
	paint(out, 0.5, 0.16, 0.82, 0.09, 0, color, 0.4, GZ + 5)
	return out
end

-- 결계(Ward): 룬 원. 겹친 링 + 네 방향 축 + 가운데 마름모.
local function ward(color: Color3, dim: Color3, rest: (number) -> number): { Shape }
	local out: { Shape } = {}
	local spin = rest(1) * 30

	ring(out, 0.5, 0.5, 0.84, 0.03, dim, GZ, 0.3)
	for index = 0, 3 do
		paint(out, 0.5, 0.5, 0.05, 0.9, spin + index * 45, dim, 0.5, GZ + 1)
	end
	ring(out, 0.5, 0.5, 0.6, 0.05, color, GZ + 3)
	paint(out, 0.5, 0.5, 0.3, 0.3, 45, color, 0.06, GZ + 5)
	paint(out, 0.5, 0.5, 0.13, 0.13, 45, dim, 0.03, GZ + 6)
	return out
end

-- 인내(Endure): 모래시계. 마름모 두 개를 꼭짓점끼리 맞대 허리를 만든다.
local function endure(color: Color3, dim: Color3, rest: (number) -> number): { Shape }
	local out: { Shape } = {}
	local sand = 0.16 + rest(1) * 0.08

	paint(out, 0.5, 0.23, 0.38, 0.38, 45, color, 0.06, GZ)
	paint(out, 0.5, 0.77, 0.38, 0.38, 45, color, 0.06, GZ)
	paint(out, 0.5, 0.5, 0.08, 0.3, 0, dim, 0.5, GZ + 2)
	paint(out, 0.5, 0.76, 0.26, sand, 0, dim, 0.2, GZ + 3)
	paint(out, 0.5, 0.1, 0.58, 0.09, 0, color, 0.3, GZ + 4)
	paint(out, 0.5, 0.9, 0.58, 0.09, 0, color, 0.3, GZ + 4)
	return out
end

-- 선봉(Vanguard): 앞으로 향한 쐐기 셋. 뒤로 갈수록 흐려 대열로 읽힌다.
local function vanguard(color: Color3, dim: Color3, rest: (number) -> number): { Shape }
	local out: { Shape } = {}
	local lean = 36 + rest(1) * 8

	for index = 0, 2 do
		local y = 0.32 + index * 0.23
		local thickness = 0.14 - index * 0.03
		local tone = if index == 0 then color else dim
		paint(out, 0.31, y, thickness, 0.52, lean, tone, 0.5, GZ + (2 - index) * 2)
		paint(out, 0.69, y, thickness, 0.52, -lean, tone, 0.5, GZ + (2 - index) * 2)
	end
	return out
end

-- 닻(Anchor): 고리 + 기둥 + 스톡 + 갈고리.
local function anchor(color: Color3, dim: Color3, rest: (number) -> number): { Shape }
	local out: { Shape } = {}
	local fluke = 0.3 + rest(1) * 0.05

	ring(out, 0.5, 0.18, 0.24, 0.05, color, GZ + 4)
	paint(out, 0.5, 0.56, 0.11, 0.62, 0, color, 0.5, GZ)
	paint(out, 0.5, 0.36, 0.56, 0.08, 0, color, 0.5, GZ + 2)
	paint(out, 0.27, 0.74, 0.09, fluke, 40, color, 0.5, GZ + 1)
	paint(out, 0.73, 0.74, 0.09, fluke, -40, color, 0.5, GZ + 1)
	paint(out, 0.5, 0.85, 0.42, 0.08, 0, dim, 0.5, GZ + 3)
	return out
end

--[[
	도발(Taunt): 오른쪽으로 벌어지는 확성기 + 퍼져 나가는 음파.

	음파를 동심원으로 그리면 나팔이 원 한가운데 박혀 방향이 사라진다. 길이가 다른
	세로 획 셋으로 대신해 **어느 쪽으로 지르고 있는지**가 읽히게 한다.
]]
local function taunt(color: Color3, dim: Color3, rest: (number) -> number): { Shape }
	local out: { Shape } = {}
	local reach = 0.16 + rest(1) * 0.06

	paint(out, 0.17, 0.5, 0.14, 0.16, 0, dim, 0.4, GZ)
	paint(out, 0.3, 0.5, 0.17, 0.32, 0, color, 0.2, GZ + 1)
	paint(out, 0.45, 0.5, 0.21, 0.58, 0, color, 0.14, GZ + 2)
	paint(out, 0.52, 0.5, 0.12, 0.44, 0, dim, 0.3, GZ + 3)
	for index = 1, 3 do
		paint(out, 0.67 + (index - 1) * 0.13, 0.5, 0.06, 0.2 + index * reach, 0, dim, 0.5, GZ + 4)
	end
	return out
end

--=== 근접 계열 ===--

-- 정밀(Precision): 레이피어. 컵 가드와 **가느다란** 날로 무게를 뺀다.
local function precision(color: Color3, dim: Color3, rest: (number) -> number): { Shape }
	local out: { Shape } = {}
	local tilt = -30 + rest(1) * 12
	local function along(distance: number): (number, number)
		local radians = math.rad(tilt)
		return 0.5 + math.sin(radians) * distance, 0.5 - math.cos(radians) * distance
	end

	local pommelX, pommelY = along(-0.36)
	paint(out, pommelX, pommelY, 0.11, 0.13, tilt, dim, 0.5, GZ)
	local gripX, gripY = along(-0.24)
	paint(out, gripX, gripY, 0.09, 0.2, tilt, dim, 0.4, GZ)
	local cupX, cupY = along(-0.11)
	ring(out, cupX, cupY, 0.32, 0.05, color, GZ + 2)
	local bladeX, bladeY = along(0.18)
	paint(out, bladeX, bladeY, 0.07, 0.5, tilt, color, 0.04, GZ + 3)
	local tipX, tipY = along(0.45)
	paint(out, tipX, tipY, 0.09, 0.09, tilt + 45, color, 0.02, GZ + 4)
	return out
end

-- 처형(Execute): 도끼. 무거운 날 판을 크게 잡아 정밀과 정반대로 읽히게.
local function execute(color: Color3, dim: Color3, rest: (number) -> number): { Shape }
	local out: { Shape } = {}
	local lean = -14 + rest(1) * 10

	paint(out, 0.44, 0.58, 0.1, 0.78, lean, dim, 0.4, GZ)
	paint(out, 0.56, 0.32, 0.46, 0.4, lean, color, 0.16, GZ + 2)
	paint(out, 0.76, 0.32, 0.22, 0.38, lean + 8, color, 0.5, GZ + 3)
	paint(out, 0.42, 0.13, 0.17, 0.17, lean + 45, dim, 0.03, GZ + 4)
	return out
end

-- 반격(Riposte): 엇갈린 검 두 자루 + 부딪친 자리의 불꽃.
local function riposte(color: Color3, dim: Color3, rest: (number) -> number): { Shape }
	local out: { Shape } = {}
	local spread = 28 + rest(1) * 10

	for _, side in { -1, 1 } do
		local angle = side * spread
		local tone = if side < 0 then color else dim
		paint(out, 0.5, 0.44, 0.1, 0.82, angle, tone, 0.05, GZ + (if side < 0 then 2 else 0))
		paint(out, 0.5 - side * 0.2, 0.72, 0.3, 0.075, angle, color, 0.4, GZ + 4)
	end
	paint(out, 0.5, 0.42, 0.19, 0.19, 45, color, 0.03, GZ + 6)
	return out
end

-- 심판(Judgment): 저울. 접시가 살짝 기울어 판정 중인 것으로 보이게 한다.
local function judgment(color: Color3, dim: Color3, rest: (number) -> number): { Shape }
	local out: { Shape } = {}
	local tip = rest(1) * 8 - 4

	paint(out, 0.5, 0.54, 0.1, 0.68, 0, color, 0.3, GZ + 2)
	paint(out, 0.5, 0.87, 0.46, 0.09, 0, color, 0.4, GZ + 3)
	paint(out, 0.5, 0.24, 0.8, 0.075, tip, color, 0.5, GZ + 4)
	for _, side in { -1, 1 } do
		local x = 0.5 + side * 0.35
		local y = 0.24 + side * math.rad(tip) * 0.35
		paint(out, x, y + 0.11, 0.04, 0.18, 0, dim, 0.5, GZ)
		paint(out, x, y + 0.24, 0.31, 0.15, 0, dim, 0.45, GZ + 1)
	end
	return out
end

-- 독주(Solo): 무대 조명 아래 혼자 선 사람.
local function solo(color: Color3, dim: Color3, rest: (number) -> number): { Shape }
	local out: { Shape } = {}
	local beam = 20 + rest(1) * 8

	paint(out, 0.34, 0.58, 0.13, 0.74, beam, dim, 0.3, GZ, 0.55)
	paint(out, 0.66, 0.58, 0.13, 0.74, -beam, dim, 0.3, GZ, 0.55)
	paint(out, 0.5, 0.6, 0.32, 0.66, 0, dim, 0.2, GZ + 1, 0.6)
	paint(out, 0.5, 0.15, 0.32, 0.15, 0, color, 0.3, GZ + 3)
	paint(out, 0.5, 0.78, 0.24, 0.3, 0, color, 0.4, GZ + 5)
	paint(out, 0.5, 0.58, 0.16, 0.16, 0, color, 0.5, GZ + 6)
	return out
end

--=== 불·분노 계열 ===--

-- 화상(Burn): 큰 불꽃 하나 + 옆으로 튄 불씨 둘.
local function burn(color: Color3, dim: Color3, rest: (number) -> number): { Shape }
	local out: { Shape } = {}
	local lean = -7 + rest(1) * 14

	paint(out, 0.24, 0.72, 0.26, 0.3, 45 + lean * 1.6, dim, 0.12, GZ)
	paint(out, 0.76, 0.72, 0.26, 0.3, 45 - lean * 1.6, dim, 0.12, GZ)
	paint(out, 0.5, 0.58, 0.48, 0.52, 45 + lean * 0.5, color, 0.14, GZ + 2)
	paint(out, 0.5, 0.44, 0.21, 0.25, 45 + lean, dim, 0.08, GZ + 4)
	return out
end

-- 분노(Rage): 치켜올린 눈썹 + 벌린 입의 이빨. 얼굴로 읽히게 한다.
local function rage(color: Color3, dim: Color3, rest: (number) -> number): { Shape }
	local out: { Shape } = {}
	local anger = 22 + rest(1) * 10

	paint(out, 0.28, 0.28, 0.42, 0.12, anger, color, 0.4, GZ + 2)
	paint(out, 0.72, 0.28, 0.42, 0.12, -anger, color, 0.4, GZ + 2)
	paint(out, 0.5, 0.66, 0.58, 0.38, 0, dim, 0.3, GZ)
	for index = 1, 3 do
		paint(out, 0.28 + (index - 1) * 0.22, 0.6, 0.15, 0.15, 45, color, 0.02, GZ + 3)
	end
	return out
end

-- 광란(Frenzy): 소용돌이. 길이가 다른 획을 60도씩 돌려 회전으로 읽히게.
local function frenzy(color: Color3, dim: Color3, rest: (number) -> number): { Shape }
	local out: { Shape } = {}
	local spin = rest(1) * 60

	for index = 0, 2 do
		local tone = if index == 0 then color else dim
		paint(out, 0.5, 0.5, 0.17, 0.9 - index * 0.16, spin + index * 60, tone, 0.5, GZ + index)
	end
	ring(out, 0.5, 0.5, 0.5, 0.055, color, GZ + 4)
	paint(out, 0.5, 0.5, 0.19, 0.19, 45, color, 0.03, GZ + 6)
	return out
end

-- 촉매(Catalyst): 결정 + 위로 튀는 스파크.
local function catalyst(color: Color3, dim: Color3, rest: (number) -> number): { Shape }
	local out: { Shape } = {}
	local facet = rest(1) * 10 - 5

	paint(out, 0.5, 0.48, 0.48, 0.48, 45 + facet, color, 0.05, GZ)
	paint(out, 0.5, 0.68, 0.42, 0.42, 45 + facet, color, 0.05, GZ + 1)
	paint(out, 0.5, 0.58, 0.15, 0.46, facet, dim, 0.06, GZ + 3)
	paint(out, 0.38, 0.19, 0.06, 0.26, 26, dim, 0.5, GZ + 4)
	paint(out, 0.62, 0.19, 0.06, 0.26, -26, dim, 0.5, GZ + 4)
	return out
end

-- 과부하(Overload): 터지는 별. 살이 여덟, 가운데 핵.
local function overload(color: Color3, dim: Color3, rest: (number) -> number): { Shape }
	local out: { Shape } = {}
	local spin = rest(1) * 30

	for index = 0, 3 do
		local tone = if index % 2 == 0 then color else dim
		paint(out, 0.5, 0.5, 0.11, 0.98, spin + index * 45, tone, 0.5, GZ)
	end
	ring(out, 0.5, 0.5, 0.5, 0.05, color, GZ + 3)
	paint(out, 0.5, 0.5, 0.3, 0.3, 0, color, 0.5, GZ + 5)
	paint(out, 0.5, 0.5, 0.13, 0.13, 45, dim, 0.03, GZ + 6)
	return out
end

--=== 피·희생 계열 ===--

-- 피(Blood): 큰 방울 + 아래로 튄 작은 방울들.
local function blood(color: Color3, dim: Color3, rest: (number) -> number): { Shape }
	local out: { Shape } = {}
	local splash = 2 + math.floor(rest(1) * 2)

	paint(out, 0.5, 0.56, 0.46, 0.46, 0, color, 0.5, GZ)
	paint(out, 0.5, 0.28, 0.31, 0.31, 45, color, 0.05, GZ)
	paint(out, 0.41, 0.52, 0.13, 0.16, -12, dim, 0.5, GZ + 3)
	for index = 1, splash do
		local x = 0.5 + (index - (splash + 1) / 2) * 0.3
		paint(out, x, 0.88, 0.11, 0.13, 0, dim, 0.5, GZ + 2)
	end
	return out
end

-- 벼랑(Brink): 갈라진 절벽과 떨어지는 조각. 체력이 깎인 상태를 나타낸다.
local function brink(color: Color3, dim: Color3, rest: (number) -> number): { Shape }
	local out: { Shape } = {}
	local crack = 0.07 + rest(1) * 0.04

	paint(out, 0.25, 0.74, 0.44, 0.42, 0, color, 0.05, GZ)
	paint(out, 0.31, 0.52, 0.32, 0.2, 0, color, 0.05, GZ + 1)
	paint(out, 0.79, 0.79, 0.36, 0.34, 0, dim, 0.05, GZ)
	paint(out, 0.54, 0.66, crack, 0.56, 9, dim, 0.5, GZ + 3)
	paint(out, 0.58, 0.34, 0.16, 0.16, 30, color, 0.04, GZ + 4)
	paint(out, 0.69, 0.17, 0.1, 0.1, 14, dim, 0.04, GZ + 4)
	return out
end

-- 희생(Sacrifice): 제단에 꽂힌 단검 + 떨어지는 방울.
local function sacrifice(color: Color3, dim: Color3, rest: (number) -> number): { Shape }
	local out: { Shape } = {}
	local drift = rest(1) * 8 - 4

	paint(out, 0.5, 0.82, 0.68, 0.15, 0, dim, 0.08, GZ)
	paint(out, 0.5, 0.14, 0.13, 0.17, drift, dim, 0.4, GZ + 1)
	paint(out, 0.5, 0.25, 0.38, 0.08, drift, color, 0.4, GZ + 3)
	paint(out, 0.5, 0.49, 0.17, 0.42, drift, color, 0.05, GZ + 2)
	paint(out, 0.5, 0.69, 0.15, 0.15, drift + 45, color, 0.02, GZ + 4)
	paint(out, 0.29, 0.93, 0.1, 0.12, 0, color, 0.5, GZ + 5)
	paint(out, 0.71, 0.93, 0.08, 0.1, 0, color, 0.5, GZ + 5)
	return out
end

--=== 원거리 계열 ===--

-- 연사(Volley): 나란히 날아가는 화살 셋. 가운데만 밝게 한다.
local function volley(color: Color3, dim: Color3, rest: (number) -> number): { Shape }
	local out: { Shape } = {}
	local fan = 9 + rest(1) * 10

	for index = -1, 1 do
		local angle = index * fan
		local x = 0.5 + index * 0.27
		local tone = if index == 0 then color else dim
		paint(out, x, 0.58, 0.08, 0.6, angle, tone, 0.5, GZ + 2 + index)
		paint(out, x + index * 0.06, 0.24, 0.19, 0.19, angle + 45, tone, 0.03, GZ + 4 + index)
	end
	return out
end

-- 표식(Mark): 조준 십자선. 링 두 겹 + 십자 + 가운데 점.
local function mark(color: Color3, dim: Color3, rest: (number) -> number): { Shape }
	local out: { Shape } = {}
	local spin = rest(1) * 16 - 8

	ring(out, 0.5, 0.5, 0.8, 0.045, color, GZ)
	for index = 0, 1 do
		paint(out, 0.5, 0.5, 0.06, 1.0, spin + index * 90, dim, 0.5, GZ + 1)
	end
	ring(out, 0.5, 0.5, 0.4, 0.055, dim, GZ + 3)
	-- 가운데는 마름모가 아니라 점이다. 결계(Ward)의 마름모 핵과 겹치지 않게.
	paint(out, 0.5, 0.5, 0.17, 0.17, 0, color, 0.5, GZ + 5)
	return out
end

-- 확산(Spread): 가운데에서 네 방향으로 뻗는 화살.
local function spread(color: Color3, dim: Color3, rest: (number) -> number): { Shape }
	local out: { Shape } = {}
	local spin = rest(1) * 30

	for index = 0, 3 do
		local angle = spin + index * 90
		local radians = math.rad(angle)
		paint(out, 0.5 + math.sin(radians) * 0.28, 0.5 - math.cos(radians) * 0.28, 0.08, 0.26, angle, dim, 0.5, GZ)
		paint(
			out,
			0.5 + math.sin(radians) * 0.44,
			0.5 - math.cos(radians) * 0.44,
			0.18,
			0.18,
			angle + 45,
			color,
			0.03,
			GZ + 2
		)
	end
	paint(out, 0.5, 0.5, 0.28, 0.28, 0, color, 0.5, GZ + 4)
	paint(out, 0.5, 0.5, 0.12, 0.12, 0, dim, 0.5, GZ + 6)
	return out
end

-- 충전(Charge): 번개 + 바깥 궤도 링.
local function charge(color: Color3, dim: Color3, rest: (number) -> number): { Shape }
	local out: { Shape } = {}
	local zag = 24 + rest(1) * 12

	ring(out, 0.5, 0.5, 0.88, 0.035, dim, GZ, 0.45)
	paint(out, 0.58, 0.27, 0.15, 0.42, zag, color, 0.05, GZ + 2)
	paint(out, 0.42, 0.7, 0.15, 0.42, zag, color, 0.05, GZ + 2)
	paint(out, 0.5, 0.48, 0.38, 0.13, -16, color, 0.05, GZ + 4)
	return out
end

--=== 신앙 계열 ===--

-- 기도력(Faith): 십자가 + 후광.
local function faith(color: Color3, dim: Color3, rest: (number) -> number): { Shape }
	local out: { Shape } = {}
	local spin = rest(1) * 8 - 4

	ring(out, 0.5, 0.27, 0.46, 0.04, dim, GZ, 0.35)
	paint(out, 0.5, 0.53, 0.19, 0.78, spin, color, 0.1, GZ + 2)
	paint(out, 0.5, 0.43, 0.62, 0.19, spin, color, 0.1, GZ + 2)
	paint(out, 0.5, 0.43, 0.19, 0.19, spin + 45, dim, 0.04, GZ + 4)
	paint(out, 0.5, 0.86, 0.32, 0.06, spin, dim, 0.5, GZ + 3)
	return out
end

--=== 음악 계열 ===--

-- 음표(Melody): 한 개짜리 8분음표.
local function melody(color: Color3, dim: Color3, rest: (number) -> number): { Shape }
	local out: { Shape } = {}
	local lean = -14 + rest(1) * 10

	paint(out, 0.58, 0.44, 0.09, 0.6, 0, color, 0.3, GZ)
	paint(out, 0.4, 0.7, 0.35, 0.27, lean, color, 0.5, GZ + 2)
	paint(out, 0.4, 0.7, 0.17, 0.12, lean, dim, 0.5, GZ + 4)
	paint(out, 0.72, 0.19, 0.27, 0.09, 28, color, 0.4, GZ + 3)
	paint(out, 0.7, 0.31, 0.21, 0.08, 28, dim, 0.4, GZ + 3)
	return out
end

-- 합창(Chorus): 보표 위에 늘어선 음표 셋. 음표 하나짜리와 확실히 구분된다.
local function chorus(color: Color3, dim: Color3, rest: (number) -> number): { Shape }
	local out: { Shape } = {}
	local sway = rest(1) * 10 - 5

	for index = 1, 3 do
		local x = 0.25 + (index - 1) * 0.25
		local y = 0.68 - (index - 2) * 0.11
		local tone = if index == 2 then color else dim
		paint(out, x + 0.1, y - 0.19, 0.06, 0.36, 0, tone, 0.3, GZ)
		paint(out, x, y, 0.23, 0.18, sway, tone, 0.5, GZ + 2)
	end
	paint(out, 0.5, 0.92, 0.9, 0.045, 0, color, 0.5, GZ + 4)
	paint(out, 0.5, 0.12, 0.9, 0.035, 0, dim, 0.5, GZ + 4, 0.4)
	return out
end

-- 박자표(Tempo): 메트로놈. 진자가 기울어 박자가 도는 것으로 읽힌다.
local function tempo(color: Color3, dim: Color3, rest: (number) -> number): { Shape }
	local out: { Shape } = {}
	local swing = -18 + rest(1) * 36
	local radians = math.rad(swing)

	paint(out, 0.5, 0.64, 0.54, 0.5, 0, color, 0.1, GZ)
	paint(out, 0.5, 0.32, 0.28, 0.3, 0, color, 0.1, GZ + 1)
	paint(out, 0.5, 0.56, 0.06, 0.62, swing, dim, 0.4, GZ + 3)
	paint(out, 0.5 + math.sin(radians) * 0.22, 0.56 - math.cos(radians) * 0.22, 0.17, 0.1, swing, dim, 0.2, GZ + 4)
	paint(out, 0.5, 0.88, 0.64, 0.09, 0, dim, 0.3, GZ + 5)
	return out
end

--=== 연쇄·제작 계열 ===--

-- 사슬(Chain): 맞물린 링 셋.
local function chain(color: Color3, dim: Color3, rest: (number) -> number): { Shape }
	local out: { Shape } = {}
	local tilt = -18 + rest(1) * 36

	for index = 1, 3 do
		local t = (index - 2) * 0.23
		local radians = math.rad(tilt)
		local x = 0.5 + math.cos(radians) * t
		local y = 0.5 + math.sin(radians) * t
		ring(out, x, y, 0.33, 0.05, if index % 2 == 0 then dim else color, GZ + index * 2)
	end
	return out
end

-- 조합(Brew): 목이 긴 플라스크 + 안의 액체와 기포.
local function brew(color: Color3, dim: Color3, rest: (number) -> number): { Shape }
	local out: { Shape } = {}
	local bubble = 0.07 + rest(1) * 0.04

	paint(out, 0.5, 0.66, 0.6, 0.58, 0, color, 0.5, GZ)
	paint(out, 0.5, 0.38, 0.44, 0.44, 45, color, 0.05, GZ)
	paint(out, 0.5, 0.17, 0.19, 0.26, 0, color, 0.2, GZ + 1)
	paint(out, 0.5, 0.07, 0.29, 0.1, 0, dim, 0.3, GZ + 2)
	paint(out, 0.5, 0.76, 0.48, 0.3, 0, dim, 0.35, GZ + 4)
	paint(out, 0.39, 0.6, bubble, bubble, 0, color, 0.5, GZ + 5)
	paint(out, 0.61, 0.53, bubble * 0.7, bubble * 0.7, 0, color, 0.5, GZ + 5)
	return out
end

-- 축조(Construct): 엇갈려 쌓은 벽돌 + 갓돌.
local function construct(color: Color3, dim: Color3, rest: (number) -> number): { Shape }
	local out: { Shape } = {}
	local shift = rest(1) * 0.06

	for row = 0, 2 do
		local y = 0.34 + row * 0.22
		local offset = if row % 2 == 0 then 0 else 0.16
		for index = -1, 1 do
			local tone = if row == 1 then color else dim
			paint(out, 0.5 + index * 0.32 + offset - shift, y, 0.29, 0.2, 0, tone, 0.05, GZ + row)
		end
	end
	paint(out, 0.5, 0.15, 0.86, 0.11, 0, color, 0.1, GZ + 4)
	return out
end

--=== 태그 → 문양·색 ===--

type Family = { Glyph: Glyph, Base: Palette }

local BLADE_COLOR = rgb(226, 232, 240)
local IRON_COLOR = rgb(150, 172, 196)
local EMBER_COLOR = rgb(255, 138, 62)
local BLOOD_COLOR = rgb(214, 66, 82)
local LEAF_COLOR = rgb(126, 206, 132)
local ARCANE_COLOR = rgb(158, 128, 246)
local GOLD_COLOR = rgb(238, 190, 84)
local SHADE_COLOR = rgb(126, 118, 168)
local AQUA_COLOR = rgb(96, 198, 214)
local ROSE_COLOR = rgb(232, 132, 176)

--[[
	태그 32개를 문양에 붙인다. **1대1이다.**

	예전에는 40개 태그가 14개 문양을 나눠 썼다. 같은 축이면 같은 그림이라는 규칙은
	말은 되지만, 실제로 쓰이는 태그는 32개뿐이고 그중 서로 다른 직업의 카드가
	같은 그림으로 나오는 일이 잦았다(예: `Brink`·`Sacrifice`가 둘 다 물약병).
	그림의 목적은 축 분류가 아니라 **카드 구분**이므로 전부 갈랐다.

	색(`Base`)은 이제 두 번째 태그 부호에만 쓴다 — 바탕은 등급색 고정이다.
]]
local FAMILIES: { [string]: Family } = {
	-- 방어
	Guard = { Glyph = shield, Base = IRON_COLOR },
	Aegis = { Glyph = aegis, Base = AQUA_COLOR },
	Ward = { Glyph = ward, Base = ARCANE_COLOR },
	Plating = { Glyph = plating, Base = GOLD_COLOR },
	Endure = { Glyph = endure, Base = LEAF_COLOR },
	Vanguard = { Glyph = vanguard, Base = BLADE_COLOR },
	Anchor = { Glyph = anchor, Base = IRON_COLOR },
	Taunt = { Glyph = taunt, Base = EMBER_COLOR },

	-- 근접
	Precision = { Glyph = precision, Base = BLADE_COLOR },
	Execute = { Glyph = execute, Base = BLOOD_COLOR },
	Riposte = { Glyph = riposte, Base = AQUA_COLOR },
	Judgment = { Glyph = judgment, Base = GOLD_COLOR },
	Solo = { Glyph = solo, Base = ROSE_COLOR },

	-- 불·분노
	Burn = { Glyph = burn, Base = EMBER_COLOR },
	Rage = { Glyph = rage, Base = BLOOD_COLOR },
	Frenzy = { Glyph = frenzy, Base = ROSE_COLOR },
	Catalyst = { Glyph = catalyst, Base = GOLD_COLOR },
	Overload = { Glyph = overload, Base = ARCANE_COLOR },

	-- 피·희생
	Blood = { Glyph = blood, Base = BLOOD_COLOR },
	Brink = { Glyph = brink, Base = SHADE_COLOR },
	Sacrifice = { Glyph = sacrifice, Base = ROSE_COLOR },

	-- 원거리
	Volley = { Glyph = volley, Base = GOLD_COLOR },
	Mark = { Glyph = mark, Base = BLOOD_COLOR },
	Spread = { Glyph = spread, Base = EMBER_COLOR },
	Charge = { Glyph = charge, Base = ARCANE_COLOR },

	-- 신앙
	Faith = { Glyph = faith, Base = GOLD_COLOR },

	-- 음악
	Melody = { Glyph = melody, Base = ROSE_COLOR },
	Chorus = { Glyph = chorus, Base = GOLD_COLOR },
	Tempo = { Glyph = tempo, Base = AQUA_COLOR },

	-- 연쇄·제작
	Chain = { Glyph = chain, Base = ARCANE_COLOR },
	Brew = { Glyph = brew, Base = LEAF_COLOR },
	Construct = { Glyph = construct, Base = IRON_COLOR },
}

local FALLBACK: Family = { Glyph = ward, Base = IRON_COLOR }

--=== 손으로 고친 도형 ===--

--[[
	**도형 하나하나의 값을 덮어쓰는 표** (요청: "벡터 위치도 직접 바꿀 수 있게").

	문양은 절차적으로 그려진다 — 반복문과 카드별 변주가 섞여 있어서 좌표를 통째로
	데이터로 빼면 그 변주가 죽는다. 그래서 **그린 뒤에 덮어쓰는** 층을 하나 둔다.
	적어 넣은 값만 바뀌고, 적지 않은 값은 그대로 절차적으로 남는다.

	  [태그] = { [도형번호] = { X = 0.42, Rotation = -20 } }

	도형 번호는 그 문양이 내놓는 순서다. `config_editor.html`의 아이콘 탭이 번호를
	보여주고, 값을 고치면 `apply_config_edits.luau`가 이 표에 적는다.

	좌표는 **메달리온에 넣기 전** 문양 자신의 0~1 좌표다.
]]
export type ShapeOverride = {
	X: number?,
	Y: number?,
	W: number?,
	H: number?,
	Rotation: number?,
}

local SHAPE_OVERRIDES: { [string]: { [number]: ShapeOverride } } = {}

--[[
	그림자를 함께 옮긴다.

	`paint`는 획 하나를 **그림자 + 본체** 두 겹으로 찍는다. 본체만 옮기면 그림자가
	제자리에 남아 획이 두 개로 보인다. 앞 도형이 이 도형의 그림자인지(같은 크기·각도에
	Y만 SHADOW_DROP만큼 아래) 보고, 맞으면 같은 값을 먹인다.
]]
local function isShadowOf(shadow: Shape, body: Shape): boolean
	return math.abs(shadow.W - body.W) < 1e-6
		and math.abs(shadow.H - body.H) < 1e-6
		and math.abs(shadow.Rotation - body.Rotation) < 1e-6
		and math.abs((shadow.Y - body.Y) - SHADOW_DROP) < 1e-6
end

local function applyOverride(item: Shape, patch: ShapeOverride)
	item.X = patch.X or item.X
	item.Y = patch.Y or item.Y
	item.W = patch.W or item.W
	item.H = patch.H or item.H
	item.Rotation = patch.Rotation or item.Rotation
end

--[[
	문양의 도형 목록. **덮어쓴 값이 이미 반영되어 있다.**

	`CardArt.For`가 쓰고, 편집기가 번호를 매겨 보여주는 것도 이 목록이다.
	둘이 같은 함수를 봐야 편집기에서 3번이라고 적힌 것이 게임에서도 3번이다.
]]
function CardArt.Glyph(tag: string, color: Color3, dim: Color3, rest: (number) -> number): { Shape }
	local family = FAMILIES[tag] or FALLBACK
	local shapes = family.Glyph(color, dim, rest)

	for index, patch in SHAPE_OVERRIDES[tag] or {} do
		local item = shapes[index]
		if item then
			--[[
				그림자 판정은 **본체를 고치기 전에** 한다. 먼저 고치면 크기와 각도가
				이미 달라져 있어 짝을 못 알아본다(실제로 한 번 밟았다).
			]]
			local ahead = shapes[index - 1]
			local hasShadow = ahead ~= nil and isShadowOf(ahead :: Shape, item)

			applyOverride(item, patch)
			if hasShadow and ahead then
				applyOverride(ahead, patch)
				ahead.Y += SHADOW_DROP
			end
		end
	end

	return shapes
end

--=== 등급 ===--

type GradeStyle = {
	--[[
		바탕색. **등급마다 고정이다** (요청).
		  일반  회색
		  희귀  파란색
		  필수  보라색
	]]
	Backdrop: Palette,
	-- 메달리온 테두리 링 개수. 등급이 높을수록 겹이 많다.
	Rims: number,
	-- 메달리온 뒤로 뻗는 살 개수. 필수만 쓴다.
	Spokes: number,
	-- 네 귀퉁이 보석. 필수만 쓴다.
	Gems: boolean,
}

--[[
	등급별 고정 색 (요청).

	예전에는 태그 계열 색에서 바탕까지 뽑아 카드마다 바탕색이 달랐다. 그래서
	등급이 색으로 읽히지 않았다 — 파란 바탕이 희귀인지 물 계열 일반인지 알 수 없었다.
	이제 **바탕은 등급만, 문양은 흰색으로 고정**하고, 태그 색은 작은 부호에만 남긴다.
]]
local GRADES: { [string]: GradeStyle } = {
	Common = { Backdrop = rgb(78, 80, 88), Rims = 1, Spokes = 0, Gems = false },
	Rare = { Backdrop = rgb(38, 74, 150), Rims = 2, Spokes = 0, Gems = false },
	Essential = { Backdrop = rgb(96, 52, 154), Rims = 2, Spokes = 8, Gems = true },
}

-- 문양은 등급과 무관하게 흰색이다(요청: "흰 아이콘").
local GLYPH_COLOR = rgb(255, 255, 255)

-- 메달리온 지름. 문양이 이 안에 들어앉는다.
local MEDALLION = 0.78

-- 문양을 메달리온 안으로 줄여 넣는 비율. 편집기가 같은 값을 써야 미리보기가 맞는다.
CardArt.INSET = MEDALLION * 0.94

--[[
	카드 하나의 그림을 만든다.

	card는 `AbilityCard`면 되지만, 필드 세 개(Id · Grade · Tags)만 본다. 보유 카드
	목록처럼 설명 없이 요약만 들고 있는 표에도 그대로 쓸 수 있게 하려는 것이다.
]]
function CardArt.For(card: { Id: string, Grade: string, Tags: { string }?, Art: string? }): Art
	local seed = hash(card.Id or "")
	local function rest(stream: number): number
		return unit(seed, stream)
	end

	local tags = card.Tags or {}
	local grade = GRADES[card.Grade] or GRADES.Common

	--[[
		바탕은 등급색, 문양은 흰색으로 고정한다(요청).

		태그 색(`family.Base`)은 이제 **두 번째 태그 부호에만** 쓴다. 바탕까지 태그
		색으로 칠하면 등급이 색으로 읽히지 않는다.
	]]
	local backdrop = toColor(grade.Backdrop, 1)
	local accent = toColor(GLYPH_COLOR, 1)
	-- 문양의 어두운 부분. 흰색을 그대로 낮춰 회색으로 쓴다.
	local dim = toColor(GLYPH_COLOR, 0.7)

	local shapes: { Shape } = {}

	--[[
		**메달리온 액자.**

		예전에는 대각선 띠 네 줄과 네 귀퉁이 `+` 표식이 카드 전면에 깔려 있었다.
		그게 문양과 같은 흰색이라 무엇이 주인공인지 흐려지고 "미완성" 느낌을 줬다.

		이제 가운데 원판 하나로 시선을 모은다. 잠재력 노드 계열 아이콘이 공통으로
		쓰는 문법이다 — 어두운 원판 + 밝은 테두리 + 그 안에 굵은 실루엣.
	]]

	-- 필수 카드의 살. 메달리온 **뒤에서** 뻗는다.
	for index = 1, grade.Spokes do
		table.insert(shapes, shape(0.5, 0.5, 0.05, 1.16, (index / grade.Spokes) * 180, accent, 0.5, 0, 1, 0.78))
	end

	-- 원판. 바탕 등급색을 어둡게 눌러 문양이 뜨게 한다.
	table.insert(shapes, shape(0.5, 0.5, MEDALLION + 0.06, MEDALLION + 0.06, 0, accent, 0.5, 0, 2, 0.72))
	table.insert(shapes, shape(0.5, 0.5, MEDALLION, MEDALLION, 0, toColor(grade.Backdrop, 0.55), 0.5, 0, 3))

	-- 테두리 링. 등급이 높을수록 한 겹 더 두른다.
	for index = 1, grade.Rims do
		local size = MEDALLION + 0.02 - (index - 1) * 0.12
		table.insert(shapes, shape(0.5, 0.5, size, size, 0, accent, 0.5, 0.022, 4, if index == 1 then 0 else 0.55))
	end

	--[[
		문양. 메달리온 안에 앉는다.

		`Glyph`는 0~1 좌표로 그리므로 그대로 쓰면 원판을 넘친다. 메달리온 비율만큼
		가운데로 줄여 넣는다 — 그래야 어떤 문양이든 액자 안에 담긴다.
	]]
	--[[
		**손으로 그린 그림이 있으면 그것을 쓴다** (요청).

		`Art`가 가리키는 그림이 태그 문양을 대신한다. 가리키지 않은 카드는 예전처럼
		태그로 그려지므로, 306장을 다 그려 넣지 않아도 게임이 돌아간다.
		액자와 바탕은 어느 쪽이든 등급이 정한다 — 그림은 안쪽만 채운다.
	]]
	local inset = CardArt.INSET
	local drawn: { Shape }
	local artwork = if card.Art then CardArtworks.Get(card.Art) else nil
	if artwork then
		drawn = {}
		for _, item in artwork.Shapes do
			table.insert(
				drawn,
				shape(
					item.X,
					item.Y,
					item.W,
					item.H,
					item.Rotation,
					fromHex(item.Color),
					item.Corner,
					item.Stroke,
					item.ZIndex,
					item.Transparency
				)
			)
		end
	else
		drawn = CardArt.Glyph(tags[1] or "", accent, dim, rest)
	end

	for _, item in drawn do
		item.X = 0.5 + (item.X - 0.5) * inset
		item.Y = 0.5 + (item.Y - 0.5) * inset
		item.W *= inset
		item.H *= inset
		if item.Stroke > 0 then
			item.Stroke *= inset
		end
		table.insert(shapes, item)
	end

	--[[
		두 번째 태그가 있으면 작은 보석으로 오른쪽 아래에 얹는다.
		"[Blood, Rage]"처럼 두 축에 걸친 카드를 그림만으로 알아볼 수 있게 한다.
		메달리온 바깥 테두리에 걸쳐 두어 문양을 가리지 않는다.
	]]
	local second = FAMILIES[tags[2] or ""]
	if second then
		local tone = toColor(second.Base, 1)
		table.insert(shapes, shape(0.855, 0.845, 0.2, 0.2, 45, accent, 0.06, 0, 20))
		table.insert(shapes, shape(0.855, 0.845, 0.15, 0.15, 45, tone, 0.05, 0, 21))
	end

	-- 필수 카드의 귀퉁이 보석. 액자를 고정하는 못처럼 보이게 둔다.
	if grade.Gems then
		for _, spot in { { 0.115, 0.115 }, { 0.885, 0.115 }, { 0.115, 0.885 } } do
			table.insert(shapes, shape(spot[1], spot[2], 0.1, 0.1, 45, accent, 0.04, 0, 20, 0.25))
			table.insert(shapes, shape(spot[1], spot[2], 0.05, 0.05, 45, accent, 0.04, 0, 21))
		end
	end

	return {
		Background = backdrop,
		Accent = accent,
		Shapes = shapes,
	}
end

-- 태그가 문양에 붙어 있는지. 새 태그를 만들고 매핑을 잊는 것을 테스트로 잡는다.
function CardArt.HasFamily(tag: string): boolean
	return FAMILIES[tag] ~= nil
end

--[[
	문양이 붙어 있는 태그 전부. 이름순이다.

	테스트가 **태그마다 그림이 다른지**를 보려면 목록이 필요하다. 예전에는 여러
	태그가 한 문양을 나눠 써서 서로 다른 직업의 카드가 같아 보였고, 그걸 잡을
	수단이 없었다.
]]
function CardArt.Tags(): { string }
	local names: { string } = {}
	for tag in FAMILIES do
		table.insert(names, tag)
	end
	table.sort(names)
	return names
end

return CardArt
