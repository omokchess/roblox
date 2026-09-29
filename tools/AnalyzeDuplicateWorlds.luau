--!strict
-- AnalyzeDuplicateWorlds.luau
--
-- 역할: Workspace에 중복 생성된 World / Town 모델들을 "읽기 전용"으로 비교한다.
--       어느 사본이 최신본인지 판단할 근거를 출력할 뿐, 아무것도 수정/삭제하지 않는다.
--
-- 배경: 2026-07-20 점검 결과 Workspace에 World 5개(42821 / 42823 / 42823 / 42821 / 2491)와
--       Town 2개(3895 / 3895)가 겹쳐 있었다. log.md 기록상 완성 맵은 약 48,000 파트인데
--       실제로는 약 177,000 파트였다. 지형 재생성 때마다 기존 World를 지우지 않고
--       새 World를 추가해서 누적된 것으로 보인다.
--
-- 이 중복이 유발하는 증상(사용자 보고와 일치):
--   - 피라미드가 겹쳐 보임(세대가 다른 피라미드 2개가 같은 자리에 존재)
--   - 평원의 옛 지형 흔적(땅 높낮이가 다름) = 옛 사본의 지면
--   - 성문 위 돌이 반짝임(z-fighting) = 같은 높이에 동일 벽이 2장
--   - 탑에 붙어있는 잔재 = 폐기된 사본의 구조물
--
-- 실행 방법: Studio 커맨드 바에 이 파일 내용을 붙여넣고 실행(Run).
--            결과는 출력(Output) 창에 "AN::" 접두어로 찍힌다.

-- 커맨드 바에서 한 줄씩 읽기 편하도록 접두어를 붙여 출력한다.
local function log(fmt: string, ...): ()
	print("AN:: " .. string.format(fmt, ...))
end

-- Workspace 직속 자식 중 비교 대상(World / Town 모델)만 수집한다.
local targets: { Model } = {}
for _, child in ipairs(workspace:GetChildren()) do
	if child:IsA("Model") and (child.Name == "World" or child.Name == "Town") then
		table.insert(targets, child)
	end
end

log("target count = %d", #targets)

-- 각 사본의 요약: 인덱스, 이름, 총 descendant 수, 바운딩 박스 중심/크기.
-- 바운딩 박스가 거의 같으면 = 같은 공간에 겹쳐 있다는 뜻이다.
for index, model in ipairs(targets) do
	local ok, cf, size = pcall(function()
		return model:GetBoundingBox()
	end)

	if ok and cf and size then
		local p = cf.Position
		log(
			"[%d] %s d=%d center=(%.0f, %.0f, %.0f) size=(%.0f, %.0f, %.0f)",
			index,
			model.Name,
			#model:GetDescendants(),
			p.X,
			p.Y,
			p.Z,
			size.X,
			size.Y,
			size.Z
		)
	else
		log("[%d] %s d=%d <bounding box 실패>", index, model.Name, #model:GetDescendants())
	end
end

-- 각 사본의 직속 자식 폴더 구성을 출력한다.
-- log.md의 작업 순서상 나중에 추가된 폴더(SwampFlora, IceCave, BossArenas 등)를
-- 가지고 있는 사본이 더 최신본이다.
for index, model in ipairs(targets) do
	local parts: { string } = {}
	for _, child in ipairs(model:GetChildren()) do
		table.insert(parts, string.format("%s=%d", child.Name, #child:GetDescendants()))
	end
	table.sort(parts)
	log("[%d] %s children(%d): %s", index, model.Name, #parts, table.concat(parts, ", "))
end
