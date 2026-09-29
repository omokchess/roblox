--!strict
--[[
	CardAxes — 카드 태그(덱 빌딩 축)의 **이름·색·한 줄 설명**. (2026-09-28)

	카드 파일(AbilityCards/*.luau) 머리 주석에 적혀 있던 직업별 축 네 개를 화면에 쓸 수 있게 옮겼다.
	레벨업 화면이 카드마다 축 칩을 달고, "지금 내 빌드가 어느 축에 몇 장인지"를 세어 보여 준다
	— 고를 때 시너지를 눈으로 따지게 하려는 것(요청: "머리를 많이 써서 플레이할 수 있는 구조").

	같은 영어 태그가 여러 직업에 있다(Brink·Faith). 이름은 같고, 설명은 직업별로 조금 다르다.
]]

export type Axis = { Id: string, Name: string, Color: Color3, Blurb: string }

local function axis(id: string, name: string, color: Color3, blurb: string): Axis
	return { Id = id, Name = name, Color = color, Blurb = blurb }
end

local C = Color3.fromRGB

local BY_CLASS: { [string]: { Axis } } = {
	Musician = {
		axis("Melody", "선율", C(120, 200, 255), "음표를 모으고 쓴다"),
		axis("Tempo", "박자", C(255, 205, 90), "박자표·턴 간격"),
		axis("Chorus", "합창", C(130, 230, 150), "아군에게 버프를 퍼뜨린다"),
		axis("Solo", "독주", C(240, 120, 200), "버프를 자신에게 몰아 쓴다"),
	},
	Duelist = {
		axis("Precision", "정밀", C(120, 200, 255), "[집중]을 벌고 스택을 값으로"),
		axis("Guard", "태세", C(200, 200, 215), "언제 바꾸느냐로 이득"),
		axis("Riposte", "반격", C(255, 205, 90), "막아낸 순간을 자원으로"),
		axis("Execute", "처형", C(235, 90, 90), "[출혈]을 깔고 마무리에서 회수"),
	},
	Quasar = {
		axis("Anchor", "질량", C(170, 140, 255), "[질량]을 벌고 보유량으로"),
		axis("Charge", "당김", C(120, 200, 255), "1스킬을 오래 당겨 [중력]으로"),
		axis("Overload", "방출", C(255, 150, 70), "2스킬 한 방에 몰아넣기"),
		axis("Taunt", "대신 맞기", C(200, 200, 215), "아군 피해를 앞으로 돌린다"),
	},
	Pulsar = {
		axis("Ward", "자장", C(120, 200, 255), "[자기장]을 두르고 반사"),
		axis("Chain", "전이", C(170, 140, 255), "[감극]을 쌓고 옮긴다"),
		axis("Volley", "연사", C(255, 205, 90), "2스킬을 이어 쓴 횟수"),
		axis("Aegis", "수호", C(130, 230, 150), "아군에게 버프·보호"),
	},
	WallPilgrim = {
		axis("Judgment", "심판", C(255, 205, 90), "한 적에게 두껍게 쌓는다"),
		axis("Mark", "낙인", C(235, 90, 90), "[낙인] 찍힌 적을 물고 늘어진다"),
		axis("Spread", "확산", C(130, 230, 150), "중첩을 옮기고 퍼뜨린다"),
		axis("Faith", "신앙", C(240, 235, 200), "기도력 구간이 규칙을 바꾼다"),
	},
	WallMason = {
		axis("Construct", "축조", C(200, 170, 120), "누구에게 얼마나 자주 [벽]을"),
		axis("Plating", "보강", C(120, 200, 255), "중첩 하나의 값을 키운다"),
		axis("Endure", "지속", C(130, 230, 150), "오래 가고, 사라질 때 남긴다"),
		axis("Faith", "신앙", C(240, 235, 200), "기도력 구간이 규칙을 바꾼다"),
	},
	WallBreaker = {
		axis("Vanguard", "돌파", C(255, 150, 70), "쌓아서 3스킬 한 방에"),
		axis("Sacrifice", "희생", C(235, 90, 90), "아군·자신을 쳐서 중첩을 번다"),
		axis("Brink", "벼랑", C(170, 60, 80), "깎인 체력을 자산으로"),
		axis("Faith", "신앙", C(240, 235, 200), "기도력 구간이 규칙을 바꾼다"),
	},
	Alchemist = {
		axis("Brew", "양조", C(130, 230, 150), "병을 만들고 채운다"),
		axis("Catalyst", "촉매", C(170, 140, 255), "섞은 것의 효과를 키운다"),
		axis("Burn", "연소", C(255, 150, 70), "기름·화염으로 태운다"),
		axis("Brink", "벼랑", C(170, 60, 80), "부작용을 감수하고 끌어올린다"),
	},
	Berserker = {
		axis("Rage", "분노", C(235, 90, 90), "[분노]를 모아 한 번에 태운다"),
		axis("Frenzy", "광란", C(255, 150, 70), "한 턴에 더 많이 때린다"),
		axis("Blood", "피", C(170, 40, 60), "체력을 내주고 화력·흡혈"),
		axis("Brink", "벼랑", C(170, 60, 80), "체력이 낮을 때 열린다"),
	},
}

local CardAxes = {}

function CardAxes.ForClass(classId: string): { Axis }
	return BY_CLASS[classId] or {}
end

-- 태그 하나. 직업을 알면 그 직업 설명을, 모르면 처음 찾은 것을.
function CardAxes.Get(tag: string, classId: string?): Axis?
	if classId and BY_CLASS[classId] then
		for _, entry in BY_CLASS[classId] do
			if entry.Id == tag then
				return entry
			end
		end
	end
	for _, list in BY_CLASS do
		for _, entry in list do
			if entry.Id == tag then
				return entry
			end
		end
	end
	return nil
end

return CardAxes
