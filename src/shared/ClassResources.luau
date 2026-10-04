--!strict
--[[
	ClassResources — 직업 자원의 **이름과 상한**.

	사양 출처: `유저 아이디어(직업).md` 각 직업의 `전용 상태이상`

	`BattleStatus`는 "이름 붙은 스택"을 담기만 하고 상한을 모른다. 상한은 직업마다
	다르고(음표는 박자표에 따라 4/8/16, 집중은 10, 질량은 20…) 규격이
	"스택은 반드시 상한이 있을 것"을 요구하므로, 그 값을 여기 한곳에 모아 둔다.

	스킬 효과(`BattleSkillEffects`)가 이 표를 보고 쌓는다. 상한을 바꿀 때 고칠 곳이
	한 군데뿐이도록 하려는 것이다.
]]

local ClassResources = {}

--=== 자원 Id ===--

-- 음악가
ClassResources.QUARTER = "Quarter" -- 4분음표
ClassResources.EIGHTH = "Eighth" -- 8분음표
ClassResources.SIXTEENTH = "Sixteenth" -- 16분음표
ClassResources.METER = "Meter" -- 박자표
ClassResources.BRILLANTE = "Brillante" -- 브릴란테 값

-- 결투사
ClassResources.FOCUS = "Focus" -- 집중
ClassResources.STANCE_ATTACK = "StanceAttack" -- 공격 태세 (1이면 켜짐)
ClassResources.READY = "Ready" -- 준비 자세 (3스킬)

-- 퀘이사
ClassResources.MASS = "Mass" -- 질량
ClassResources.CHARGE = "Charge" -- 붕괴 차징 턴
ClassResources.GRAVITY = "Gravity" -- 중력 (적에게)

-- 펄서
ClassResources.FIELD = "Field" -- 자기장 (남은 턴)
ClassResources.DEPOLAR = "Depolar" -- 감극 (적에게)
ClassResources.RESONATE = "Resonate" -- 공명 (같은 턴 연속 사용)

-- 월 필그림스
ClassResources.ZEAL = "Zeal" -- 광신 (적에게)
ClassResources.WALL = "Wall" -- 벽
ClassResources.RUIN = "Ruin" -- 허물 벽

-- 연금술사
ClassResources.HERB = "Herb" -- 약재
ClassResources.EXTRACT = "Extract" -- 원액
ClassResources.EMPTY_BOTTLE = "EmptyBottle" -- 빈 병
ClassResources.BROKEN_BOTTLE = "BrokenBottle" -- 깨진 병(2026-10-04 리워크 패시브)
ClassResources.POISON_BOTTLE = "PoisonBottle" -- 독 병
ClassResources.FIRE_BOTTLE = "FireBottle" -- 화염병
ClassResources.OIL_BOTTLE = "OilBottle" -- 기름 병
ClassResources.HEAL_BOTTLE = "HealBottle" -- 회복 병(섞기로는 안 나온다 — 호신용 물약·꾸준한 조제. 보험 패시브가 쓴다)
ClassResources.OVERHEAL = "Overheal" -- 과다 회복

-- 광전사
--[[
	[분노]. `유저 아이디어(직업).md`에는 광전사 항목이 없지만(전사 직업은 남겨 둔
	것이라 문서가 없다), 카드 여러 장이 "[분노] 최대 8스택"을 전제로 쓰여 있다.
	카드 효과를 붙이려면 자원이 실재해야 하므로 카드 쪽 수치를 따라 여기 둔다.
]]
ClassResources.RAGE = "Rage"

--=== 상한 ===--

--[[
	상한 표. 음표는 박자표에 따라 달라지므로 여기 없고 `NoteCap`이 계산한다.
]]
local CAPS: { [string]: number } = {
	[ClassResources.METER] = 3, -- 박자표는 1에서 3까지
	[ClassResources.FOCUS] = 10,
	[ClassResources.RAGE] = 8,
	[ClassResources.MASS] = 20,
	[ClassResources.DEPOLAR] = 3,
	[ClassResources.RESONATE] = 3,
	[ClassResources.ZEAL] = 10,
	[ClassResources.WALL] = 5,
	[ClassResources.RUIN] = 5,
	[ClassResources.HERB] = 6,
	[ClassResources.EXTRACT] = 4,
	[ClassResources.EMPTY_BOTTLE] = 8,
	[ClassResources.BROKEN_BOTTLE] = 8,
	[ClassResources.POISON_BOTTLE] = 4,
	[ClassResources.FIRE_BOTTLE] = 4,
	[ClassResources.OIL_BOTTLE] = 4,
	[ClassResources.HEAL_BOTTLE] = 4,
	[ClassResources.OVERHEAL] = 3,
}

function ClassResources.Cap(id: string): number?
	return CAPS[id]
end

--[[
	음표 최대 보유 수. 박자표 값에 비례한다.
	`유저 아이디어(직업).md`: "1일 때는 4개, 2일 때는 8개, 3일 때는 16개"
]]
function ClassResources.NoteCap(meter: number): number
	if meter >= 3 then
		return 16
	elseif meter >= 2 then
		return 8
	end
	return 4
end

--[[
	음표는 종류가 셋이지만 **한 곳에 욱여넣어진다**(md의 `!!` 주석).
	그래서 "총 개수"가 곧 버프 계산의 기준이다.
]]
ClassResources.NOTE_IDS = { ClassResources.QUARTER, ClassResources.EIGHTH, ClassResources.SIXTEENTH }

--=== 사람이 읽는 이름 ===--

local LABELS: { [string]: string } = {
	[ClassResources.QUARTER] = "4분음표",
	[ClassResources.EIGHTH] = "8분음표",
	[ClassResources.SIXTEENTH] = "16분음표",
	[ClassResources.METER] = "박자표",
	[ClassResources.BRILLANTE] = "브릴란테",
	[ClassResources.FOCUS] = "집중",
	[ClassResources.RAGE] = "분노",
	[ClassResources.STANCE_ATTACK] = "공격 태세",
	[ClassResources.READY] = "준비 자세",
	[ClassResources.MASS] = "질량",
	[ClassResources.CHARGE] = "차징",
	[ClassResources.GRAVITY] = "중력",
	[ClassResources.FIELD] = "자기장",
	[ClassResources.DEPOLAR] = "감극",
	[ClassResources.RESONATE] = "공명",
	[ClassResources.ZEAL] = "광신",
	[ClassResources.WALL] = "벽",
	[ClassResources.RUIN] = "허물 벽",
	[ClassResources.HERB] = "약재",
	[ClassResources.EXTRACT] = "원액",
	[ClassResources.EMPTY_BOTTLE] = "빈 병",
	[ClassResources.BROKEN_BOTTLE] = "깨진 병",
	[ClassResources.POISON_BOTTLE] = "독 병",
	[ClassResources.FIRE_BOTTLE] = "화염병",
	[ClassResources.OIL_BOTTLE] = "기름 병",
	[ClassResources.HEAL_BOTTLE] = "회복 병",
	[ClassResources.OVERHEAL] = "과다 회복",
}

function ClassResources.Label(id: string): string
	return LABELS[id] or id
end

-- 직업마다 쓰는 자원(자기에게 쌓이는 것). 디버그 패널이 "자원 주기" 목록으로 쓴다.
local BY_CLASS: { [string]: { string } } = {
	Musician = { ClassResources.QUARTER, ClassResources.EIGHTH, ClassResources.SIXTEENTH, ClassResources.METER, ClassResources.BRILLANTE },
	Duelist = { ClassResources.FOCUS, ClassResources.STANCE_ATTACK, ClassResources.READY },
	Quasar = { ClassResources.MASS, ClassResources.CHARGE },
	Pulsar = { ClassResources.FIELD, ClassResources.RESONATE },
	WallPilgrim = { ClassResources.WALL },
	WallMason = { ClassResources.WALL },
	WallBreaker = { ClassResources.RUIN, ClassResources.WALL },
	Alchemist = {
		ClassResources.HERB,
		ClassResources.EXTRACT,
		ClassResources.EMPTY_BOTTLE,
		ClassResources.BROKEN_BOTTLE,
		ClassResources.POISON_BOTTLE,
		ClassResources.FIRE_BOTTLE,
		ClassResources.OIL_BOTTLE,
		ClassResources.HEAL_BOTTLE,
		ClassResources.OVERHEAL,
	},
	Berserker = { ClassResources.RAGE },
}

function ClassResources.ForClass(classId: string): { string }
	return BY_CLASS[classId] or {}
end

--[[
	전투를 시작할 때 들고 있는 자원. `유저 아이디어(직업).md`의 패시브에서 왔다.

	  음악가   전투 시작 시 박자표를 1 얻는다
	  연금술사 전투 시작 시 약재 3, 빈 병 5
]]
function ClassResources.StartingStacks(classId: string): { [string]: number }
	if classId == "Musician" then
		return { [ClassResources.METER] = 1 }
	elseif classId == "Alchemist" then
		return { [ClassResources.HERB] = 3, [ClassResources.EMPTY_BOTTLE] = 5 }
	end
	return {}
end

--[[
	매 턴 자동으로 차는 자원. 역시 패시브에서 왔다.

	  연금술사 약재는 매 턴 1, 빈 병은 2턴마다 1
]]
function ClassResources.TurnGain(classId: string, turn: number): { [string]: number }
	if classId == "Alchemist" then
		local gain = { [ClassResources.HERB] = 1 }
		if turn % 2 == 0 then
			gain[ClassResources.EMPTY_BOTTLE] = 1
		end
		return gain
	end
	return {}
end

return ClassResources
