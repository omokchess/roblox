--!nocheck
--[[
	Vfx_Import.luau — 2026-11-01. 사용자가 꺼내 둔 마켓 VFX 팩(PACK — 이름, Workspace·ReplicatedStorage·ServerStorage 에서 찾음)을
	ReplicatedStorage.VfxLibrary.<PACK> 로 옮긴다. 클라이언트 CombatVfx.Pack("<PACK>/<이펙트>", cf, opts) 가 복제해 터뜨린다.
	  1. 정화: 팩 안 스크립트는 전부 지운다(이펙트 틀엔 필요 없다 — 무료 모델 뒷문 방지). 지우기 전 수상한 줄(require(숫자)·getfenv·loadstring·
	     HttpService·MarketplaceService·TeleportService·InsertService·긴 이스케이프 문자열)을 보고한다.
	  2. 목록: 파티클·빔·트레일을 직접 품은 것마다 경로 · 개수 · 텍스처 · 색 · 수명 · EmitCount 를 보고(/vfxlib) — 기술마다 고를 때 쓴다.
	  3. 낱개(작업 공간 바로 아래 파티클을 품은 Part — 팩을 꺼내면 흩어지는 견본)는 LOOSE 상자 안에 있는 것만 모아
	     VfxLibrary.Loose(이름 = 첫 이미터 이름) / VfxLibrary.Textures(1×1×1 이미터 하나 — 이름 = 텍스처 ID)로.
	돌리기: bash tools/job.sh tools/Vfx_Import.luau (PACKS 에 팩 이름들)
]]
local PACKS = { "vfx pack", "Big", "Anime", "Heads", "Beams", "Auras" }
-- 2026-11-01 꺼내 둔 낱개 견본 자리(x -4320~-4190, z -3660~-3570)
local LOOSE = { Min = Vector3.new(-4320, 30, -3660), Max = Vector3.new(-4190, 60, -3570) }
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
local lib = RS:FindFirstChild("VfxLibrary") or Instance.new("Folder")
lib.Name = "VfxLibrary"
lib.Parent = RS
-- 틀은 고정·충돌 없음(ReplicatedStorage 안에선 그려지지 않는다 — CombatVfx.Pack 이 복제해 터뜨린다)
local function tidy(root)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
		end
	end
	if root:IsA("BasePart") then
		root.Anchored, root.CanCollide, root.CanQuery, root.CanTouch = true, false, false, false
	end
end
local function catalog(src)
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
					table.insert(parts, string.format("P %s tex=%s col=%d,%d,%d life=%.2f-%.2f size=%.2f emit=%s rate=%g on=%s",
						e.Name, string.match(e.Texture, "%d+") or e.Texture, c.R * 255, c.G * 255, c.B * 255,
						e.Lifetime.Min, e.Lifetime.Max, e.Size.Keypoints[1].Value, tostring(e:GetAttribute("EmitCount")), e.Rate, tostring(e.Enabled)))
				elseif e:IsA("Beam") or e:IsA("Trail") then
					table.insert(parts, string.format("%s %s tex=%s", if e:IsA("Beam") then "B" else "T", e.Name, string.match(e.Texture, "%d+") or e.Texture))
				end
			end
			local path = string.sub(holder:GetFullName(), #lib:GetFullName() + 2)
			say("이펙트 %s [%s] | %s", path, holder.ClassName, table.concat(parts, " | "))
		end
	end
	return effects
end
for _, PACK in PACKS do
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
	local old = lib:FindFirstChild(src.Name)
	if old and old ~= src then
		old:Destroy()
	end
	src.Parent = lib
	tidy(src)
	local effects = catalog(src)
	say("팩 %s: 스크립트 %d 지움, 이펙트 묶음 %d, → %s", PACK, scripts, effects, src:GetFullName())
end)
if not ok then
	say("오류 %s", tostring(err))
end
end
-- 3. 낱개 견본
local ok, err = pcall(function()
	local loose = lib:FindFirstChild("Loose") or Instance.new("Folder")
	loose.Name = "Loose"
	loose.Parent = lib
	local tex = lib:FindFirstChild("Textures") or Instance.new("Folder")
	tex.Name = "Textures"
	tex.Parent = lib
	local n = 0
	for _, c in workspace:GetChildren() do
		local p = c:IsA("BasePart") and c.Position
		local first = c:FindFirstChildWhichIsA("ParticleEmitter", true)
		if p and first and p.X > LOOSE.Min.X and p.X < LOOSE.Max.X and p.Y > LOOSE.Min.Y and p.Y < LOOSE.Max.Y and p.Z > LOOSE.Min.Z and p.Z < LOOSE.Max.Z then
			for _, d in c:GetDescendants() do
				if d:IsA("LuaSourceContainer") then
					say("스크립트 지움 %s", d:GetFullName())
					d:Destroy()
				end
			end
			local single = c.Size.Magnitude < 2 and #c:GetChildren() == 1
			local base = if single then (string.match(first.Texture, "%d+") or "tex") else first.Name:gsub("%s+", "")
			local name, i = base, 1
			local folder = if single then tex else loose
			while folder:FindFirstChild(name) do
				i += 1
				name = base .. "-" .. i
			end
			c.Name = name
			c.Transparency = 1
			tidy(c)
			c.Parent = folder
			n += 1
		end
	end
	local e1, e2 = catalog(loose), catalog(tex)
	say("낱개 %d 옮김 (Loose %d · Textures %d)", n, e1, e2)
end)
if not ok then
	say("오류(낱개) %s", tostring(err))
end
HS:PostAsync("http://127.0.0.1:34999/vfxlib", table.concat(lines, "\n"))
