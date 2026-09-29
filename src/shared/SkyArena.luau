--!strict
--[[
	SkyArena — 하늘에 띄운 **개인 전장 칸**의 자리 계산. (2026-09-28, 옛 TowerArena)

	한 사람의 격자 전투를 남과 겹치지 않는 자리에서 치르게 한다. 예전엔 탑 등반실이었고,
	탑 입장을 걷어낸 지금은 디버그 전투(`BattleService`)가 "하늘 전장"으로 쓴다.

	겹침이 왜 생겼나: 클라이언트가 자기 캐릭터가 서 있던 자리에 격자를 깔면, 캐릭터는
	서버에 복제되므로 두 사람이 나란히 전투를 시작할 때 서로의 전장 한복판에 서게 된다.
	그래서 하늘 높은 곳에 칸을 SLOT_COUNT 개 나란히 두고 **서버가 빈 칸 하나를 배정한다.**

	      [1]      [2]      [3]   ...      ← SLOT_SPACING 간격
	     ┌───┐    ┌───┐    ┌───┐
	     │격자│    │격자│    │격자│           격자 가로폭 ARENA_ACROSS
	     └───┘    └───┘    └───┘

	이 모듈은 **순수 계산만** 한다(Lune 에서 그대로 돈다). 바닥을 실제로 짓는 것은
	`BattleService`, 그 자리에 격자를 그리는 것은 `BattleClient` 다.
]]

local SkyArena = {}

--[[
	전장을 하늘에 두는 이유.

	지상에는 이미 지형과 마을이 깔려 있어 빈 땅을 12칸이나 찾기 어렵고, 찾더라도
	나중에 그 자리에 무언가를 지으면 조용히 겹친다. 아무것도 없는 높이를 쓰면
	그런 충돌이 원천적으로 없다.
]]
SkyArena.ZONE_Y = 1400

-- 칸이 늘어서는 줄의 중심 (X/Z). 월드 원점 바로 위다.
SkyArena.ZONE_CENTER_X = 0
SkyArena.ZONE_CENTER_Z = 0

--[[
	칸 개수. 한 서버에서 동시에 하늘 전장을 쓸 수 있는 인원이다.

	칸이 다 차면 하늘 전장을 거절한다(필드 전장은 된다) — 자리 없이 입장시키면 결국 누군가와 겹치므로,
	"겹침 없음"을 지키려면 여기서 막는 편이 맞다.
]]
SkyArena.SLOT_COUNT = 12

--[[
	방 간격.

	격자 가로폭은 `BattleArena.ArenaExtents`로 계산하면
	  Midline(8) + Width(6) * (CellSize(5) + Gap(1)) * 2 = 80
	이다. 240이면 방 사이에 160스터드가 비어, 카메라를 옆으로 돌려도 옆방이
	화면에 들어오지 않는다.
]]
SkyArena.SLOT_SPACING = 240

-- 바닥 판 크기. 격자(80 × 18)를 넉넉히 덮는다.
SkyArena.FLOOR_LENGTH = 150 -- X (양 진영 축)
SkyArena.FLOOR_WIDTH = 80 -- Z (세로 라인 축)
SkyArena.FLOOR_THICKNESS = 3

export type Point = { X: number, Y: number, Z: number }

--[[
	방 하나의 중심 좌표. index는 1..SLOT_COUNT.

	줄 전체가 ZONE_CENTER를 기준으로 좌우 대칭이 되도록 가운데 정렬한다.
]]
function SkyArena.SlotOrigin(index: number): Point
	local clamped = math.clamp(math.floor(index), 1, SkyArena.SLOT_COUNT)
	local offset = (clamped - (SkyArena.SLOT_COUNT + 1) / 2) * SkyArena.SLOT_SPACING
	return {
		X = SkyArena.ZONE_CENTER_X + offset,
		Y = SkyArena.ZONE_Y,
		Z = SkyArena.ZONE_CENTER_Z,
	}
end

--[[
	전투가 없을 때(레벨업 화면 등) 서 있을 자리.

	격자 한복판에 두면 레벨업 화면 뒤로 캐릭터가 어중간하게 걸치므로, 아군 진영
	바깥쪽으로 조금 물려 둔다.
]]
function SkyArena.SlotStand(index: number): Point
	local origin = SkyArena.SlotOrigin(index)
	return {
		X = origin.X - SkyArena.FLOOR_LENGTH / 2 + 12,
		Y = origin.Y,
		Z = origin.Z,
	}
end

--[[
	두 방이 실제로 떨어져 있는지 확인하는 계산.

	테스트에서 "간격이 격자 폭보다 넓은가"를 검사하는 데 쓴다. 나중에 격자를
	키우면서 SLOT_SPACING을 잊고 그대로 두면 여기서 걸린다.
]]
function SkyArena.SlotGap(): number
	return SkyArena.SLOT_SPACING - SkyArena.FLOOR_LENGTH
end

return SkyArena
