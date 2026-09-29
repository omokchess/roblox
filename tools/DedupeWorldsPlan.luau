--!strict
-- DedupeWorldsPlan.luau
--
-- 역할: Workspace에 중복 누적된 World / Town 정리 "계획만" 출력한다. (읽기 전용)
--       이 스크립트는 아무것도 삭제하지 않는다. 무엇을 지울지 목록만 보여준다.
--
-- 근거(2026-07-20 AnalyzeDuplicateWorlds.luau 결과):
--   - World 4개가 바운딩 박스까지 완전히 동일했다.
--     center=(0, 418, 0), size=(8000, 1675, 8000)  ← 같은 자리에 4겹으로 겹쳐 있었음
--     자식 19종 구성도 동일. 차이는 PlainsVillage=1945 / 1947 (2파트) 뿐.
--   - Town 2개도 동일했다. 둘 다 Podium=216, Tower=3677.
--   - World 1개는 Ground(2490)만 가진 고아 지면이었다.
--     → 사용자가 보고한 "이전 왕국 토지 흔적, 땅 높낮이가 다름"의 원인.
--
-- 이 중복이 유발하던 증상:
--   - 피라미드가 겹쳐 보임          (같은 피라미드가 4개 겹침)
--   - 성문 위 돌 반짝임 z-fighting  (동일 벽이 같은 높이에 4장)
--   - 탑에 붙은 잔재                 (겹친 사본의 구조물)
--   - 평원의 옛 지형 흔적            (고아 Ground 레이어)
--
-- 정리 정책:
--   1) 완전한 World(자식 10개 이상) 중 descendant 수가 가장 많은 것 1개만 남긴다.
--      → PlainsVillage=1947 쪽(d=42823)이 선택된다.
--   2) 나머지 완전한 World는 모두 삭제 대상.
--   3) Ground만 가진 고아 World는 모두 삭제 대상.
--   4) Town은 첫 번째 1개만 남기고 나머지 삭제 대상.
--
-- 예상 결과: 약 177,000 파트 → 약 46,700 파트 (log.md 기록상 완성본 ~48,000과 일치)
--
-- 백업: backup/pre-dedupe-2026-07-20.rbxl (파일 > 사본 다운로드로 저장 완료)
-- 실행 방법: Studio 커맨드 바에 붙여넣고 실행(Run). 결과는 "PLAN::" 접두어로 출력된다.

local function log(fmt: string, ...): ()
	print("PLAN:: " .. string.format(fmt, ...))
end

-- 완전한 World로 볼 최소 자식 수. 정상 World는 자식이 19종이다.
local FULL_WORLD_MIN_CHILDREN = 10

local fullWorlds: { Model } = {}
local orphanWorlds: { Model } = {}
local towns: { Model } = {}

for _, child in ipairs(workspace:GetChildren()) do
	if child:IsA("Model") then
		if child.Name == "World" then
			if #child:GetChildren() >= FULL_WORLD_MIN_CHILDREN then
				table.insert(fullWorlds, child)
			else
				-- Ground 하나만 든 옛 지면 레이어
				table.insert(orphanWorlds, child)
			end
		elseif child.Name == "Town" then
			table.insert(towns, child)
		end
	end
end

log("발견: 완전한 World=%d, 고아 World=%d, Town=%d", #fullWorlds, #orphanWorlds, #towns)

if #fullWorlds == 0 then
	log("중단: 완전한 World를 찾지 못했다.")
	return
end

-- descendant가 가장 많은 World를 최신/최다 사본으로 보고 남긴다.
local keeper = fullWorlds[1]
local keeperCount = #keeper:GetDescendants()
for index = 2, #fullWorlds do
	local candidate = fullWorlds[index]
	local count = #candidate:GetDescendants()
	if count > keeperCount then
		keeper = candidate
		keeperCount = count
	end
end

log("유지할 World: d=%d", keeperCount)
if #towns > 0 then
	log("유지할 Town: d=%d", #towns[1]:GetDescendants())
end

-- 삭제 대상 후보를 모아 목록으로만 보여준다.
local doomed: { Model } = {}

for _, world in ipairs(fullWorlds) do
	if world ~= keeper then
		table.insert(doomed, world)
	end
end
for _, world in ipairs(orphanWorlds) do
	table.insert(doomed, world)
end
for index = 2, #towns do
	table.insert(doomed, towns[index])
end

local plannedRemoval = 0
for _, model in ipairs(doomed) do
	local count = #model:GetDescendants()
	plannedRemoval += count
	log("[삭제 예정] %s (d=%d)", model.Name, count)
end

local total = 0
for _, child in ipairs(workspace:GetChildren()) do
	total += #child:GetDescendants()
end

log("삭제 예정: %d개 모델, 약 %d 인스턴스", #doomed, plannedRemoval)
log("현재 총 %d → 정리 후 약 %d", total, total - plannedRemoval)
log("이 스크립트는 아무것도 삭제하지 않았다.")
