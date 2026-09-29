--!strict
--[[
	MusicianCards — 음악가(Musician) 능력 카드 34종.

	출처: `유저 아이디어(직업).md` — **기준 직업**. 수치 눈금이 여기서 나왔다.

	수치 앵커
	  음표 상한 = 박자표 1→4개, 2→8개, 3→16개
	  브릴란테  = 치명타 확률·피해량 +(1.5 × 값)%
	  벨로체 18 / 크레셴도 26 / 크레셴도 알 포르테 34

	덱 빌딩 축
	  Melody  음표를 모으고 쓰는 축
	  Tempo   박자표·턴 간격 축
	  Chorus  아군에게 버프를 퍼뜨리는 축
	  Solo    버프를 자신에게 몰아 쓰는 축
]]

local AbilityCardDefinitions = require(script.Parent.Parent.AbilityCardDefinitions)

type Card = AbilityCardDefinitions.AbilityCard

local CLASS_ID = "Musician"

local cards: { Card } = {
	--=== 필수 (4) ===--
	{
		Id = "Musician_E_LongBreath",
		Name = "긴 호흡",
		Description = "크레셴도를 쓰지 않은 턴마다 자신이 주는 버프 효과가 {5}%씩, 최대 {40}%까지 증가하며, 크레셴도를 사용하면 초기화된다. "
			.. "아군에게 [브릴란테]효과를 부여할 때마다 체력을 {5}% 회복한다.",
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Tempo", "Chorus", "Solo" },
	},
	{
		Id = "Musician_E_Resonance",
		Name = "공명",
		Description = "음표를 소모할 때마다 아군의 치명타 피해와 자신의 치명타 확률이 {5}%씩 증가한다. 피해는 최대 {30}%, 확률은 {15}%까지 "
			.. "증가한다.",
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Melody", "Chorus" },
	},
	{
		Id = "Musician_E_Accompanist",
		Name = "반주자",
		Description = "딜링 스킬의 기본 피해량이 {60}% 줄어들고 음표와 [브릴란테]의 버프량이 {1.5}배 증가한다.",
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Chorus" },
	},
	{
		Id = "Musician_E_Concertist",
		Name = "협주자",
		Description = "음표와 [브릴란테]의 아군 버프 효과가 삭제되는 대신, 그 전부가 자신에게 {1.5}배 향상된 상태로 적용된다.",
		Grade = "Essential",
		ClassId = CLASS_ID,
		Tags = { "Solo", "Melody" },
	},

	--=== 희귀 (10) ===--
	{
		Id = "Musician_R_Metronome",
		Name = "메트로놈",
		Description = "{3}턴마다 무작위 음표를 {1}개 얻는다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Melody", "Tempo" },
	},
	{
		Id = "Musician_R_Sustain",
		Name = "지속음",
		Description = "[브릴란테]가 {1}턴 더 유지된다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Chorus" },
	},
	{
		Id = "Musician_R_Modulation",
		Name = "전조",
		Description = "박자표를 얻을 때마다, 모든 적에게 소모 음표수x{3}만큼 피해를 입힌다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Tempo", "Melody" },
	},
	{
		Id = "Musician_R_Cadenza",
		Name = "울림",
		Description = "[브릴란테]가 끝난 다음 턴까지 효과의 {20}%가 남는다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Solo", "Melody" },
	},
	{
		Id = "Musician_R_Tutti",
		Name = "투티",
		Description = "아군이 셋 이상 살아 있으면, 음표 획득량이 {1} 증가한다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Chorus", "Melody" },
	},
	{
		Id = "Musician_R_Fermata",
		Name = "페르마타",
		Description = "행동하지 않고 턴을 마치면, 무작위 음표를 {1}개 얻고 [브릴란테] 지속이 {1}턴 늘어난다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Tempo" },
	},
	{
		Id = "Musician_R_Harmonic",
		Name = "배음",
		Description = "16분음표 {1}개당 아군의 치명타 피해량이 {2}% 더 증가한다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Melody", "Chorus" },
	},
	{
		Id = "Musician_R_Ostinato",
		Name = "오스티나토",
		Description = "전투당 {1}회, 같은 스킬을 연속으로 쓰면 그 스킬의 음표를 하나 더 얻는다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Tempo", "Solo" },
	},
	{
		Id = "Musician_R_Overture",
		Name = "자장가",
		Description = "브릴란테를 쓴 턴에 가장 가까운 적의 다음 행동이 한 턴 늦어진다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Tempo" },
	},
	{
		Id = "Musician_R_Descant",
		Name = "데스캉트",
		Description = "[브릴란테]를 받은 아군이 치명타를 내면 턴당 {1}회 음표를 {1}개 얻는다. [브릴란테]를 받은 아군의 치명타 확률이 {3}% "
			.. "증가한다.",
		Grade = "Rare",
		ClassId = CLASS_ID,
		Tags = { "Chorus", "Melody" },
	},

	--=== 일반 (20) ===--
	{
		Id = "Musician_C_HalfSpend",
		Name = "절약",
		Description = "음표를 두 번째로 소모할 때마다 {1}개 덜 소모한다. 크레셴도의 소모한 음표 판정은 받는다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Melody" },
	},
	{
		Id = "Musician_C_BarLine",
		Name = "마디줄",
		Description = "박자표 값이 오를 때마다 아군에게 보호막 {5}를 제공한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Tempo", "Chorus", "Solo" },
	},
	{
		Id = "Musician_C_Prelude",
		Name = "전주",
		Description = "전투당 각 음표들을 처음 얻을 때, 체력을 {2}% 회복한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Melody" },
	},
	{
		Id = "Musician_C_Rest",
		Name = "쉼표",
		Description = "아무 행동도 하지 않고 턴을 넘기면, 스테미나를 {6} 더 회복한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Tempo" },
	},
	{
		Id = "Musician_C_Quarter",
		Name = "4분 강조",
		Description = "4분음표의 스테미나 획득량 증가가 개수당 {0.5}% 더 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Melody", "Chorus" },
	},
	{
		Id = "Musician_C_Eighth",
		Name = "8분 강조",
		Description = "8분음표의 적 스테미나 감소가 개수당 {0.5}%p 더 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Melody" },
	},
	{
		Id = "Musician_C_Sixteenth",
		Name = "16분 강조",
		Description = "16분음표의 치명타 확률 감소가 개수당 {0.2}%p 감소한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Melody", "Solo" },
	},
	{
		Id = "Musician_C_Rosin",
		Name = "송진",
		Description = "벨로체의 보호막 부여량이 {2}에서 {5}로 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Chorus" },
	},
	{
		Id = "Musician_C_Vibrato",
		Name = "비브라토",
		Description = "[브릴란테]를 받은 아군의 회복량이 {15}% 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Chorus" },
	},
	{
		Id = "Musician_C_Staccato",
		Name = "스타카토",
		Description = "음표를 소모한 턴에는 주는 피해량이 {8}% 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Tempo", "Solo" },
	},
	{
		Id = "Musician_C_Bowing",
		Name = "운궁",
		Description = "턴당 {1}회, 평타 사용 후 음표를 {1}개 얻는다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Melody" },
	},
	{
		Id = "Musician_C_Tuning",
		Name = "조율",
		Description = "박자표 값 {1}당 자신이 받는 피해량이 {4}% 감소한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Tempo", "Solo" },
	},
	{
		Id = "Musician_C_Applause",
		Name = "갈채",
		Description = "적을 처치하면 음표를 {1}개 얻는다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Melody", "Solo" },
	},
	{
		Id = "Musician_C_Lullaby",
		Name = "서곡",
		Description = "처음 사용하는 공격 스킬의 피해량이 {10}% 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Chorus", "Tempo" },
	},
	{
		Id = "Musician_C_Score",
		Name = "불협화음",
		Description = "{2}회 이상 다른 스킬을 연달아 사용하면, 그 스킬의 피해량이 {5}% 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Melody" },
	},
	{
		Id = "Musician_C_Echo",
		Name = "카덴차",
		Description = "음표 수가 최대일 때, 자신이 주는 피해량이 {15}% 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Chorus" },
	},
	{
		Id = "Musician_C_Crescendo",
		Name = "아첼레란도",
		Description = "크레셴도의 음표당 피해량 증가가 {0.5}% 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Melody", "Solo" },
	},
	{
		Id = "Musician_C_Encore",
		Name = "앙코르",
		Description = "박자표가 {3}일 때, 자신이 주는 피해량이 {7}% 증가한다..",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Tempo", "Solo" },
	},
	{
		Id = "Musician_C_Chord",
		Name = "화음",
		Description = "둘 이상의 아군에게 [브릴란테]가 있으면, 자신의 평타 또한 [브릴란테] 효과를 일부 받는다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Chorus", "Solo" },
	},
	{
		Id = "Musician_C_Refrain",
		Name = "후렴",
		Description = "음표를 {4}개 얻을 때마다 회복하는 체력이 최대 체력의 {1}% 더 증가한다.",
		Grade = "Common",
		ClassId = CLASS_ID,
		Tags = { "Melody", "Tempo" },
	},
}

return {
	ClassId = CLASS_ID,
	Cards = cards,
}
