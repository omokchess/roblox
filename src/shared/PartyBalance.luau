--!strict
--[[
	PartyBalance — 파티 전투 코스트 표·역할군·예시 프리셋 (자료만). 2026-11-08.
	사양: 파티전투_사양.md. 이 파일은 **밸런싱 부서 소유**(수치·예시). 규칙 코드는 PartyDefinitions.luau(프로그래밍).

	사용자(2026-11-08): "조율자처럼 OP 반열에 오른 직업이다 -> 4코스트 … 성능은 역할군에 따라서 결정되고,
	해당 역할군을 얼마나 잘 수행하느냐에 따라서 코스트를 다르게 주자." · "예시 프리셋으로 3개정도"

	코스트 정하는 법: 역할군 안에서 "그 역할을 얼마나 잘 하나"로 1~4. 개인 딜만 보지 않고 파티 전체에 주는 값을 본다.
	  4  판을 뒤집는 직업(조율자 — 사용자 지정)
	  3  역할군 최상급(메인 딜러·유리대포·디버퍼 — 파티 딜을 직접 키운다)
	  2  제 몫을 하는 직업(탱커·지원·지속 딜러)
	  1  싸지만 한계가 뚜렷한 직업(도발만 하는 방패·작은 지원·딜이 약한 딜러)
	근거 숫자 출처: tools/damage_sim.luau(카드 없는 단독 전투: 적 셋 14턴 평균 피해·처치 턴·받은 피해, 2026-11-08 측정)
	  와 BattleSkills/ClassPassives/Keywords 의 수치. 시뮬은 단독 전투라 파티의 순서·행 효과는 반영 못 한다 → 근거에 따로 적음.

	파티 전투의 순서(행 y=1→3, 같은 행에선 x=6 뒤열 → x=1 앞열)와 행 공격(자기 행의 적만)이 배치의 핵심이다.
	  - 디버프·버프를 건 유닛은 뒤 순서 유닛보다 먼저 행동해야 이득 → 뒤열(x 큼)·윗행(y 작음)에 둔다.
	  - 가운데 행(y=2)의 유닛은 유도로 위(y=1)·아래(y=3) 어느 쪽 적에게도 닿는다. 윗행(y=1)은 아래 쪽(y=2)까지만,
	    아랫행(y=3)은 위(y=2)까지만 닿는다 → 딜러는 y=2 가 안전하다.
]]

export type PresetUnit = { ClassId: string, X: number, Y: number, Cards: { { CardId: string, Level: number } }, Level: number? }
export type Preset = { Name: string, Note: string?, Units: { PresetUnit } }

local PartyBalance = {}

-- 직업 Id → 코스트(1~4)
PartyBalance.COSTS = {
	Musician = 2,
	Duelist = 2,
	Quasar = 2,
	Pulsar = 1,
	WallPilgrim = 3,
	WallMason = 1,
	WallBreaker = 1,
	Alchemist = 2,
	Berserker = 3,
	Attuner = 4, -- 사용자 지정
	AzureBlade = 3,
} :: { [string]: number }

-- 직업 Id → 역할군(한국어 한 낱말: 딜러·탱커·지원·디버퍼·회복 …)과 그 코스트 근거 한 줄
PartyBalance.ROLES = {
	Attuner = "딜러",
	AzureBlade = "딜러",
	Berserker = "딜러",
	WallPilgrim = "디버퍼",
	Alchemist = "딜러",
	Musician = "지원",
	Duelist = "탱커",
	Quasar = "탱커",
	Pulsar = "탱커",
	WallMason = "지원",
	WallBreaker = "딜러",
} :: { [string]: string }

PartyBalance.REASONS = {
	Attuner = "깡딜러(사용자 2026-11-08 지정). 코스트 4는 사용자 지정. 메그레즈·메라크·알리오스·셉텐트리오네스 모두 대상 [융해] 1당 피해 +15%(최대 +300%)를 받고, 융해를 스킬 시작에 걸어 같은 스킬의 타격이 먹는다(메그레즈 +15%·메라크 +30%·알리오스 +75%·셉텐트리오네스 +75%에 [화상] 몫이 더해짐). 시뮬(tools/attuner_party_sim.luau 슬라임, 단독·카드 없음): 직접 피해 턴당 57 → 98(청의 검사 67·광전사 49), damage_sim 1843 → 2179·처치 5 → 4턴. 미자르·두베·페크다·알카이드 지원은 그대로 남아 딜 4코 값에 지원이 덤으로 붙는다.",
	AzureBlade = "딜러 최상급. 진 발도술 33×1.2 행 전체(재사용 2), 발도술의 절정 48×1.2 최대 4명(재사용 4). 시뮬 턴당 188.6·2턴 처치로 11직업 중 1위. 자기 행만 베므로 행 맞추기가 관건, 방어 수단은 도발 정도.",
	Berserker = "딜러 상급(유리대포). 분쇄 23(분노 4면 3×3)·횡베기 30 3줄·종베기 50, 분노 1당 피해 +10%. 시뮬 턴당 166.6·2턴 처치. 쓸 때마다 체력 3~5를 잃어 받은 피해 368(2위로 많음) — 파티에선 회복이 필요하다.",
	WallPilgrim = "디버퍼 최상급. 못질 26에 광신 3·낙인·파상풍, 합창은 행 전체에 18+광신 4. 광신 1당 받는 피해 +3%·가하는 −2%, 낙인·쇼크가 더해져 뒤 순서 아군 전부의 피해를 키운다. 시뮬 턴당 115.9·4턴 처치·받은 67. 뒤열(x=6) 윗행에 두면 먼저 건다.",
	Alchemist = "딜러 중급. 던지기 40+병 상태이상(독·불·기름)이 핵심이나 재사용 5라 병 수급이 막히면 약하다. 시뮬 턴당 65.4·10턴 처치, 받은 피해 400(최고) — 도핑으로 받는 피해가 오르는 유리대포.",
	Musician = "지원 중급. 브릴란테: 아군 전체 치명 확률·치명 피해 +1.5%×음표(16개면 +24%) 3턴, 재사용 4. 아군이 많을수록 값이 오르는 전체 버프. 개인 딜은 시뮬 턴당 52.4. 윗행 뒤열에 두면 이어지는 딜러 전부가 바로 받는다.",
	Duelist = "탱커 중급. 방어 태세 받는 피해 −55%, 전열 도발 2·체력 +100, 패링 누적 4번째 확정. 시뮬 받은 피해 46으로 11직업 중 최저에 턴당 82.7 딜. 도발로 유도 공격을 받아 내지만 아군 보호 수단은 없다.",
	Quasar = "탱커 중급(딜탱). 체력 140으로 최고, 초대질량 20% 확률 받는 피해 −50%, 질량 20이면 가하는 +20%·받는 −10%, 특이점 3단계 범위. 시뮬 턴당 100.2·4턴 처치·받은 184. 도발 수단이 없어 맞아 줄 자리를 배치로 만들어야 한다.",
	Pulsar = "탱커 하급. 중성자 도발 3 상시, 자기장 받는 피해 −20%+반사 8+감극(받는 피해 +15%, 3스택), 등대로 전원 +10% 2턴. 도발은 11직업 중 최고지만 체력 84·시뮬 턴당 38.0·10턴 처치로 딜이 가장 약해 싸다.",
	WallMason = "지원 하급. 축성: 아군 전체 벽 3(받는 피해 −12%·회피 6%) 재사용 4, 벽은 최대 5스택. 딜이 가장 약해(시뮬 턴당 28.1·11턴 처치) 벽 지원 하나로만 값을 한다. 월 필그림과 같은 행이면 신앙심 +8.",
	WallBreaker = "딜러 하급. 허물 벽 5스택이면 +25%(허물다 26 → ×1.6)이나 허물 벽은 제 살 깎기로 아군 체력을 깎아 얻는다. 시뮬 턴당 48.4·8턴 처치·받은 313. 파티에선 아군에게 피해를 입히는 비용이 있어 싸다.",
} :: { [string]: string }

-- 예시 프리셋 3개(지울 수 없음). Cards 는 AbilityCardDefinitions 의 실제 Id·최대 레벨 안(2026-11-08 lune 으로 검사).
PartyBalance.EXAMPLES = {
	{
		Name = "디버프 폭딜",
		Note = "코스트 8 = 월 필그림 3 + 연금술사 2 + 청의 검사 3. 셋 다 가운데 행(y=2)에 한 줄로 세운다. 순서는 x=6 필그림(광신·낙인·파상풍을 먼저 건다) → x=5 연금술사(병 투척으로 지속 피해) → x=4 청의 검사(진 발도술이 행 전체에 들어간다). 앞 유닛이 건 디버프를 뒤 유닛이 바로 받는 것이 이 편성의 전부다. 방패가 없어 적이 y=2 를 노리면 위험하다. 유도 3개: 적이 y=2 에 없을 때 위 행(y=1)을 먼저 보고 없으면 아래 행(y=3)을 보니, 필그림·연금술사·청의 검사에 하나씩 붙여 셋이 같은 행을 함께 겨누게 한다(가운데 행이라 위·아래 어디든 닿는다).",
		Units = {
			{
				ClassId = "WallPilgrim",
				X = 6,
				Y = 2,
				Level = 15,
				Cards = {
					{ CardId = "WallPilgrim_E_Stigmata", Level = 2 },
					{ CardId = "WallPilgrim_R_Brand", Level = 3 },
					{ CardId = "WallPilgrim_C_FirstNail", Level = 2 },
					{ CardId = "WallPilgrim_C_Whetted", Level = 3 },
					{ CardId = "WallPilgrim_C_Cleave", Level = 2 },
				},
			},
			{
				ClassId = "Alchemist",
				X = 5,
				Y = 2,
				Level = 15,
				Cards = {
					{ CardId = "Alchemist_R_Napalm", Level = 3 },
					{ CardId = "Alchemist_R_Accelerant", Level = 3 },
					{ CardId = "Alchemist_R_Chain", Level = 3 },
					{ CardId = "Alchemist_R_Distill", Level = 2 },
					{ CardId = "Alchemist_C_Splash", Level = 3 },
				},
			},
			{
				ClassId = "AzureBlade",
				X = 4,
				Y = 2,
				Level = 15,
				Cards = {
					{ CardId = "AzureBlade_E_Biased", Level = 1 },
					{ CardId = "AzureBlade_R_SwordWind", Level = 3 },
					{ CardId = "AzureBlade_R_AllOut", Level = 3 },
					{ CardId = "AzureBlade_C_Through", Level = 3 },
					{ CardId = "AzureBlade_C_Point", Level = 3 },
					{ CardId = "AzureBlade_C_Wanderer", Level = 2 },
				},
			},
		},
	},
	{
		Name = "도발 받이",
		Note = "코스트 8 = 음악가 2 + 월 메이슨 1 + 연금술사 2 + 퀘이사 2 + 펄서 1. 앞열(x=1)의 펄서(도발 3·반사)와 퀘이사가 추적 공격을 받아 내고, 월 메이슨의 벽·음악가 보호막·벽 해제 회복(회반죽)으로 버틴다. 윗행(y=1) 뒤열 x=6 음악가가 가장 먼저 행동해 브릴란테를 이어질 모든 유닛에 건다. 연금술사(x=5, y=2)는 지속 피해와 펄서가 감극을 쌓은 적에게 병을 던져 딜을 맡는다. 유도 3개: 연금술사에 둘(y=2 라 위·아래 모두 닿음), 퀘이사에 하나(y=1 이라 아래 행 y=2 까지만). 적이 y=3 에만 있다면 y=2 유닛(메이슨·연금술사·펄서)만 닿으므로 유도를 연금술사·펄서에 몰아 준다. 아랫행 y=3 은 일부러 비워 둔다.",
		Units = {
			{
				ClassId = "Musician",
				X = 6,
				Y = 1,
				Level = 15,
				Cards = {
					{ CardId = "Musician_E_Accompanist", Level = 2 },
					{ CardId = "Musician_R_Sustain", Level = 2 },
					{ CardId = "Musician_R_Tutti", Level = 2 },
					{ CardId = "Musician_C_Prelude", Level = 3 },
					{ CardId = "Musician_C_Refrain", Level = 3 },
					{ CardId = "Musician_C_Eighth", Level = 2 },
				},
			},
			{
				ClassId = "Quasar",
				X = 1,
				Y = 1,
				Level = 15,
				Cards = {
					{ CardId = "Quasar_E_EventHorizon", Level = 1 },
					{ CardId = "Quasar_R_ShoulderIt", Level = 2 },
					{ CardId = "Quasar_R_HighDensity", Level = 3 },
					{ CardId = "Quasar_C_Hull", Level = 3 },
					{ CardId = "Quasar_C_Halo", Level = 2 },
				},
			},
			{
				ClassId = "WallMason",
				X = 6,
				Y = 2,
				Level = 15,
				Cards = {
					{ CardId = "WallMason_E_Cathedral", Level = 1 },
					{ CardId = "WallMason_R_Mortar", Level = 3 },
					{ CardId = "WallMason_R_FinishedWall", Level = 2 },
					{ CardId = "WallMason_C_Footstone", Level = 3 },
					{ CardId = "WallMason_C_Groundwork", Level = 2 },
					{ CardId = "WallMason_C_Cushion", Level = 2 },
				},
			},
			{
				ClassId = "Alchemist",
				X = 5,
				Y = 2,
				Level = 15,
				Cards = {
					{ CardId = "Alchemist_R_Antidote", Level = 1 },
					{ CardId = "Alchemist_R_Accelerant", Level = 3 },
					{ CardId = "Alchemist_R_Napalm", Level = 3 },
					{ CardId = "Alchemist_C_Herbal", Level = 3 },
					{ CardId = "Alchemist_C_Floorstart", Level = 2 },
					{ CardId = "Alchemist_C_Sturdy", Level = 2 },
				},
			},
			{
				ClassId = "Pulsar",
				X = 1,
				Y = 2,
				Level = 15,
				Cards = {
					{ CardId = "Pulsar_R_Beacon", Level = 3 },
					{ CardId = "Pulsar_R_Shroud", Level = 2 },
					{ CardId = "Pulsar_R_Induction", Level = 2 },
					{ CardId = "Pulsar_C_ReflectUp", Level = 3 },
					{ CardId = "Pulsar_C_Magnetize", Level = 2 },
					{ CardId = "Pulsar_C_Attraction", Level = 3 },
				},
			},
		},
	},
	{
		Name = "조율자 중심",
		Note = "코스트 8 = 조율자 4 + 광전사 3 + 펄서 1. 셋 모두 가운데 행(y=2)에 세워 조율자 알카이드(같은 행·열 아군 가하는 피해 +50%)를 전원이 받는다. 순서는 x=6 조율자(미자르 +50%·보호막, 두베 전체 보호막, '지키기 위한 별'로 스킬을 쓸 때마다 전원 회복) → x=3 광전사(체력을 깎는 대신 회복을 받는다) → x=1 펄서(도발 3으로 받아 내고 감극을 건다). 조율자 딜은 줄이고 회복·보호를 키운 대신 광전사의 유리대포를 살리는 구조다. 유도 3개: 적이 y=2 에 없을 때 위 행(y=1)을 먼저 보고 없으면 아래 행(y=3)을 보니, 조율자 하나·광전사 둘(횡베기·종베기가 줄 단위라 맞는 행이 중요)에 준다. 펄서는 맞는 쪽이므로 유도를 받지 않는다. y=1·y=3 은 일부러 비워 놓았다(조율자의 열 보너스는 안 쓴다).",
		Units = {
			{
				ClassId = "Attuner",
				X = 6,
				Y = 2,
				Level = 15,
				Cards = {
					{ CardId = "Attuner_E_GuardStar", Level = 2 },
					{ CardId = "Attuner_R_Binary", Level = 3 },
					{ CardId = "Attuner_R_Polaris", Level = 3 },
					{ CardId = "Attuner_R_Mirage", Level = 3 },
					{ CardId = "Attuner_C_Roof", Level = 3 },
					{ CardId = "Attuner_C_Cluster", Level = 3 },
				},
			},
			{
				ClassId = "Berserker",
				X = 3,
				Y = 2,
				Level = 15,
				Cards = {
					{ CardId = "Berserker_E_Undying", Level = 1 },
					{ CardId = "Berserker_R_Wrath", Level = 2 },
					{ CardId = "Berserker_R_ScentOfBlood", Level = 3 },
					{ CardId = "Berserker_R_Sweep", Level = 3 },
					{ CardId = "Berserker_C_Bite", Level = 3 },
					{ CardId = "Berserker_C_Boiling", Level = 3 },
				},
			},
			{
				ClassId = "Pulsar",
				X = 1,
				Y = 2,
				Level = 15,
				Cards = {
					{ CardId = "Pulsar_R_Beacon", Level = 3 },
					{ CardId = "Pulsar_R_Shroud", Level = 2 },
					{ CardId = "Pulsar_R_Induction", Level = 2 },
					{ CardId = "Pulsar_C_ReflectUp", Level = 3 },
					{ CardId = "Pulsar_C_Magnetize", Level = 2 },
					{ CardId = "Pulsar_C_Attraction", Level = 3 },
				},
			},
		},
	},
} :: { Preset }

return PartyBalance
