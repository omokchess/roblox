--!strict
--[[
	TowerArena — 탑 등반 전용 **등반실**의 자리 계산.

	요청
	  "탑 등반 할 땐 따로 등반 장소로 가서 등반 해야 해."
	  "멀티 플레이 할 때 겹침 현상 없애야 하니까 이것도 신경 써서 해줘."

	--------------------------------------------------------------------------
	겹침이 왜 생겼나

	예전에는 클라이언트가 **자기 캐릭터가 서 있던 자리**에 격자를 깔았다
	(`origin + (0, 0, -30)`). 격자 타일과 적 더미는 클라이언트가 만든 것이라
	자기 화면에만 보이지만, **캐릭터는 서버에 복제된다**.

	그래서 두 사람이 광장에서 나란히 서 있다가 동시에 등반을 시작하면
	  - 두 사람의 격자가 같은 공간에 겹치고
	  - 서로의 캐릭터가 남의 전장 한복판에 서 있게 되고
	  - 최악의 경우 같은 칸을 두 사람이 차지한다.

	--------------------------------------------------------------------------
	해결: 1인 1등반실

	하늘 높은 곳에 등반실을 SLOT_COUNT개 나란히 지어 두고, 등반을 시작한 사람에게
	**서버가 빈 방 하나를 배정한다.** 방과 방 사이는 격자 전체 폭보다 훨씬 넓어
	남의 방이 내 화면에 걸치지 않는다.

	      [1]      [2]      [3]   ...      ← SLOT_SPACING 간격
	     ┌───┐    ┌───┐    ┌───┐
	     │격자│    │격자│    │격자│           격자 가로폭 ARENA_ACROSS
	     └───┘    └───┘    └───┘

	이 모듈은 **순수 계산만** 한다(Lune에서 그대로 돌아간다). 방을 실제로 짓는 것은
	`TowerService`, 그 자리에 격자를 그리는 것은 `TowerBattleController`다.
	`BattleGrid`(논리) ↔ `BattleArena`(월드 좌표)를 나눈 것과 같은 이유다.
]]

local TowerArena = {}

--[[
	등반실을 하늘에 두는 이유.

	지상에는 이미 지형과 마을이 깔려 있어 빈 땅을 12칸이나 찾기 어렵고, 찾더라도
	나중에 그 자리에 무언가를 지으면 조용히 겹친다. 아무것도 없는 높이를 쓰면
	그런 충돌이 원천적으로 없다.
]]
TowerArena.ZONE_Y = 1400

-- 등반실이 늘어서는 줄의 중심 (X/Z). 월드 원점의 고대 대탑 바로 위다.
TowerArena.ZONE_CENTER_X = 0
TowerArena.ZONE_CENTER_Z = 0

--[[
	방 개수. 한 서버에서 동시에 등반할 수 있는 인원이다.

	방이 다 차면 등반을 거절한다 — 자리 없이 입장시키면 결국 누군가와 겹치므로,
	"겹침 없음"을 지키려면 여기서 막는 편이 맞다.
]]
TowerArena.SLOT_COUNT = 12

--[[
	방 간격.

	격자 가로폭은 `BattleArena.ArenaExtents`로 계산하면
	  Midline(8) + Width(6) * (CellSize(5) + Gap(1)) * 2 = 80
	이다. 240이면 방 사이에 160스터드가 비어, 카메라를 옆으로 돌려도 옆방이
	화면에 들어오지 않는다.
]]
TowerArena.SLOT_SPACING = 240

-- 바닥 판 크기. 격자(80 × 18)를 넉넉히 덮는다.
TowerArena.FLOOR_LENGTH = 150 -- X (양 진영 축)
TowerArena.FLOOR_WIDTH = 80 -- Z (세로 라인 축)
TowerArena.FLOOR_THICKNESS = 3

export type Point = { X: number, Y: number, Z: number }

--[[
	방 하나의 중심 좌표. index는 1..SLOT_COUNT.

	줄 전체가 ZONE_CENTER를 기준으로 좌우 대칭이 되도록 가운데 정렬한다.
]]
function TowerArena.SlotOrigin(index: number): Point
	local clamped = math.clamp(math.floor(index), 1, TowerArena.SLOT_COUNT)
	local offset = (clamped - (TowerArena.SLOT_COUNT + 1) / 2) * TowerArena.SLOT_SPACING
	return {
		X = TowerArena.ZONE_CENTER_X + offset,
		Y = TowerArena.ZONE_Y,
		Z = TowerArena.ZONE_CENTER_Z,
	}
end

--[[
	전투가 없을 때(보상 화면 등) 서 있을 자리.

	격자 한복판에 두면 카드 화면 뒤로 캐릭터가 어중간하게 걸치므로, 아군 진영
	바깥쪽으로 조금 물려 둔다.
]]
function TowerArena.SlotStand(index: number): Point
	local origin = TowerArena.SlotOrigin(index)
	return {
		X = origin.X - TowerArena.FLOOR_LENGTH / 2 + 12,
		Y = origin.Y,
		Z = origin.Z,
	}
end

--[[
	두 방이 실제로 떨어져 있는지 확인하는 계산.

	테스트에서 "간격이 격자 폭보다 넓은가"를 검사하는 데 쓴다. 나중에 격자를
	키우면서 SLOT_SPACING을 잊고 그대로 두면 여기서 걸린다.
]]
function TowerArena.SlotGap(): number
	return TowerArena.SLOT_SPACING - TowerArena.FLOOR_LENGTH
end

return TowerArena
