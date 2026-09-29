--!strict

local Constants = {
	REMOTE_FOLDER = "PorcelainRemotes",
	REMOTES = {
		-- 광장에 세워졌다는 신호. 카메라를 되돌리는 데 쓴다.
		PlazaState = "PlazaState",
		SaveMotion = "SaveMotion",
		RequestMotion = "RequestMotion",
		MotionSaved = "MotionSaved",
		RequestInventory = "RequestInventory",
		InventoryState = "InventoryState",
		EquipMotion = "EquipMotion",
		--[[
			탑 등반 + 격자 전투 (추가&수정.md `#### 탑 시스템`, `#### 전투 시스템`).

			판정은 전부 서버가 한다. 클라이언트는 TowerAction/GridAction으로 **의도만**
			보내고, TowerState/GridState로 내려온 스냅샷을 그린다.
		]]
		TowerAction = "TowerAction",
		TowerState = "TowerState",
		GridAction = "GridAction",
		GridState = "GridState",
	},
	MAX_MOTION_FRAMES = 300,
	MAX_MOTION_DURATION = 30,
}

return table.freeze(Constants)
