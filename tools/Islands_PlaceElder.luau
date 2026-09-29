--!nocheck
--[[
	Islands_PlaceElder.luau — 거목을 바위 대지 위에 앉힌다.

	거목은 랜드마크이므로 지반을 따라다니지 않는다.
	숲 한가운데 언덕은 지반이 아니라 봉우리 블록으로 세웠고,
	나무 맞춤 스크립트(Islands_LiftForest)는 지반만 보기 때문에
	거목만 따로 앉혀야 한다. 그래서 그 스크립트에서 Elder 는 제외돼 있다.

	거목은 두 군데에 나뉘어 있다.
	  Struct 의 For_Elder_*  왕관 모양 뿌리 신전과 줄기
	  Flora  의 For_Elder_*  꼭대기 잎
	둘을 **같은 양만큼** 올려야 한다. 따로 옮기면 잎이 줄기에서 떨어진다.
	실제로 한 번 그렇게 돼서 잎 90장이 왕관 위로 쏟아졌다.

	Islands_Mountains.luau 뒤에 실행한다.
	발밑을 실측해 대지 윗면에 맞추므로 몇 번을 돌려도 결과가 같다.
]]

local X, Z = -4800, 1600 -- 거목이 서는 자리. 봉우리 씨앗과 같은 좌표다
local SINK = 6 -- 밑동을 대지 안으로 이만큼 파묻어 이음매를 감춘다

local S = workspace.Surface
local mtn = S:FindFirstChild("Mountains")
assert(mtn, "Mountains 가 없다. Islands_Mountains.luau 를 먼저 돌려라")

local rp = RaycastParams.new()
rp.FilterType = Enum.RaycastFilterType.Include
rp.FilterDescendantsInstances = { mtn, S.World }

local hit = workspace:Raycast(Vector3.new(X, 1400, Z), Vector3.new(0, -2000, 0), rp)
assert(hit, "거목 자리 아래에 아무것도 없다")
local top = hit.Position.Y

-- 두 폴더에 흩어진 거목 파트를 한 덩어리로 모은다
local parts, minY = {}, 1e9
for _, fold in ipairs(S["R_숲"]:GetChildren()) do
	for _, p in ipairs(fold:GetChildren()) do
		if p:IsA("BasePart") and p.Name:match("^For_Elder") then
			parts[#parts + 1] = p
			minY = math.min(minY, p.Position.Y)
		end
	end
end
assert(#parts > 100, "거목 파트가 " .. #parts .. "개뿐이다. 이름 규칙을 확인해라")

local d = (top - SINK) - minY
for _, p in ipairs(parts) do
	p.CFrame = p.CFrame + Vector3.new(0, d, 0)
end

print(
	string.format(
		"[PlaceElder] %d파트를 %d 만큼 옮김 / 밑동 %d -> %d (대지 윗면 %d)",
		#parts,
		d,
		minY,
		minY + d,
		top
	)
)
