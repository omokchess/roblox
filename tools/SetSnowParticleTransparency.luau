--!strict
-- SetSnowParticleTransparency.luau
--
-- 피드백: "snow particles 투명도 0으로 바꿔줘"
--
-- ── 위치 ────────────────────────────────────────────────────────────────
--   Workspace.Model 아래 `Snow Particles` 파트 **221개**
--   각 파트: size (142, 0.1, 109), color rgb(163,162,165), Material=Plastic
--   각 파트마다 ParticleEmitter 1개 (rate=1000, lifetime 5~10, speed 30)
--   분포: 중심 (102, 222, -1924), 범위 (2276, 182, 2324) — 설원 상공
--
-- ── 조사 결과 ───────────────────────────────────────────────────────────
--   Part.Transparency    = 0  (221개 전부) → 이미 요청값이라 바꿀 것이 없다
--   Emitter.Transparency = NumberSequence 0.00@0 → 0.04@0.98 → 1.00@1.00
--                          즉 수명 끝에서 사라진다. 이쪽이 0이 아니다.
--
--   그래서 **ParticleEmitter의 Transparency를 평탄한 0으로** 만든다.
--   눈 입자가 생성부터 소멸까지 완전 불투명해진다.
--
-- ── 되돌리기 ────────────────────────────────────────────────────────────
--   Ctrl+Z. 원래 값은 아래 ORIGINAL에 적어 두었다.
--     NumberSequence.new({
--       NumberSequenceKeypoint.new(0, 0),
--       NumberSequenceKeypoint.new(0.98, 0.04),
--       NumberSequenceKeypoint.new(1, 1),
--     })
--
-- 실행: Studio 커맨드 바에 붙여넣고 실행(Run). 결과는 "SNOWFIX::" 접두어.

local FLAT_OPAQUE = NumberSequence.new(0)

local function log(fmt: string, ...): ()
	print("SNOWFIX:: " .. string.format(fmt, ...))
end

local changedEmitters = 0
local visitedParts = 0

for _, descendant in ipairs(workspace:GetDescendants()) do
	if descendant.Name == "Snow Particles" and descendant:IsA("BasePart") then
		visitedParts += 1
		for _, child in ipairs(descendant:GetDescendants()) do
			if child:IsA("ParticleEmitter") then
				child.Transparency = FLAT_OPAQUE
				changedEmitters += 1
			end
		end
	end
end

log(
	"Snow Particles 파트 %d개 / ParticleEmitter %d개의 Transparency를 0으로 설정",
	visitedParts,
	changedEmitters
)

-- 반영 확인: 모든 에미터가 평탄한 0인지 다시 읽는다.
local stillCurved = 0
for _, descendant in ipairs(workspace:GetDescendants()) do
	if descendant.Name == "Snow Particles" and descendant:IsA("BasePart") then
		for _, child in ipairs(descendant:GetDescendants()) do
			if child:IsA("ParticleEmitter") then
				for _, keypoint in ipairs(child.Transparency.Keypoints) do
					if keypoint.Value ~= 0 then
						stillCurved += 1
						break
					end
				end
			end
		end
	end
end

log("검증: 0이 아닌 에미터 %d개 (0이어야 정상)", stillCurved)
