--!strict
-- 연락선 설정

local FerryConfig = {
	ShipName = "안개늪호",
	Asset = "Ferry", -- ReplicatedStorage.SwampAssets(Mesh) 안의 모델 이름

	-- 운항 (항로 길이 약 2020 stud)
	MaxSpeed = 30, -- stud/s
	Accel = 2.4, -- stud/s²
	DwellTime = 24, -- 각 선착장 정박 시간 (초)
	PhaseOffset = 0, -- 전체 시간표 이동 (초)

	-- 도선판: 도착 후 N초 뒤 내리고, 출항 N초 전 올림
	GangplankDelay = 1.5,
	GangplankLead = 2.5,
	GangplankSwing = 1.2, -- 회전 시간
	BellBefore = 6, -- 출항 N초 전 종

	StopLabels = {
		Mistmire = "안개늪 섬",
		Harbor = "항구섬",
	} :: { [string]: string },

	-- 흔들림
	Bob = {
		Heave = 0.35, -- stud
		Pitch = 1.3, -- 도
		Roll = 1.8, -- 도
		DockedScale = 0.35,
		BankPerAccel = 0.6, -- 횡가속도(곡률×속도², stud/s²) 1 당 기울기(도)
		MaxBank = 6,
	},

	-- 플레이어 운반 / 안내
	CarryRay = 16, -- 캐릭터 아래로 배를 감지하는 거리
	DockUiRange = 110, -- 선착장 안내 UI 표시 거리
	RelaySendRate = 10, -- 배 위 상대 위치 전송 빈도 (Hz)

	-- 바다 구조
	RescueSwimSeconds = 18, -- 먼바다에서 이만큼 수영하면 구조 버튼 표시
	RescueMinDistanceFromLand = 90,
}

return FerryConfig
