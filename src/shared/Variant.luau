--!strict
--[[
	Variant — A/B/C 비교용 변형 스위치. (2026-11-07)
	주관적인 건(색·크기·박자…) 2~3개 안을 같이 만들어 두고, Studio 에서 workspace 속성 하나로 바꿔 가며 고른다.
	속성이 없으면 늘 기본값이라 라이브 서버에서도 안전하다(속성을 넣는 건 Studio 에서뿐).

	  local Variant = require(ReplicatedStorage.Shared.Variant)

	  -- 값 하나: workspace 속성 V_FlashSize(숫자/문자열)가 있으면 그 값, 없으면 기본값
	  local size = Variant.Get("FlashSize", 8)

	  -- 안 고르기: workspace 속성 V_TrailLook = 1 · 2 · 3 (번호). 없거나 범위 밖이면 1번 안
	  local color = Variant.Pick("TrailLook", {
	  	[1] = Color3.fromRGB(255, 200, 80), -- A안(기본)
	  	[2] = Color3.fromRGB(120, 200, 255), -- B안
	  	[3] = Color3.fromRGB(255, 120, 200), -- C안
	  })

	  Variant.Index("TrailLook", 3) -- 번호만 필요하면(안 개수 3)
	보고 정한 뒤엔 Pick 을 지우고 고른 안만 남긴다(속성 이름은 V_ 로 시작).
	같은 안을 한 번만 읽고 싶으면 호출한 결과를 지역 변수에 담아 쓴다(매 프레임 부르지 말 것 — 속성 읽기는 가볍지만 공짜는 아님).
]]

local Variant = {}

local PREFIX = "V_"

-- workspace 속성 V_<name> 의 값(숫자·문자열). 없으면 default
function Variant.Get(name: string, default: any): any
	local value = workspace:GetAttribute(PREFIX .. name)
	if type(value) == "number" or type(value) == "string" then
		return value
	end
	return default
end

-- V_<name> 이 가리키는 안 번호(1~count). 없거나 숫자가 아니거나 범위 밖이면 1
function Variant.Index(name: string, count: number): number
	local value = workspace:GetAttribute(PREFIX .. name)
	if type(value) ~= "number" then
		return 1
	end
	local index = math.floor(value)
	if index < 1 or index > count then
		return 1
	end
	return index
end

-- 안 목록(번호 → 값)에서 V_<name> 번호의 것을 돌려준다. 그 번호 칸이 비었으면 1번 안
function Variant.Pick(name: string, options: { [number]: any }): any
	local count = 0
	for index in options do
		count = math.max(count, index)
	end
	local index = Variant.Index(name, count)
	if options[index] == nil then
		return options[1]
	end
	return options[index]
end

return Variant
