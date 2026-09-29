--!strict
--[[
	PulsarCards — 펄서(Pulsar) 능력 카드 34종.

	출처: `유저 아이디어(직업).md` — 필드를 깔고 **적이 자신을 치게 만들어** 대가를 받아내는 섭딜.

	수치 앵커
	  자기장 = 3턴, 받는 피해 −20%, 피격 시 반사 8 + [감극]
	  감극   = 2턴, 최대 3중첩, 중첩 1당 방어 −10% / 받는 피해 +5%
	  공명   = 최대 3스택, 스택 1당 2스킬 피해 +30%
	  수렴 18(3연타 마지막 36)
	  패시브 중성자 = 적이 대상을 고를 때 자신이 뽑힐 확률 +30%

	--------------------------------------------------------------------------
	덱 빌딩 축 네 가지

	  Ward    **필드**. [자기장]을 두르고 맞아 가며 반사한다.
	  Chain   **전이**. [감극]을 쌓고 옮겨 적 쪽 방어를 무너뜨린다.
	  Volley  **연사**. 한 턴에 2스킬을 몇 번 이어 쓰느냐로 화력을 낸다.
	  Aegis   **지원**. 아군에게 버프와 보호를 돌린다.

	축끼리 수치를 더하지 않습니다. **한쪽이 조건을 만들고 다른 쪽이 지불합니다**:
	  Ward가 반사로 맞받으면      → Chain이 그 자리에서 [감극]을 얻는다.
	  Chain이 3중첩을 채우면      → Volley의 발마다 그 적에게 붙는 값이 열린다.
	  Volley가 [공명]을 쌓으면    → Ward의 사거리와 유지가 달라진다(임계 자속).
	  Aegis가 아군을 지키면       → 중성자로 표적이 자신에게 몰려 Ward가 돌아간다.

	그래서 맞아 가며 반사만 해도, 연사에 다 몰아도, 아군을 살리는 쪽으로 가도 굴러갑니다.
]]

local AbilityCardDefinitions = require(script.Parent.Parent.AbilityCardDefinitions)

type Card = AbilityCardDefinitions.AbilityCard

local CLASS_ID = "Pulsar"

local cards: { Card } = {
	--=== 필수 (4) ===--
	{
		Id = "Pulsar_E_ImperfectLight",
		Name = "불완전한 빛",
		Description = "2스킬이 연속 사용 대신 단발이 되고, 피해량이 {3}연타 최대치보다 {15}%씩, 최대 {5}번까지 높아진다. 대신 쓸 때마다 "
			.. "자신에게 명중률 {−10}%가 영구히 쌓인다.",
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Volley" },
	},
	{
		Id = "Pulsar_E_NuclearPasta",
		Name = "핵파스타",
		Description = "1스킬 지속이 {3}턴에서 {2}턴으로 줄어든다. 반사 피해가 {8}에서 {20}으로 오르고 (레벨 2에서 {28}) [감극] 중첩당 "
			.. "수치가 {2}배가 된다.",
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Ward", "Chain" },
	},
	{
		Id = "Pulsar_E_DimSupernova",
		Name = "열화된 초신성",
		Description = "3스킬이 적 전체를 대상으로 하고 명중률 감소가 {−30}%가 된다. 아군 전체에게 피해량 +{15}% 버프를 {2}턴 제공한다.",
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Aegis" },
	},
	{
		Id = "Pulsar_E_Geostationary",
		Name = "정지 궤도",
		Description = "1스킬의 효과가 자신에게는 걸리지 않고, 무작위 아군 하나에게 부여된다. 반사 피해가 {2}배가 되고 재사용 대기가 {3}턴이 된다.",
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Aegis", "Ward" },
	},

	--=== 희귀 (10) ===--
	{
		Id = "Pulsar_R_CriticalFlux",
		Name = "임계 자속",
		Description = "[자기장]이 유지되는 동안 [공명] 상한이 {1} 오르고, [공명]이 상한이면 자기장 지속이 {1}턴 증가한다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Ward", "Volley" },
	},
	{
		Id = "Pulsar_R_Lock",
		Name = "고정 극",
		Description = "3스킬이 적중한 적은 {2}턴 동안 [감극]을 잃지 않는다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Chain", "Aegis" },
	},
	{
		Id = "Pulsar_R_Induction",
		Name = "유도",
		Description = "[자기장]이 유지되는 동안 2스킬이 [감극]을 {1}중첩 더 부여한다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Ward", "Chain" },
	},
	{
		Id = "Pulsar_R_Arc",
		Name = "방전",
		Description = "반사 피해가 인접한 적에게도 절반으로 퍼진다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Chain" },
	},
	{
		Id = "Pulsar_R_Flywheel",
		Name = "플라이휠",
		Description = "[공명]이 턴이 지나도 {1}스택 이하로 떨어지지 않는다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Volley" },
	},
	{
		Id = "Pulsar_R_Beacon",
		Name = "등대 증폭",
		Description = "별들의 등대 버프가 +{10}%에서 +{18}%가 되고 {1}턴 더 유지된다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Aegis" },
	},
	{
		Id = "Pulsar_R_Recharge",
		Name = "재충전",
		Description = "[자기장]이 끝날 때 재사용 대기가 {1}턴 감소한다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Ward" },
	},
	{
		Id = "Pulsar_R_QteMastery",
		Name = "정밀 조율",
		Description = "2스킬 QTE 성공 시, 피해량 증가가 {20}%에서 {35}%가 된다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Volley", "Chain" },
	},
	{
		Id = "Pulsar_R_Grounding",
		Name = "접지",
		Description = "[감극]이 {3}중첩인 적에게 주는 피해량이 {20}% 증가한다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Chain" },
	},
	{
		Id = "Pulsar_R_Shroud",
		Name = "차폐",
		Description = "[자기장]이 유지되는 동안 상태이상에 걸리지 않게 된다. 막을 때마다 자기장 지속이 {1}턴 감소한다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Ward", "Aegis" },
	},

	--=== 일반 (20) ===--
	{
		Id = "Pulsar_C_ReflectUp",
		Name = "반사 강화",
		Description = "1스킬의 반사 피해가 {4} 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Ward" },
	},
	{
		Id = "Pulsar_C_DepolarDamage",
		Name = "감극 활용",
		Description = "[감극] 중첩 {1}당 입히는 피해량이 {3}% 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Chain" },
	},
	{
		Id = "Pulsar_C_Spin",
		Name = "회전",
		Description = "[자기장]이 유지되는 동안 스테미나를 턴당 {3} 더 회복한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Ward" },
	},
	{
		Id = "Pulsar_C_Orbit",
		Name = "궤도",
		Description = "2스킬을 두 번 이상 이어 쓰면, 스테미나 소모가 {20}% 감소한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Volley" },
	},
	{
		Id = "Pulsar_C_Afterglow",
		Name = "잔광",
		Description = "3스킬이 {6}의 피해도 함께 입힌다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Aegis", "Chain" },
	},
	{
		Id = "Pulsar_C_Attraction",
		Name = "인력",
		Description = "중성자의 표적 확률 증가가 {8}% 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Ward", "Aegis" },
	},
	{
		Id = "Pulsar_C_Magnetize",
		Name = "자화",
		Description = "전투 시작 시 [자기장]을 두른다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Ward" },
	},
	{
		Id = "Pulsar_C_Backflow",
		Name = "역류",
		Description = "반사 피해로 적을 처치하면, [공명]을 {1}스택 얻는다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Chain", "Volley" },
	},
	{
		Id = "Pulsar_C_Residue",
		Name = "잔류",
		Description = "[감극] 지속시간이 {1}턴 연장된다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Chain" },
	},
	{
		Id = "Pulsar_C_Focused",
		Name = "집속",
		Description = "2스킬 마지막 발의 피해량이 {10}% 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Volley" },
	},
	{
		Id = "Pulsar_C_GuardLight",
		Name = "수호광",
		Description = "체력이 절반 아래인 아군의 받는 피해량이 {8}% 감소한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Aegis" },
	},
	{
		Id = "Pulsar_C_StaticField",
		Name = "정지장",
		Description = "이동하지 않은 턴에는 반사 피해가 {50}% 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Ward" },
	},
	{
		Id = "Pulsar_C_Afterimage",
		Name = "잔상",
		Description = "3스킬의 명중률 감소가 {5}% 더 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Aegis", "Chain" },
	},
	{
		Id = "Pulsar_C_RecoilControl",
		Name = "반동 제어",
		Description = "2스킬을 {3}회 다 쓰면 다음 턴 받는 피해량이 {12}% 감소한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Volley", "Ward" },
	},
	{
		Id = "Pulsar_C_Relay",
		Name = "중계",
		Description = "[감극]이 걸린 적을 처치하면 남은 중첩이 가장 가까운 적에게 옮겨진다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Chain" },
	},
	{
		Id = "Pulsar_C_LightUp",
		Name = "점등",
		Description = "별들의 등대가 추가로 아군에게 보호막 {6}을 제공한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Aegis" },
	},
	{
		Id = "Pulsar_C_Coil",
		Name = "코일",
		Description = "[공명] {1}스택당 2스킬 사거리가 {1}칸씩, 최대 {2}칸 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Volley" },
	},
	{
		Id = "Pulsar_C_Discharge",
		Name = "방출 조율",
		Description = "[자기장]이 끝날 때 주변 {1}칸에 반사 피해만큼 폭발한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Ward", "Chain" },
	},
	{
		Id = "Pulsar_C_FixedAim",
		Name = "고정 조준",
		Description = "2스킬 첫 발의 QTE 판정 폭이 {15}% 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Volley", "Aegis" },
	},
	{
		Id = "Pulsar_C_Trailing",
		Name = "여광",
		Description = "1스킬이 끝난 다음 턴까지 받는 피해량 감소의 절반이 남는다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Ward" },
	},
}

return {
	ClassId = CLASS_ID,
	Cards = cards,
}
