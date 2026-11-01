--!nocheck
--[[
	Vfx_Import.luau — 2026-11-01. 사용자가 꺼내 둔 마켓 VFX 팩(PACK — 이름, Workspace·ReplicatedStorage·ServerStorage 에서 찾음)을
	ReplicatedStorage.VfxLibrary.<PACK> 로 옮긴다. 클라이언트 CombatVfx.Pack("<PACK>/<이펙트>", cf, opts) 가 복제해 터뜨린다.
	  1. 정화: 팩 안 스크립트는 전부 지운다(이펙트 틀엔 필요 없다 — 무료 모델 뒷문 방지). 지우기 전 수상한 줄(require(숫자)·getfenv·loadstring·
	     HttpService·MarketplaceService·TeleportService·InsertService·긴 이스케이프 문자열)을 보고한다.
	  2. 목록: 파티클·빔·트레일을 직접 품은 것마다 경로 · 개수 · 텍스처 · 색 · 수명 · EmitCount 를 보고(/vfxlib) — 기술마다 고를 때 쓴다.
	돌리기: sed 로 PACK 을 채운 뒤 bash tools/job.sh tools/Vfx_Import.luau
]]
local PACK = "__PACK__"
local HS = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local lines = {}
local function say(f, ...)
	lines[#lines + 1] = string.format(f, ...)
end
local SUSPECT = {
	"require%s*%(%s*%d", "getfenv", "setfenv", "loadstring", "HttpService", "MarketplaceService", "TeleportService",
	"InsertService", "\\%d%d%d\\%d%d%d", "string%.reverse", "_G%.",
}
local ok, err = pcall(function()
	local src = workspace:FindFirstChild(PACK) or RS:FindFirstChild(PACK) or game:GetService("ServerStorage"):FindFirstChild(PACK)
	assert(src, "팩을 못 찾음: " .. PACK)
	-- 1. 정화
	local scripts = 0
	for _, d in src:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			scripts += 1
			local okSrc, code = pcall(function()
				return d.Source
			end)
			local hits = {}
			if okSrc then
				for _, pat in SUSPECT do
					if string.find(code, pat) then
						table.insert(hits, pat)
					end
				end
			end
			say("스크립트 지움 %s [%s] %s", d:GetFullName(), d.ClassName, if #hits > 0 then "★수상: " .. table.concat(hits, ", ") else "")
			d:Destroy()
		end
	end
	-- 2. 옮기기
	local lib = RS:FindFirstChild("VfxLibrary") or Instance.new("Folder")
	lib.Name = "VfxLibrary"
	lib.Parent = RS
	local old = lib:FindFirstChild(src.Name)
	if old and old ~= src then
		old:Destroy()
	end
	src.Parent = lib
	-- 3. 목록
	local effects = 0
	local seen = {}
	for _, d in src:GetDescendants() do
		if (d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail")) and not seen[d.Parent] then
			local holder = d.Parent
			seen[holder] = true
			effects += 1
			local parts = {}
			for _, e in holder:GetChildren() do
				if e:IsA("ParticleEmitter") then
					local c = e.Color.Keypoints[1].Value
					table.insert(parts, string.format("P %s tex=%s col=%d,%d,%d life=%.2f-%.2f size=%.2f emit=%s rate=%g",
						e.Name, string.match(e.Texture, "%d+") or e.Texture, c.R * 255, c.G * 255, c.B * 255,
						e.Lifetime.Min, e.Lifetime.Max, e.Size.Keypoints[1].Value, tostring(e:GetAttribute("EmitCount")), e.Rate))
				elseif e:IsA("Beam") or e:IsA("Trail") then
					table.insert(parts, string.format("%s %s tex=%s", if e:IsA("Beam") then "B" else "T", e.Name, string.match(e.Texture, "%d+") or e.Texture))
				end
			end
			local path = string.sub(holder:GetFullName(), #lib:GetFullName() + 2)
			say("이펙트 %s [%s] | %s", path, holder.ClassName, table.concat(parts, " | "))
		end
	end
	say("팩 %s: 스크립트 %d 지움, 이펙트 묶음 %d, → %s", PACK, scripts, effects, src:GetFullName())
end)
if not ok then
	say("오류 %s", tostring(err))
end
HS:PostAsync("http://127.0.0.1:34999/vfxlib", table.concat(lines, "\n"))
