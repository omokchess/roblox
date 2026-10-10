# -*- coding: utf-8 -*-
"""
snow_walkcheck.py — 2026-10-10. 들어가는 건물·지하 카지노의 걷는 길 점검표 → tools/swamp/_walkcheck.luau (Studio 에서 돌려 recv/walk.txt).
점마다: 아래로 쏜 광선이 부딪히는(CanCollide) 바닥을 기대 높이 근처에서 찾는가, 그 위 사람 크기 상자(1.2×4×1.2, 발 0.7 위부터)에
부딪히는 것이 없는가. 좌표는 블렌더 (x, y, 바닥 z) — 로블록스 로컬 = (-x, z, y). 지하는 Casino_Gate 피벗 기준.
돌리기: python tools/snow_walkcheck.py && bash tools/job.sh tools/swamp/_walkcheck.luau
"""
import math
import os

HERE = os.path.dirname(os.path.abspath(__file__))

# 나선 계단(build_steam_under.py 와 같은 값)
ZU, Z_LAND, N, A0 = -28.0, 0.4, 44, -50.0
SW = 90.0 - 10.0 - A0 + 720.0
D, RISE = SW / N, (Z_LAND - ZU) / N
spiral = [(4.6 * math.cos(math.radians(A0 + (i + 0.5) * D)), 4.6 * math.sin(math.radians(A0 + (i + 0.5) * D)), Z_LAND - (i + 1) * RISE)
          for i in range(N)]
# 기물군 본부 날개 계단(build_steam_figuren.py: 바깥벽 따라 y 6 → 24, 21 단, 2.2 → 16)


def fstairs(s):
    return [(s * 34.8, 4.0 + (i + 0.5) * 18.0 / 21, 2.2 + (i + 1) * 13.8 / 21) for i in range(21)]


# 학교 계단(build_steam_school.py: y -1 → 12, 18 단, 바닥 2.2 → 14)
sstairs = [(0.0, -1.0 + (i + 0.5) * 13.0 / 18, 2.2 + (i + 1) * 11.8 / 18) for i in range(18)]

ROUTES = {
    "Casino_Gate": [
        ("입구", [(0, -13.5, 0.0), (0, -11.0, 0.4), (0, -8.1, 0.4), (0, -6.0, 0.4), (2.5, -5.0, 0.4)]),
        ("나선", spiral),
        ("로비·홀", [(0, 4.5, ZU), (0, 8.1, ZU), (0, 10.5, ZU), (0, 16.5, ZU), (0, 23.0, ZU), (0, 25.1, ZU), (0, 30.0, ZU),
                   (0, 44.0, ZU), (10.0, 44.0, ZU), (22.0, 44.0, ZU), (25.5, 44.0, ZU)]),
        ("경매장", [(28.0, 44.0, ZU), (31.0, 44.0, ZU), (31.0, 33.9, ZU), (42.0, 33.9, ZU), (31.0, 52.1, ZU), (42.0, 52.1, ZU)]),
        ("바·무대", [(-10.0, 54.0, ZU), (-18.0, 54.0, ZU), (10.0, 54.0, ZU), (16.0, 54.0, ZU)]),
    ],
    "Schule": [
        ("현관", [(0, -27.0, 0.0), (0, -24.0, 0.733), (0, -22.5, 1.467), (0, -20.0, 2.2), (0, -15.0, 2.2), (0, -8.0, 2.2)]),
        ("교실", [(-5.0, -11.0, 2.2), (-7.0, -11.0, 2.2), (-10.0, -11.0, 2.2), (-12.0, -14.0, 2.2), (-12.0, 0.0, 2.2)]),
        ("기계교실·체육관", [(5.0, -11.0, 2.2), (7.0, -11.0, 2.2), (9.5, -11.0, 2.2), (17.0, -11.0, 2.2), (17.0, 9.5, 2.2),
                       (24.0, 9.5, 2.2), (25.5, 9.5, 2.2), (28.0, 9.5, 2.2), (38.0, 2.0, 2.2), (38.0, -1.5, 2.2),
                       (38.0, -3.2, 1.5), (38.0, -5.0, 0.7), (38.0, -7.0, 0.0)]),
        ("계단", sstairs),
        ("회랑·위층", [(0, 13.5, 14.0), (-5.0, 14.8, 14.0), (-7.0, 14.8, 14.0), (-10.0, 14.8, 14.0), (-12.0, 0.0, 14.0),
                    (5.0, 14.8, 14.0), (7.0, 14.8, 14.0), (10.0, 14.8, 14.0), (14.0, -1.0, 14.0)]),
    ],
    "Steam_Factory": [("길", [(0, -42.0, 0.0), (0, -39.8, 1.3), (0, -36.4, 2.6), (0, -33.0, 2.8), (0, -25.0, 2.8), (0, -10.0, 2.8), (0, 22.0, 2.8)])],
    "Zapfen_Werk": [("길", [(0, -31.0, 0.0), (0, -28.1, 1.3), (0, -24.7, 2.6), (0, -21.0, 2.8), (0, -16.0, 2.8), (6.0, -6.0, 2.8),
                           (-8.0, -5.0, 2.8), (-6.0, 4.0, 2.8), (4.0, 6.0, 2.8), (12.0, 6.0, 2.8)])],
    "Figuren_HQ": [
        ("관문·로비·홀", [(0, -41.0, 0.0), (0, -38.8, 0.2), (0, -37.2, 0.733), (0, -35.6, 1.467), (0, -33.0, 2.2), (0, -29.0, 2.2),
                     (0, -22.0, 2.2), (0, -16.0, 2.2), (0, -10.0, 2.2), (6.3, -4.0, 2.2), (6.3, 7.0, 2.2), (6.3, 18.0, 2.2),
                     (-6.3, 7.0, 2.2), (0, 21.0, 2.2), (0, 23.6, 2.2)]),
        ("왼 날개", [(-20.0, -22.0, 2.2), (-24.0, -22.0, 2.2), (-27.5, -23.0, 2.2), (-30.0, 0.0, 2.2), (-30.0, 7.0, 2.2), (-24.0, 6.0, 2.2), (-21.0, 6.0, 2.2)]),
        ("왼 계단", fstairs(-1)),
        ("위층 왼쪽·회랑·작전실", [(-34.8, 23.0, 16.0), (-30.0, 23.0, 16.0), (-30.0, 2.0, 16.0), (-24.0, 2.0, 16.0), (-21.5, 2.0, 16.0),
                           (-21.5, -13.5, 16.0), (0.0, -13.5, 16.0), (0.0, -16.0, 16.0), (0.0, -17.5, 16.0), (-12.0, -17.5, 16.0),
                           (-20.0, -22.0, 16.0), (-24.0, -22.0, 16.0), (-28.0, -22.0, 16.0), (21.5, 27.5, 16.0)]),
        ("오른 날개", [(20.0, -22.0, 2.2), (24.0, -22.0, 2.2), (27.5, -20.0, 2.2), (27.5, -9.0, 2.2), (31.0, 0.0, 2.2), (27.0, 6.0, 2.2), (24.0, 6.0, 2.2), (21.0, 6.0, 2.2)]),
        ("오른 계단", fstairs(1)),
        ("위층 오른쪽", [(34.8, 23.0, 16.0), (30.0, 23.0, 16.0), (30.0, 10.0, 16.0), (26.5, 2.0, 16.0), (24.0, 2.0, 16.0), (24.0, -22.0, 16.0)]),
    ],
    "Frostig_Werk": [("길", [(-6.0, -13.0, 0.0), (-6.0, -11.6, 0.75), (-6.0, -10.0, 1.5), (-6.0, -8.6, 1.7), (-6.0, -5.0, 1.7), (0, -4.0, 1.7)])],
    "Inn_House": [("길", [(0, -11.0, 0.0), (0, -10.6, 0.75), (0, -9.0, 1.5), (0, -7.5, 1.7), (0, -4.0, 1.7), (0, 0.0, 1.7),
                         (5.0, -0.2, 1.7), (10.3, -0.2, 1.7), (10.2, 3.0, 1.7), (10.0, 5.1, 1.7), (5.0, 5.1, 1.7), (1.0, 5.1, 1.7)]),
                  ("계단 동", [(11.6, -0.2, 1.7), (13.8, -0.2, 1.7), (14.0, -3.0, 1.7), (14.0, -5.5, 1.7)]),
                  ("계단", [(17.4, -6.8 + (i + 0.5) * 11.0 / 13, 1.7 + (i + 1) * 8.6 / 13) for i in range(13)]),
                  ("2층", [(17.4, 5.7, 10.3), (13.5, 5.8, 10.3), (11.6, 5.8, 10.3), (9.0, 5.4, 10.3), (-5.5, 5.4, 10.3),
                          (-5.5, 3.4, 10.3), (-5.5, 1.0, 10.3), (-3.5, -3.0, 10.3), (5.5, 5.4, 10.3), (5.5, 3.4, 10.3), (5.5, 1.0, 10.3),
                          (3.5, -3.0, 10.3)])],
    "Shop_Blue": [("길", [(-5.0, -10.0, 0.0), (-5.0, -8.6, 0.75), (-5.0, -7.0, 1.5), (-5.0, -5.6, 1.7), (-5.0, -3.0, 1.7), (0, -1.5, 1.7)])],
    "Shop_Teal": [("길", [(-5.0, -10.0, 0.0), (-5.0, -8.6, 0.75), (-5.0, -7.0, 1.5), (-5.0, -5.6, 1.7), (-5.0, -3.0, 1.7), (0, -1.5, 1.7)])],
    "Shop_Red": [("길", [(-5.0, -10.0, 0.0), (-5.0, -8.6, 0.75), (-5.0, -7.0, 1.5), (-5.0, -5.6, 1.7), (-5.0, -3.0, 1.7), (0, -1.5, 1.7)])],
    "Ticket_Booth": [("길", [(8.0, 1.0, 0.0), (5.5, 1.0, 1.0), (3.5, 1.0, 1.2), (0.0, 1.5, 1.2)])],
}


def lua():
    out = ["-- tools/snow_walkcheck.py 가 만든 걷는 길 점검(손으로 고치지 말 것)", 'local HS = game:GetService("HttpService")',
           "local town = workspace.Schneereich[\"마을\"]", "local R = {"]
    for kind, routes in ROUTES.items():
        out.append('\t{ "%s", {' % kind)
        for name, pts in routes:
            out.append('\t\t{ "%s", { %s } },' % (name, ", ".join("{%.3f, %.3f, %.3f}" % p for p in pts)))
        out.append("\t} },")
    out.append("}")
    out.append('''local rp = RaycastParams.new()
rp.RespectCanCollide = true
local op = OverlapParams.new()
op.RespectCanCollide = true
local lines, bad, total = {}, 0, 0
for _, k in ipairs(R) do
	local m
	for _, d in ipairs(town:GetDescendants()) do
		if d:IsA("Model") and d.Name == k[1] then
			m = d
			break
		end
	end
	if not m then
		lines[#lines + 1] = k[1] .. " 없음"
		bad += 1
		continue
	end
	local pv = m:GetPivot()
	for _, route in ipairs(k[2]) do
		for i, p in ipairs(route[2]) do
			total += 1
			local w = pv:PointToWorldSpace(Vector3.new(-p[1], p[3], p[2]))
			local hit = workspace:Raycast(w + Vector3.new(0, 3.5, 0), Vector3.new(0, -5.5, 0), rp)
			local tag = string.format("%s/%s #%d (%.1f, %.1f, %.1f)", k[1], route[1], i, p[1], p[2], p[3])
			if not hit then
				lines[#lines + 1] = tag .. " 바닥 없음"
				bad += 1
			else
				local dy = hit.Position.Y - w.Y
				if dy < -0.35 or dy > 0.75 then
					lines[#lines + 1] = string.format("%s 바닥 높이 어긋남 %.2f (%s)", tag, dy, hit.Instance:GetFullName())
					bad += 1
				end
				local c = CFrame.new(w.X, hit.Position.Y + 0.7 + 2.0, w.Z) * pv.Rotation
				local parts = workspace:GetPartBoundsInBox(c, Vector3.new(1.0, 4.0, 1.0), op)
				if #parts > 0 then
					local names = {}
					for j = 1, math.min(3, #parts) do
						local q = parts[j]
						local l = pv:PointToObjectSpace(q.Position)
						names[#names + 1] = string.format("%s@(%.1f,%.1f,%.1f) %s", q.Name, -l.X, l.Z, l.Y, tostring(q.Size))
					end
					lines[#lines + 1] = tag .. " 막힘: " .. table.concat(names, " | ")
					bad += 1
				end
			end
		end
	end
end
table.insert(lines, 1, string.format("점 %d, 문제 %d", total, bad))
HS:PostAsync("http://127.0.0.1:34999/walk", table.concat(lines, "\\n"))''')
    return "\n".join(out) + "\n"


if __name__ == "__main__":
    p = os.path.join(HERE, "swamp", "_walkcheck.luau")
    with open(p, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(lua())
    print("점", sum(len(pts) for r in ROUTES.values() for _, pts in r), "→", p)
