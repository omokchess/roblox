--!strict
-- 서버 진입점: 원격 이벤트 생성 → 전투 → 연락선 → 월드(비동기 생성) → 적

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared").Util.Net)
Net.CreateAll()

local Services = script.Parent:WaitForChild("Services")
local CombatService = require(Services.Combat.CombatService)
local FerryService = require(Services.FerryService)
local WorldService = require(Services.WorldService)
local EnemyService = require(Services.Enemies.EnemyService)

CombatService.Start()
FerryService.Start()
task.spawn(WorldService.Start)
EnemyService.Start()

print("[Swamp] 서버 시작 완료")
