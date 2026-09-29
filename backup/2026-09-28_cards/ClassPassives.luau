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
				Description = "2번 스킬에 피격될 때마다 무작위 [음표]를 1개 얻는다.",
			},
			{
				Id = "Musician_Refrain",
				Name = "후렴",
				Description = "[음표]를 4개 얻을 때마다 최대 체력의 2.5%를 회복한다.",
			},
			{
				Id = "Musician_Downbeat",
				Name = "첫 박",
				Description = "전투 시작 시 [박자표]를 1 얻는다.",
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
				Description = "4번 피격될 때마다 다음 공격을 확정으로 패링한다. 궁극기와 패링 불가 스킬은 빼고 센다.",
			},
			{
				Id = "Duelist_Slip",
				Name = "흘림",
				Description = "방어의 피해 감소가 절반이 된다. 대신 방어 범위 증가가 사라지고 그 3분의 1만큼 [패링 범위]를 얻는다.",
			},
			{
				Id = "Duelist_Count",
				Name = "머릿수 읽기",
				Description = "전투 시작 시 적이 3기 이하면 [가하는 피해량] 증가 5%, 4기 이상이면 [받는 피해량] 감소 5%. 적 수가 바뀌면 다시 판정한다.",
			},
		},
	},

	Berserker = {
		ClassId = "Berserker",
		StatusKeywords = { "Rage" },
		Passives = {
			{
				Id = "Berserker_Fury",
				Name = "핏발",
				Description = "체력을 소모할 때마다 [분노]를 1 얻는다.",
			},
			{
				Id = "Berserker_Thickening",
				Name = "굳는 피",
				Description = "잃은 체력 10%마다 [가하는 피해량] 증가 4%. 최대 20%다.",
			},
			{
				Id = "Berserker_Bloodlust",
				Name = "피에 취함",
				Description = "[분노]가 상한에 닿으면 그 턴 동안 [치명타 확률] 15%를 얻는다.",
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
				Description = "피해를 주거나 받으면 그 양의 10%만큼 [질량]을 얻는다.",
			},
			{
				Id = "Quasar_Supermassive",
				Name = "초대질량",
				Description = "20% 확률로 받는 피해가 절반이 된다.",
			},
			{
				Id = "Quasar_LoneLight",
				Name = "고독한 빛",
				Description = "아군이 모두 쓰러지면 [가하는 피해량] 증가 25%를 영구히 얻고 [질량] 획득량이 2배가 된다.",
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
				Description = "전투 시작 시 아군 전체가 2턴 동안 [가하는 피해량] 증가 10%를 얻는다. 같은 직업이 여럿이어도 겹치지 않는다.",
			},
			{
				Id = "Pulsar_Neutron",
				Name = "중성자",
				Description = "적이 대상을 고를 때 자신이 뽑힐 확률이 30% 오른다.",
			},
			{
				Id = "Pulsar_Spin",
				Name = "자전",
				Description = "[자기장]이 유지되는 동안 매 턴 스테미나를 4 더 회복한다.",
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
				Description = "같은 행에 월 필그림스 아군이 있으면 그 아군의 신앙심이 8 오른다.",
			},
			{
				Id = "WallPilgrim_Sigil",
				Name = "각인",
				Description = "[광신]이 상한에 닿은 적에게 2턴 동안 [낙인]을 남긴다.",
			},
			{
				Id = "WallPilgrim_NailMark",
				Name = "못 자국",
				Description = "[광신]이 걸린 적을 처치하면 남은 중첩이 가장 가까운 적에게 그대로 옮겨간다.",
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
				Description = "같은 행에 월 필그림스 아군이 있으면 그 아군의 신앙심이 8 오른다.",
			},
			{
				Id = "WallMason_Stacking",
				Name = "쌓기",
				Description = "아군이 [벽]을 유지한 채 턴을 마치면 자신이 [벽]을 1중첩 얻는다. 턴당 1회다.",
			},
			{
				Id = "WallMason_Brace",
				Name = "버팀목",
				Description = "[벽]이 상한까지 찬 아군은 치명타를 맞지 않는다.",
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
				Description = "잃은 체력에 비례해 [가하는 피해량] 증가를 얻는다. 최대 20%다.",
			},
			{
				Id = "WallBreaker_Road",
				Name = "순례길",
				Description = "같은 행에 월 필그림스 아군이 있으면 그 아군의 신앙심이 8 오른다.",
			},
			{
				Id = "WallBreaker_Debris",
				Name = "잔해",
				Description = "[허물 벽]을 소모해 적을 처치하면 소모한 중첩의 절반을 돌려받는다.",
			},
		},
	},

	Alchemist = {
		ClassId = "Alchemist",
		StatusKeywords = {
			"Herb",
			"Extract",
			"EmptyBottle",
			"FullBottle",
			"HealBottle",
			"PoisonBottle",
			"FireBottle",
			"OilBottle",
			"Overheal",
		},
		Passives = {
			{
				Id = "Alchemist_Insurance",
				Name = "보험",
				Description = "체력이 5% 이하로 떨어지면 [회복 병]을 1 소모해 체력을 30% 회복한다.",
			},
			{
				Id = "Alchemist_BulkUp",
				Name = "벌크업",
				Description = "`섞기`를 쓸 때마다 [가하는 피해량] 증가 5%와 [받는 피해량] 증가 5%를 얻는다. 최대 5중첩이다.",
			},
			{
				Id = "Alchemist_SideEffect",
				Name = "부작용",
				Description = "`중독`을 쓸 때마다 [받는 피해량] 증가 10%를 얻는다. 최대 5중첩이다.",
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
