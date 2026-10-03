--!strict
--[[
	Fx/Common — 직업 이펙트가 같이 쓰는 조합과 기본 타격. (2026-09-28)

	이펙트 함수 모양: function(ctx, ev, at: Vector3?)
	  ctx.Vfx      CombatVfx
	  ctx.Root     시전자 HumanoidRootPart CFrame (앞 = LookVector)
	  ctx.Forward  적 쪽 방향(수평 단위 벡터)
	  ctx.Tip(slot?) / ctx.Base(slot?)   무기 끝·밑동 월드 자리(slot 기본 "W")
	  ctx.Hand(side?)  손 자리("R"/"L")
	  ctx.Target   첫 대상 가슴 높이 자리(없으면 앞 6칸)
	  ctx.Targets  이번 타격 대상들 자리
	  ctx.Ground   시전자 발밑 높이(y)
	  ctx.Weapons  CombatWeapons(오브 대형·병 숨기기 등)
	at 은 Hit 사건일 때 맞은 대상 자리다.
]]
local Common = {}

local function c(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end
Common.c = c

--[[
	ctx.Vfx 를 k 배로 키운 것으로 감싼다(크기·반지름·굵기 옵션만). 쓰는 곳:
	  디버그 보스 페이즈(Fx/Debug), 단계 스킬(CombatDirector — 특이점·붕괴·분쇄·크레셴도의 단계, 2026-10-03)
]]
local SCALE_KEYS = { "Size", "Radius", "R0", "R1", "Width", "Height" }
function Common.ScaledVfx(Vfx: any, k: number): any
	if k == 1 then
		return Vfx
	end
	return setmetatable({}, {
		__index = function(_, name)
			local f = Vfx[name]
			if type(f) ~= "function" then
				return f
			end
			return function(...)
				local args = table.pack(...)
				for i = 1, args.n do
					local a = args[i]
					if type(a) == "table" and (a.Size or a.Radius or a.R1 or a.Width or a.Height) then
						local opts = table.clone(a)
						for _, key in SCALE_KEYS do
							if type(opts[key]) == "number" then
								opts[key] *= k
							end
						end
						args[i] = opts
					end
				end
				return f(table.unpack(args, 1, args.n))
			end
		end,
	})
end

Common.BLOOD = { c(170, 16, 24), c(120, 8, 16), c(210, 40, 40) }

-- 피 튀김(dir 쪽 원뿔)
function Common.Blood(Vfx: any, at: Vector3, dir: Vector3?, count: number?, speed: number?)
	Vfx.Burst(at, { Count = count or 10, Colors = Common.BLOOD, Size = 0.28, Speed = speed or 18, Dir = dir, Spread = 55, Gravity = 70, Life = 0.7, Material = Enum.Material.SmoothPlastic })
end

-- 기본 타격: 번쩍 + 조각 + 불꽃
function Common.Impact(Vfx: any, at: Vector3, color: Color3?, size: number?)
	local s = size or 1
	Vfx.Flash(at, { Color = color or Color3.new(1, 1, 1), Size = 7 * s, Life = 0.22 })
	Vfx.Burst(at, { Count = math.floor(8 * s), Color = color or c(255, 244, 220), Size = 0.3 * s, Speed = 20 * s, Life = 0.45 })
	Vfx.Sparks(at, { Color = color, Count = math.floor(14 * s) })
end

-- 땅 먼지 + 바닥 고리
function Common.Land(Vfx: any, ground: Vector3, size: number?, color: Color3?)
	local s = size or 1
	Vfx.Dust(ground + Vector3.new(0, 0.3, 0), { Count = math.floor(10 * s), Size = 1.2 * s, Speed = 10 * s, Color = color })
	Vfx.Ring(CFrame.new(ground + Vector3.new(0, 0.15, 0)), { R0 = 0.6, R1 = 4 * s, Color = color or c(230, 225, 210), Life = 0.35, Width = 0.25, Height = 0.08 })
end

-- 명상: 발밑 고리 + 떠오르는 빛가루
function Common.Meditate(Vfx: any, ground: Vector3, color: Color3)
	Vfx.Ring(CFrame.new(ground + Vector3.new(0, 0.12, 0)), { R0 = 3.5, R1 = 1.2, Color = color, Life = 1.1, Width = 0.18, Height = 0.06 })
	Vfx.Sparks(ground + Vector3.new(0, 0.5, 0), { Color = color, Count = 16, MinSpeed = 2, Speed = 5, Accel = Vector3.new(0, 6, 0), Lifetime = 1.2, Size = 0.35 })
end

-- 가드: 발밑 고리 + 앞쪽 세로 고리
function Common.GuardRing(Vfx: any, ctx: any, color: Color3)
	Vfx.Ring(CFrame.new(Vector3.new(ctx.Root.Position.X, ctx.Ground + 0.15, ctx.Root.Position.Z)), { R0 = 1, R1 = 3.4, Color = color, Life = 0.5, Width = 0.3, Height = 0.1 })
	local front = ctx.Root.Position + ctx.Forward * 1.6
	Vfx.Ring(CFrame.lookAt(front, front + ctx.Forward), { R0 = 0.4, R1 = 2.4, Color = color, Life = 0.4, Width = 0.2, Facing = true })
end

--[[
	칼 궤적 원호. center 를 중심으로 forward(적 쪽)와 "위" 가 이루는 판에 긋는다.
	tilt = 판을 앞 축으로 기울인 각(0 = 세로로 내려치기, 90 = 가로베기, 45 = 대각)
	from/to = 판 안의 각(0 = 앞, 90 = 위, 180 = 뒤, -90 = 아래)
]]
function Common.Arc(ctx: any, center: Vector3, tilt: number, from: number, to: number, opts: { [string]: any }?)
	local o = table.clone(opts or {})
	local fwd = ctx.Forward
	local up = (CFrame.fromAxisAngle(fwd, math.rad(tilt)) * Vector3.new(0, 1, 0)).Unit
	o.From, o.To = from, to
	ctx.Vfx.Slash(CFrame.fromMatrix(center, fwd, up), o)
end

-- 음표 탄환: 빛나는 조각에 음표 글자가 붙어 날아간다
function Common.NoteBolt(Vfx: any, from: Vector3, to: Vector3, time: number, color: Color3, arc: number?)
	Vfx.Projectile(from, to, {
		Time = time,
		Arc = arc or 0.8,
		TrailColor = color,
		Build = function()
			local p = Vfx.Part(Vector3.new(0.45, 0.45, 0.45), CFrame.new(from), color)
			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.fromScale(2, 2)
			bb.LightInfluence = 0
			bb.Parent = p
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.fromScale(1, 1)
			t.Text = if math.random() < 0.5 then "♪" else "♫"
			t.TextScaled = true
			t.Font = Enum.Font.GothamBlack
			t.TextColor3 = color
			t.TextStrokeTransparency = 0.3
			t.Parent = bb
			return p
		end,
	})
end

-- 땅 위에 번지는 금(from 에서 dir 쪽으로 length 만큼, 지그재그 조각)
function Common.Crack(Vfx: any, from: Vector3, dir: Vector3, length: number, color: Color3, life: number?)
	local d = Vector3.new(dir.X, 0, dir.Z).Unit
	local side = d:Cross(Vector3.new(0, 1, 0))
	local rng = Random.new()
	local p = from
	local n = math.max(3, math.floor(length / 1.4))
	for i = 1, n do
		local q = from + d * (length * i / n) + side * rng:NextNumber(-0.7, 0.7)
		local len = (q - p).Magnitude
		local seg = Vfx.Part(Vector3.new(0.22, 0.08, len), CFrame.lookAt(p, q) * CFrame.new(0, 0, -len / 2), color)
		task.delay(life or 0.9, function()
			seg:Destroy()
		end)
		p = q
	end
end

-- 돌 조각 튀기
function Common.Rubble(Vfx: any, at: Vector3, count: number?, color: Color3?)
	Vfx.Burst(at, { Count = count or 10, Colors = { color or Color3.fromRGB(150, 140, 125), Color3.fromRGB(110, 102, 92), Color3.fromRGB(180, 172, 158) }, Size = 0.55, Speed = 20, Gravity = 70, Life = 0.9, Material = Enum.Material.Slate })
end

function Common.Head(ctx: any): Vector3
	return ctx.Root.Position + Vector3.new(0, 1.6, 0)
end

function Common.Feet(ctx: any): Vector3
	return Vector3.new(ctx.Root.Position.X, ctx.Ground, ctx.Root.Position.Z)
end

return Common
