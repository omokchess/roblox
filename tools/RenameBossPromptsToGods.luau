--!strict
-- RenameBossPromptsToGods.luau
--
-- 피드백:
--   "각 보스방의 상호작용들을 신들의 이름으로 바꿔줘."
--   "오염지대 보스방이 프리미야 보스전이야."
--   "지하 보스방은 그대로 두고."
--
-- ── 세계관.md 6신 ────────────────────────────────────────────────────────
--   평원 — 프리미야 (여신)    숲 — 엘더 (신)      사막 — 제니스 (여신)
--   늪  — 메리아 (여신)       화산 — 이그너스 (여신)   설원 — 콜 (신)
--   (원래 신은 가이아 하나뿐이었고, 가이아가 자신을 나눠 여섯 신을 만들었다)
--
-- ── 매핑 근거 ────────────────────────────────────────────────────────────
--   오염지대는 "오염된 평원"이므로 평원의 여신 프리미야가 타락한 모습으로 등장한다.
--   따라서 평원 보스방은 프리미야가 아니라 **인간이 만든** 보스방이 되고(별도 작업),
--   프리미야 보스전은 오염지대(부패의 심장)에 배치된다.
--
-- ── 변경 대상 (지상 보스 아레나 5곳) ─────────────────────────────────────
--   Workspace.World.BossArenas.<아레나>.BossSeal.ProximityPrompt
--
--   Boss_고대수신전  숲   → 엘더
--   Boss_부패의심장  오염 → 프리미야 (타락)
--   Boss_용암투기장  화산 → 이그너스
--   Boss_빙결왕좌    설원 → 콜
--   Boss_수몰신전    늪   → 메리아
--
-- ── 손대지 않는 것 ───────────────────────────────────────────────────────
--   ToxicUnderworld.BossSetup   '부패의 태동'  ← 지하 보스방
--   VolcanoUnderworld.BossSetup '화염의 심핵'  ← 지하 보스방
--   VolcanoCore.BossSeal        '화산 광산'    ← 지하 갱도
--   IceCave.BossSeal            '얼음 동굴'    ← 지하 동굴
--
--   Boss_피라미드무덤(사막/제니스)은 현재 ProximityPrompt가 없다.
--   상호작용을 새로 달 때 '사막의 여신 제니스'로 붙일 것.
--
-- 실행: Studio 커맨드 바에 붙여넣고 실행(Run). 결과는 "GOD::" 접두어.

type Entry = { arena: string, action: string, object: string }

local MAPPING: { Entry } = {
	{ arena = "Boss_고대수신전", action = "신에게 도전", object = "숲의 신 엘더" },
	{ arena = "Boss_부패의심장", action = "신에게 도전", object = "타락한 평원의 여신 프리미야" },
	{ arena = "Boss_용암투기장", action = "신에게 도전", object = "화산의 여신 이그너스" },
	{ arena = "Boss_빙결왕좌", action = "신에게 도전", object = "설원의 신 콜" },
	{ arena = "Boss_수몰신전", action = "신에게 도전", object = "늪의 여신 메리아" },
}

local function log(fmt: string, ...): ()
	print("GOD:: " .. string.format(fmt, ...))
end

local arenas = workspace.World:FindFirstChild("BossArenas")
if not arenas then
	log("중단: BossArenas 없음")
	return
end

local changed = 0

for _, entry in ipairs(MAPPING) do
	local arena = arenas:FindFirstChild(entry.arena)
	if not arena then
		log("경고: %s 없음", entry.arena)
		continue
	end

	-- BossSeal 아래 ProximityPrompt를 찾는다 (깊이 무관하게 탐색)
	local prompt: ProximityPrompt? = nil
	for _, descendant in ipairs(arena:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") then
			prompt = descendant
			break
		end
	end

	if prompt then
		local oldAction, oldObject = prompt.ActionText, prompt.ObjectText
		prompt.ActionText = entry.action
		prompt.ObjectText = entry.object
		changed += 1
		log("%s: '%s / %s' → '%s / %s'", entry.arena, oldAction, oldObject, entry.action, entry.object)
	else
		log("경고: %s 에 ProximityPrompt가 없다", entry.arena)
	end
end

log(
	"완료: %d곳 변경. 지하 보스방(부패의 태동/화염의 심핵)과 갱도·동굴은 손대지 않았다.",
	changed
)
