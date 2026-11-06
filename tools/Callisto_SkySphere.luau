--!nocheck
--[[
	Callisto_SkySphere.luau — 2026-11-02. 블렌더 하늘 구(models/build_callisto_skysphere.py → models/CallistoSkySphere.glb)를 Ctrl+M 으로
	가져온 뒤, 구 메시를 ReplicatedStorage.CallistoAssets.SkySphere(MeshPart, 지름 2 스터드 — 클라이언트 Combat/CallistoSpace 가 크기를 정해 쓴다)로 옮긴다.
	표지(CallistoSkySphere_Marker 1×1×1)로 가져온 배율을 되찾고, 가져온 묶음은 지운다. 그림은 속성 SpaceLayerImage(tools/Callisto_SpaceLayer.luau)에서 클라이언트가 입힌다.
	기본 길 = Neon 재질 + TextureID(템플릿에는 SurfaceAppearance 를 두지 않는다). 안 밝게 나오면 EMISSIVE = true 로 다시 돌려 발광 마스크 길로 바꾼다
	(SurfaceAppearance 에 같은 그림을 색 지도·발광 마스크로 — 마스크 = 그림 밝기라 밝은 곳이 더 빛난다. 플러그인 권한 필요 — 안 되면 보고에 오류가 뜬다). 보고: /skysphere
]]
local HS = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local EMISSIVE = false
local EMISSIVE_STRENGTH = 1.5
local lines = {}
local function say(f, ...)
	lines[#lines + 1] = string.format(f, ...)
end
local ok, err = pcall(function()
	local marker, sphere
	for _, d in workspace:GetDescendants() do
		if d:IsA("MeshPart") then
			if d.Name == "CallistoSkySphere_Marker" then
				marker = d
			elseif d.Name == "CallistoSkySphere" then
				sphere = d
			end
		end
	end
	assert(marker and sphere, "가져온 CallistoSkySphere · 표지가 없다(GLB 를 먼저 가져올 것)")
	local imported = marker
	while imported.Parent and imported.Parent ~= workspace do
		imported = imported.Parent
	end
	assert(imported ~= marker and sphere:IsDescendantOf(imported), "가져온 묶음을 못 찾았다")
	local k = 1 / marker.Size.X
	say("표지 크기 %.4f → 배율 %.4f", marker.Size.X, k)
	local kit = RS:FindFirstChild("CallistoAssets") or Instance.new("Folder")
	kit.Name = "CallistoAssets"
	kit.Parent = RS
	local old = kit:FindFirstChild("SkySphere")
	if old then
		old:Destroy()
	end
	sphere.Size = sphere.Size * k -- 지름 2
	say("구 크기 %s", tostring(sphere.Size))
	sphere.Name = "SkySphere"
	sphere.Anchored = true
	sphere.CanCollide, sphere.CanQuery, sphere.CanTouch, sphere.CastShadow = false, false, false, false
	sphere.Material = Enum.Material.Neon
	sphere.Color = Color3.new(1, 1, 1)
	sphere.CFrame = CFrame.new()
	for _, c in sphere:GetChildren() do
		c:Destroy() -- 가져오며 딸린 SurfaceAppearance 등(있으면 Neon 이 덮인다)
	end
	-- 멀리서 거칠어지지 않게 · 안쪽이 안 보이면(감는 방향이 뒤집혔을 때) 양면으로
	pcall(function()
		sphere.RenderFidelity = Enum.RenderFidelity.Precise
	end)
	local dsOk = pcall(function()
		sphere.DoubleSided = true
	end)
	say("RenderFidelity Precise · DoubleSided %s", tostring(dsOk))
	if EMISSIVE then
		local image = kit:GetAttribute("SpaceLayerImage")
		assert(type(image) == "string" and image ~= "", "속성 SpaceLayerImage 가 없다(Callisto_SpaceLayer 먼저)")
		local sa = Instance.new("SurfaceAppearance")
		sa.ColorMap = image
		sa.EmissiveMaskContent = Content.fromUri(image)
		sa.EmissiveStrength = EMISSIVE_STRENGTH
		sa.Parent = sphere
		say("발광 마스크 길: 세기 %.2f", EMISSIVE_STRENGTH)
	end
	sphere.Parent = kit
	imported:Destroy()
	say("ReplicatedStorage.CallistoAssets.SkySphere 완료 (%s)", if EMISSIVE then "SurfaceAppearance 발광" else "Neon + TextureID")
end)
if not ok then
	say("오류 %s", tostring(err))
end
HS:PostAsync("http://127.0.0.1:34999/skysphere", table.concat(lines, "\n"))
