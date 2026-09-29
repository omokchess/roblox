--!nocheck
--[[
	StudioJobs.luau — 커맨드 바에서 **한 번** 돌려 두면, 로컬 서버(127.0.0.1:35000 = tools/swamp)의 job.txt 를
	1.5초마다 보고 값이 바뀔 때마다 run.luau 를 받아 실행한다. (2026-09-29)
	모니터가 꺼졌거나 다른 창이 앞을 가려 커맨드 바의 실행 단추를 못 누를 때도 작업을 이어 가려고 만들었다.
	  작업 넣기: bash tools/job.sh <스크립트 파일>   (run.luau 에 복사하고 job.txt 에 새 도장을 찍는다)
	다시 돌리면 앞 폴러는 _G.StudioJobsId 가 바뀌어 스스로 멈춘다. 10시간 뒤 스스로 멈춘다.
	실행 오류는 /jobs_err 로 보낸다.
]]
local HS = game:GetService("HttpService")
local BASE = "http://127.0.0.1:35000/"
local id = HS:GenerateGUID(false)
_G.StudioJobsId = id

local function get(name)
	local ok, body = pcall(function()
		return HS:GetAsync(BASE .. name, true)
	end)
	return ok and body or nil
end

local function report(name, text)
	pcall(function()
		HS:PostAsync("http://127.0.0.1:34999/" .. name, text)
	end)
end

task.spawn(function()
	local last = get("job.txt")
	local t0 = os.clock()
	report("jobs_up", tostring(last))
	while _G.StudioJobsId == id and os.clock() - t0 < 36000 do
		task.wait(1.5)
		local stamp = get("job.txt")
		if stamp and stamp ~= last then
			last = stamp
			local src = get("run.luau")
			if src then
				local f, err = loadstring(src)
				if f then
					task.spawn(function()
						local ok, e = pcall(f)
						if not ok then
							report("jobs_err", stamp .. "\n" .. tostring(e))
						end
					end)
				else
					report("jobs_err", stamp .. "\n" .. tostring(err))
				end
			end
		end
	end
end)
print("StudioJobs 시작", id)
