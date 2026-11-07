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
				Description = "스킬에 두 번 맞을 때마다 무작위 [음표] 1개를 얻는다.",
			},
			{
				Id = "Musician_Refrain",
				Name = "후렴",
				Description = "[음표]를 4개 얻을 때마다 최대 체력의 2.5%를 회복한다.\n"
					.. "기본 회복량으로 취급해 [주는 회복량]·[받는 회복량]의 영향을 받는다.",
			},
			{
				Id = "Musician_Downbeat",
				Name = "첫 박",
				Description = "전투 시작 시 [박자표] 1과 4분음표 2개를 얻는다.",
			},
		},
	},

	Duelist = {
		ClassId = "Duelist",
		StatusKeywords = { "Focus", "AttackStance", "DefenseStance" },
		Passives = {
			{
				Id = "Duelist_Prep",
				Name = "네 번의 준비, 한 번의 반격",
				Description = "- 공격을 받은 스킬이 누적 4번째일 때마다 그 스킬을 반드시 패링한다.\n"
					.. "  - 스킬 하나는 몇 번을 때려도 한 번으로 센다.\n"
					.. "  - 궁극기·패링 불가 스킬은 패링하지 않는다.\n"
					.. "- 이 패링에 성공하면 [집중] 1 획득",
			},
			{
				Id = "Duelist_Read",
				Name = "간파",
				Description = "- 막기의 [받는 피해량] 감소 효과가 절반이 된다.\n"
					.. "- 패링 실패 1개를 성공으로 본다.",
			},
			{
				Id = "Duelist_Situation",
				Name = "전황 파악",
				Description = "- 적 1기마다 [받는 피해량] −5%\n"
					.. "- 적이 5기에서 하나 줄 때마다 [가하는 피해량] +5%\n"
					.. "  - 적 수가 바뀌면 다시 계산한다.",
			},
			{
				Id = "Duelist_Pain",
				Name = "아픈 곳 또 때리기",
				Description = "- 공격 태세일 때 치명타를 내면 [집중] 1 획득",
			},
			{
				Id = "Duelist_Guard",
				Name = "맨 앞에서 긁기",
				Description = "- 방어 태세일 때 최대 체력 +100\n"
					.. "- 방어 태세에서 전열에 있으면 매 턴 [도발] 2 획득\n"
					.. "- 공격 태세가 되면 두 효과 모두 사라진다.",
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
				Description = "체력이 조금이라도 줄어들면 이유를 가리지 않고 [분노] 1을 얻는다.",
			},
			{
				Id = "Berserker_Thickening",
				Name = "광기",
				Description = "- 잃은 체력 10%당 [가하는 피해량] +5%(최대 +45%)\n"
					.. "- 현재 체력이 1% 이하면 대신 [가하는 피해량] +50%",
			},
			{
				Id = "Berserker_Bloodlust",
				Name = "격분",
				Description = "[분노]가 8스택이면 [치명타 확률] +15%",
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
				Description = "맞거나 공격할 때마다 그 수치의 10%만큼 [질량]을 얻는다(한 번에 최대 2).",
			},
			{
				Id = "Quasar_Supermassive",
				Name = "초대질량",
				Description = "- 맞을 때마다 20% 확률로 [받는 피해량] −50%\n"
					.. "  - 곱해서 적용되며, 최종 [받는 피해량]이 줄어든다.",
			},
			{
				Id = "Quasar_LoneLight",
				Name = "고독한 빛",
				Description = "자신 말고 살아 있는 아군이 없으면, 그 전투 동안 [가하는 피해량] +25%, [질량] 획득량 +100%",
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
				Description = "전투 시작 시 아군 전체에게 [가하는 피해량] +10%를 2턴 동안 부여한다.",
			},
			{
				Id = "Pulsar_Neutron",
				Name = "중성자",
				Description = "매 턴 갱신되는 [도발] 3을 얻는다.",
			},
			{
				Id = "Pulsar_Spin",
				Name = "자전",
				Description = "[자기장]이 있으면 매 턴 스테미나를 4 더 얻는다.",
			},
		},
	},

	WallPilgrim = {
		ClassId = "WallPilgrim",
		StatusKeywords = { "Zeal", "Brand", "Tetanus", "Shock", "Spasm" },
		Passives = {
			{
				Id = "WallPilgrim_Road",
				Name = "순례길",
				Description = "같은 행에 월 필그림스 소속 아군이 있으면 그 아군의 신앙심이 8 오른다.",
			},
			{
				Id = "WallPilgrim_Sigil",
				Name = "각인",
				Description = "[광신]이 10 이상 쌓인 적에게 [낙인]을 부여한다.",
			},
			{
				Id = "WallPilgrim_NailMark",
				Name = "못 자국",
				Description = "[광신]이 걸린 적을 처치하면, 그 턴 동안 [광신]이 가장 가까운 다른 적에게 그대로 옮겨 간다.",
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
				Description = "같은 행에 월 필그림스 소속 아군이 있으면 그 아군의 신앙심이 8 오른다.",
			},
			{
				Id = "WallMason_Stacking",
				Name = "쌓기",
				Description = "턴이 끝날 때 [벽]을 가진 아군이 있으면 자신의 [벽]이 1 늘어난다.",
			},
			{
				Id = "WallMason_Brace",
				Name = "버팀목",
				Description = "[벽]이 5스택 이상인 아군은 치명타 피해를 받지 않는다.",
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
				Description = "- 잃은 체력 2%당 [가하는 피해량] +1%\n"
					.. "  - 최대 +48%\n"
					.. "  - 체력이 1% 이하면 대신 +50%",
			},
			{
				Id = "WallBreaker_Road",
				Name = "순례길",
				Description = "같은 행에 월 필그림스 소속 아군이 있으면 그 아군의 신앙심이 8 오른다.",
			},
			{
				Id = "WallBreaker_Debris",
				Name = "잔해",
				Description = "[허물 벽]을 소모한 스킬로 적을 처치하면 소모한 [허물 벽]의 50%를 돌려받는다.",
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
				Description = "- 자신이 건 [화상]은 대상의 화염 경감을 30%만큼 무시한다(더하기).\n"
					.. "  - 다른 아군이 건 [화상]도 자신이 다시 걸면 자신의 것이 된다.",
			},
			{
				Id = "Alchemist_BrokenBottle",
				Name = "깨진 병",
				Description = "- `던지기`를 쓸 때마다 [깨진 병] 1 획득(최대 8)\n"
					.. "  - 스택 1당 [가하는 피해량] +3%",
			},
			{
				Id = "Alchemist_Insurance",
				Name = "보험",
				Description = "- 체력이 5% 이하로 떨어지면 [회복 병] 1을 소모해 체력 30% 회복",
			},
			{
				Id = "Alchemist_BulkUp",
				Name = "벌크업",
				Description = "- `섞기`를 쓸 때마다 [가하는 피해량] +5%, [받는 피해량] +5%\n"
					.. "  - 최대 5스택",
			},
			{
				Id = "Alchemist_SideEffect",
				Name = "부작용",
				Description = "- `중독`을 쓸 때마다 [받는 피해량] +10%\n"
					.. "  - 상한 없음",
			},
		},
	},

	--[[
		조율자(조건부 획득, 2026-10-25 원안). 패시브가 넷 — 스킬 셋과 합쳐 북두칠성 일곱 별이라 규격(셋)보다 하나 많다.
		별마다 [칠성]을 `셉텐트리오네스` 전까지 한 번 준다.
	]]
	Attuner = {
		ClassId = "Attuner",
		StatusKeywords = { "Star", "Melt", "Fusion", "Bind" },
		Passives = {
			{
				Id = "Attuner_Alkaid",
				Name = "알카이드",
				Description = "- 자신과 행 또는 열이 같은 모든 아군의 [가하는 피해량] +50%.\n"
					.. "- 그런 아군이 없으면 [칠성] 1 획득(`셉텐트리오네스` 전까지 이 효과로 1번).\n"
					.. "- 이 직업은 `신앙심` 스탯 말고는 [가하는 피해량]을 올릴 수 없다.\n"
					.. "  - 신앙심 1당 [가하는 피해량] +2%.",
			},
			{
				Id = "Attuner_Mizar",
				Name = "미자르",
				Description = "- 턴 시작 시 자신을 포함한 무작위 아군 하나를 지정 → [묶임] 1, [보호막] 49, [가하는 피해량] +50%.\n"
					.. "  - [묶임]은 한 번 묶이면 그 뒤 2턴 동안 다시 걸리지 않는다(디버그 검수 묶임과 같은 규칙).\n"
					.. "- 3턴 동안 자신을 지정하지 않았으면 3턴째엔 반드시 자신을 지정.\n"
					.. "- 자신을 지정하면 [칠성] 1 획득(`셉텐트리오네스` 전까지 이 효과로 1번).",
			},
			{
				Id = "Attuner_Phecda",
				Name = "페크다",
				Description = "- 자신을 포함한 모든 아군에게 자동 회피 확률 20%.\n"
					.. "- 자동 회피로 피한 아군이 있으면 [칠성] 1 획득(`셉텐트리오네스` 전까지 이 효과로 1번).",
			},
			{
				Id = "Attuner_Dubhe",
				Name = "두베",
				Description = "- 턴 시작 시 자신을 포함한 모든 아군에게 [보호막] 7.\n"
					.. "- 아군 중 한 명이라도 14 이상의 피해를 받으면 [칠성] 1 획득(`셉텐트리오네스` 전까지 이 효과로 1번).",
			},
		},
	},

	-- 청의 검사(조건부 획득). 원안의 패시브 둘 그대로(규격 셋보다 하나 적다).
	AzureBlade = {
		ClassId = "AzureBlade",
		StatusKeywords = { "Concentration" },
		Passives = {
			{
				Id = "AzureBlade_Provoke",
				Name = "도발",
				Description = "- 방어와 다른 특별한 스킬 `도발`이 추가된다.\n"
					.. "- `도발`은 자신에게 [집중력]을 준다.",
			},
			{
				Id = "AzureBlade_Focus",
				Name = "집중력",
				Description = "- [집중력]은 몇몇 스킬을 바꾸지만 2턴 뒤 사라진다.\n"
					.. "  - `검집 타격` → `집중 베기`, `발도술의 절정` → `공간의 이해`",
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
