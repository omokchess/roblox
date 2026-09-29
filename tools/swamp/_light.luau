local L = game:GetService("Lighting")
local out = {}
local props = {
	Atmosphere = {"Density","Offset","Color","Decay","Glare","Haze"},
	BloomEffect = {"Intensity","Size","Threshold"},
	SunRaysEffect = {"Intensity","Spread"},
	ColorCorrectionEffect = {"Brightness","Contrast","Saturation","TintColor","Enabled"},
	BlurEffect = {"Size","Enabled"},
	DepthOfFieldEffect = {"FarIntensity","FocusDistance","InFocusRadius","NearIntensity","Enabled"},
	ColorGradingEffect = {"Enabled"},
	Sky = {"SkyboxBk","SunAngularSize","MoonAngularSize","StarCount","CelestialBodiesShown"},
}
for _, c in L:GetChildren() do
	local line = c.ClassName .. " " .. c.Name
	for _, p in props[c.ClassName] or {} do
		local ok, v = pcall(function() return c[p] end)
		line ..= " " .. p .. "=" .. tostring(ok and v or "?")
	end
	table.insert(out, line)
end
for _, p in {"ClockTime","Brightness","ExposureCompensation","EnvironmentDiffuseScale","EnvironmentSpecularScale","GlobalShadows","ShadowSoftness","GeographicLatitude","ColorShift_Top","ColorShift_Bottom","FogColor","FogStart","FogEnd"} do
	local ok, v = pcall(function() return L[p] end)
	table.insert(out, p .. "=" .. tostring(ok and v or "?"))
end
game:GetService("HttpService"):PostAsync("http://127.0.0.1:34999/light", table.concat(out, "\n"))
