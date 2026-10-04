--!strict
--[[
	ClassPassives — 직업마다 늘 켜져 있는 **패시브**와, 그 직업의 **전용 상태이상**.

	출처: `유저 아이디어(직업).md` 각 직업의 `## 패시브` · `## 전용 상태이상`

	--------------------------------------------------------------------------
	왜 이제야 데이터가 되나

	패시브는 오래도록 md 문서에만 있었다. 카드 설명이 "벌크업의 피해량 증가가…"
	처럼 패시브 이름을 부르는데, 그 패시브가 무엇인지는 코드 어디에도 없어서
	편집기로 고칠 수도, 게임에서 띄울 수도 없었다.

	--------------------------------------------------------------------------
	전용 상태이상은 **여기 두지 않는다**

	[광신]·[벽]·[질량] 같은 것은 이미 `Keywords`에 이름과 설명이 있고, 상한은
	`ClassResources`가 들고 있다. 여기서 또 적으면 세 곳이 서로 어긋난다.
	대신 `StatusKeywords`로 **가리키기만** 한다 — 편집은 키워드 탭에서 한다.
]]

export type Passive = {
	Id: string,
	Name: string,
	Description: string,
}

export type ClassKit = {
	ClassId: string,
	Passives: { Passive },
	-- 이 직업의 전용 상태이상. `Keywords`의 Id를 가리킨다.
	StatusKeywords: { string },
}

local ClassPassives = {}

local KITS: { [string]: ClassKit } = {
	Musician = {
		ClassId = "Musician",
		StatusKeywords = { "Note", "Meter", "Brillante" },
		Passives = {
			{
				Id = "Musician_Listener",
				Name = "청중",
				Description = "스킬에 두 번 피격될 때마다 무작위 [음표] 1개 얻음.",
			},
			{
				Id = "Musician_Refrain",
				Name = "후렴",
				Description = "[음표]를 4개 얻을 때마다 최대 체력의 2.5% 회복.\n"
					.. "[주는 회복량] 증가와 [받는 회복량] 증가의 영향을 받음.\n"
					.. "기본 회복량으로 취급함.",
			},
			{
				Id = "Musician_Downbeat",
				Name = "첫 박",
				Description = "전투 시작 시 [박자표]를 1 얻음.",
			},
		},
	},

	Duelist = {
		ClassId = "Duelist",
		StatusKeywords = { "Focus", "AttackStance", "DefenseStance" },
		Passives = {
			{
				Id = "Duelist_Read",
				Name = "간파",
				Description = "- 4번 피격될 때마다 다음 공격을 확정으로 패링.\n"
					.. "  - 궁극기·패링 불가 스킬 제외.",
			},
			{
				Id = "Duelist_Slip",
				Name = "흘림",
				Description = "- 방어의 피해 감소 효과가 절반이 됨.\n"
					.. "  - 대신 [회피 시간] +10%.",
			},
			{
				Id = "Duelist_Count",
				Name = "사전 전략",
				Description = "- 전투 시작 시 적이 3기 이하면 [가하는 피해량] +5%, 4기 이상이면 [받는 피해량] −5%.\n"
					.. "  - 전투 중 적 수가 바뀌면 다시 판정.",
			},
		},
	},

	Berserker = {
		ClassId = "Berserker",
		StatusKeywords = { "Rage" },
		Passives = {
			{
				Id = "Berserker_Fury",
				Name = "다혈질",
				Description = "어떤 수단이든 체력이 조금이라도 감소할 경우 [분노]를 1 얻음.",
			},
			{
				Id = "Berserker_Thickening",
				Name = "광기",
				Description = "잃은 체력 10%당 [가하는 피해량] 5% 증가. (최대45%)\n"
					.. "현재 체력이 1% 이하인 경우 대신 [가하는 피해량] 50% 증가.",
			},
			{
				Id = "Berserker_Bloodlust",
				Name = "격분",
				Description = "[분노]가 8스택일 경우 [치명타 확률] 15% 증가.",
			},
		},
	},

	Quasar = {
		ClassId = "Quasar",
		StatusKeywords = { "Mass", "Gravity" },
		Passives = {
			{
				Id = "Quasar_FarLight",
				Name = "아득한 빛",
				Description = "피격 또는 공격 시, 그 수치의 10%만큼 [질량]을 얻음. (한 번에 최대 2)",
			},
			{
				Id = "Quasar_Supermassive",
				Name = "초대질량",
				Description = "매 피격마다 20% 확률로 [받는 피해량]이 50% 감소함.\n"
					.. "- 위 효과는 곱연산으로 계산되며, 최종적으로 들어오는 [받는 피해량]이 감소함.",
			},
			{
				Id = "Quasar_LoneLight",
				Name = "고독한 빛",
				Description = "자신 외 살아있는 아군이 없다면, 그 전투에 한해 [가하는 피해량]이 25% 증가하고, [질량] 획득량이 100% 증가함.",
			},
		},
	},

	Pulsar = {
		ClassId = "Pulsar",
		StatusKeywords = { "Field", "Depolar", "Resonate" },
		Passives = {
			{
				Id = "Pulsar_Beacon",
				Name = "별들의 등대",
				Description = "전투 시작 시, 아군 전체에 [가하는 피해량] 증가 10%를 두 턴 간 부여.",
			},
			{
				Id = "Pulsar_Neutron",
				Name = "중성자",
				Description = "매 턴, 갱신되는 [도발]을 3 얻음.",
			},
			{
				Id = "Pulsar_Spin",
				Name = "자전",
				Description = "[자기장] 보유 시, 매 턴 스테미나를 4 추가 획득함.",
			},
		},
	},

	WallPilgrim = {
		ClassId = "WallPilgrim",
		StatusKeywords = { "Zeal", "Brand" },
		Passives = {
			{
				Id = "WallPilgrim_Road",
				Name = "순례길",
				Description = "같은 행에 월 필그림스 소속 아군이 있다면, 해당 아군의 신앙심 8 증가.",
			},
			{
				Id = "WallPilgrim_Sigil",
				Name = "각인",
				Description = "[광신]이 10 이상 쌓인 적에게 [낙인] 부여.",
			},
			{
				Id = "WallPilgrim_NailMark",
				Name = "못 자국",
				Description = "[광신]을 보유중인 적 처치 시 해당 턴동안 가장 가까운 또다른 적에게 그대로 옮김.",
			},
		},
	},

	WallMason = {
		ClassId = "WallMason",
		StatusKeywords = { "Wall" },
		Passives = {
			{
				Id = "WallMason_Road",
				Name = "순례길",
				Description = "같은 행에 월 필그림스 소속 아군이 있다면, 해당 아군의 신앙심 8 증가.",
			},
			{
				Id = "WallMason_Stacking",
				Name = "쌓기",
				Description = "턴 종료 시 아군이 [벽] 보유 시 자신의 [벽] 수치 1 증가.",
			},
			{
				Id = "WallMason_Brace",
				Name = "버팀목",
				Description = "[벽]이 5스택 이상인 아군은 치명타 피해를 받지 않음.",
			},
		},
	},

	WallBreaker = {
		ClassId = "WallBreaker",
		StatusKeywords = { "Ruin" },
		Passives = {
			{
				Id = "WallBreaker_MadOath",
				Name = "광적인 맹세",
				Description = "- 잃은 체력 2%당 [가하는 피해량] +1%.\n"
					.. "  - 최대 48%.\n"
					.. "  - 체력이 1% 이하인 경우 대신 [가하는 피해량] +50%.",
			},
			{
				Id = "WallBreaker_Road",
				Name = "순례길",
				Description = "같은 행에 월 필그림스 소속 아군이 있다면, 해당 아군의 신앙심 8 증가.",
			},
			{
				Id = "WallBreaker_Debris",
				Name = "잔해",
				Description = "[허물 벽]을 소모한 스킬로 적 처치  시 소모한 [허물 벽]의 50%를 돌려받음.",
			},
		},
	},

	Alchemist = {
		ClassId = "Alchemist",
		StatusKeywords = {
			"Herb",
			"Extract",
			"EmptyBottle",
			"BrokenBottle",
			"FullBottle",
			"HealBottle",
			"PoisonBottle",
			"FireBottle",
			"OilBottle",
			"Overheal",
		},
		Passives = {
			{
				Id = "Alchemist_Toxic",
				Name = "맹독성 물질",
				Description = "- 자신이 건 [화상]은 대상의 경감률을 30%만큼 무시함(합연산).\n  - 다른 아군이 건 [화상]도 자신이 다시 걸면 자신의 것으로 갱신됨.",
			},
			{
				Id = "Alchemist_BrokenBottle",
				Name = "깨진 병",
				Description = "- `던지기` 스킬을 쓸 때마다 [깨진 병] 1 얻음(최대 8).\n"
					.. "  - 수치 1당 [가하는 피해량] +3%.",
			},
			{
				Id = "Alchemist_Insurance",
				Name = "보험",
				Description = "- 체력이 5% 이하로 떨어지면 [회복 병] 1을 소모해 체력 30% 회복.",
			},
			{
				Id = "Alchemist_BulkUp",
				Name = "벌크업",
				Description = "- `섞기` 스킬을 사용할 때마다 가하는 피해량 +5%, 받는 피해량 +5%.\n"
					.. "  - 최대 5중첩.",
			},
			{
				Id = "Alchemist_SideEffect",
				Name = "부작용",
				Description = "- `중독` 스킬을 쓸 때마다 받는 피해량 +10%.\n"
					.. "  - 최대치 없음.",
			},
		},
	},
}

function ClassPassives.Get(classId: string): ClassKit?
	return KITS[classId]
end

function ClassPassives.All(): { ClassKit }
	local list: { ClassKit } = {}
	for _, kit in KITS do
		table.insert(list, kit)
	end
	table.sort(list, function(a, b)
		return a.ClassId < b.ClassId
	end)
	return list
end

-- 패시브 하나를 Id로. 편집기가 고친 값을 되먹일 때 쓴다.
function ClassPassives.Passive(passiveId: string): Passive?
	for _, kit in KITS do
		for _, passive in kit.Passives do
			if passive.Id == passiveId then
				return passive
			end
		end
	end
	return nil
end

return ClassPassives
