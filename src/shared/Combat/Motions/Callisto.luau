--!strict
--[[
	칼리스토 — 히든 보스(2026-10-31). 큰곰자리 · 천문학자 · 시인, 기물군의 비숍.
	2026-11-01 전면 손질(사용자: "칼리스토 1·2·3페이즈 모션이랑 이펙트, 할 수 있는 최대한의 노력과 품질로 레퍼런스 찾아서").
	레퍼런스·기술별 연출 표: 저장소 `보스 칼리스토.md` 「모션·이펙트 3판」. 케노스 아스테리스모스 = WWE 피니셔(같은 문서 「밸런스 개선안」 B절).

	성격: 관찰자. 서두르지 않고 꼿꼿이 서서 고개를 기울여 상대를 "찍는다".
	1페이즈 — 오른팔이 곧 검(무기 CallistoArms Main, 팔 축에 고정 · 날은 기술 동안만 소매에서 나온다 — CombatDirector).
	  날이 팔의 연장(2.5)이라 날이 나와 있는 동안 팔은 늘 수직에서 45° 넘게 든다(칼끝이 땅에 박히지 않게 — 자세마다 칼끝 높이 확인).
  날 방향(2026-11-01 사용자: "칼날이 아니라 칼 면으로 때리는 것 같은데"): 날 단면은 두께 0.07(팔 로컬 X) × 폭 0.28(팔 로컬 Z)이라 날은 팔 로컬 ±Z 쪽이다.
  팔을 앞뒤 면으로 휘두르면 넓은 면이 앞장서므로, 휘두를 때 칼끝 속도(팔 축에 수직 성분)가 팔 로컬 Z 와 나란하도록 팔을 긴 축 둘레로 비튼다(R6 상자 팔이라 거의 안 보인다).
  비틀기는 기술마다 키별로 구해 RArm 에 넣었고(callisto_edge_gen.py gen — 원본 키는 tools/combat/out/callisto_edge_base.json), 휘두르는 순간(칼끝 25 스터드/초 이상) |cos| ≥ 0.8 을 검사로 지킨다(check).
	  레퍼런스: 엘든 링 말레니아(의수 + 칼 — "칼 팔을 뒤로 감아 든 준비 동작이 화려한 기술의 신호", 물새 춤 = 도약 · 잠깐 떠 있다가 연타 묶음 셋),
	            사이버펑크 2077 맨티스 블레이드(팔에서 나온 날 — 도약 베기), 아케인 리니지 블레이드 댄서(아스트로 세시 칼춤 — 사용자 사양),
	            영 시리즈(Fatal Frame) 카메라 옵스큐라(포착 원이 대상에게 좁혀지고, 공격 순간 셔터 = 페이탈 프레임) — 왼손목 카메라 기술.
	2·3페이즈 — 북두칠성 망치(WeaponDefinitions.CallistoHammer, 무기 종류 StarHammer → 이 표의 Hammer 묶음). 대기는 오른 어깨에 메고,
	  공격은 두 손(오른손 y 0 · 왼손 y -0.85). 자세 = tools/combat/design/callisto_hammer_gen.py(손이 자루에 붙는지 · 머리가 땅에 박히지 않는지 계산).
	  대기(2026-11-01 사용자: "팔뚝을 팔이라 정의해서, 180도정도 뒤집은 다음 망치를 어깨에 걸치게"): R6 팔을 아래팔로 보고 세워 손이 귀 곁, 자루는 어깨 윗면 위, 머리는 등 뒤.
	  대기 ↔ 두 손 자세는 망치만 손 둘레로 들썩(HPOP)여 어깨에서 떼었다가 얹는다(곧장 섞으면 머리가 몸통을 가로지른다).
	  레퍼런스: 두 손 거대 망치(어깨 메기 → 머리 위로 → 내려찍기), 슬레지해머 스윙(뒷손은 고정, 칠 때 두 손 단단히 — US7694392),
	            엘든 링 아스텔·라다곤/엘든 짐승(우주 별 공격 — 별 비 · 레이저), 할로우 나이트 라디언스(빛살 · 일식 후광 연출).
	박자(feedback-motion-rhythm): 느린 준비(sineOut) → 짧은 멈춤(긴장) → 번개 같은 한 방(expoOut · quadIn) → 짧게 넘침 → 여운을 두고 천천히(sineInOut).
	사건(k): Hit(i) · Dash(to = Target/Home, gap) · Fx(n = Fx/Callisto 의 이름) · Trail(on, slot) · Shake(a, d) · Stop(d)
	트로히아(2026-11-06)는 QTE 1개 안 **5연격**(Hit 1~5 — 약·약·중·중·강)이다.
	신데시 톤 아스트론 · 쏟아지는 뭇별(2026-11-06)은 QTE 1개 안 3비트로 합쳐져 모션이 **3번 치는 한 묶음**(강중약 — 셋째가 가장 센 한 방)이다.
	망치 모션은 Kit.Chain 으로 키마다 무기 각 표기를 앞 키에 맞춘다(자세 계산기 값은 표기가 제멋대로라 그대로 두면 한 바퀴 돈다).
]]
local Kit = require(script.Parent.Parent.MotionKit)
local K = Kit.K
local With = Kit.With
-- 날 비틀기 중간 키(tools/combat/design/callisto_edge_gen.py): 칼 기술은 휘두르는 동안 오른팔을 팔 자신의 긴 축 둘레로 비틀어 칼끝이 가는 쪽에 날(팔 로컬 ±Z)이 오게 한다.
-- 비튼 팔은 오일러(YXZ)에서 값이 크게 휘어(팔이 수평 앞인 X≈90 근처는 짐벌) 키 둘만으론 칼끝이 엉뚱한 길로 가므로, 휘어지는 곳엔 원래 모션을 그 시각에 찍은 자세를 키로 끼운다.
local Roll = K

local function M(motion: { [string]: any }): { [string]: any }
	return Kit.Chain(motion)
end

--=== 1페이즈 자세(칼 팔 · 손목 카메라) ===--

-- 관찰자의 대기: 오른 어깨를 조금 앞으로(몸 20°), 상체는 살짝 젖혀 턱을 든 채 고개를 갸웃. 칼날은 소매 속, 카메라 왼팔은 가슴 앞으로 반쯤
local OBS = {
	Root = { 0, 0, 0, 0, 20, 0 },
	Torso = { 4, -6, 0 },
	Head = { -6, -16, 6 },
	RArm = { 40, 0, 12 },
	LArm = { 52, 10, -4 },
	RLeg = { 8, 0, 4 },
	LLeg = { -6, 0, -4 },
}
-- 베기 준비(말레니아의 칼 팔 뒤로 감아 듦): 칼 팔을 오른 어깨 위 뒤로, 몸을 오른쪽으로 비틀고 왼손은 앞으로 균형
local READY_HI = { Root = { 0, -0.2, 0.25, 0, -20, 0 }, Torso = { 10, -24, 0 }, Head = { 0, 20, 0 }, RArm = { 165, 0, 35 }, LArm = { 60, 0, -20 }, RLeg = { -14, 0, 8 }, LLeg = { 22, 0, -8 } }
-- 비스듬히 내려벤 끝: 몸이 왼쪽으로 풀리고 칼 팔은 몸 앞을 가로질러 왼쪽 아래(칼끝은 땅 위 1.7)
local SLASH_END = { Root = { 0, -0.4, -0.35, 0, 24, 0 }, Torso = { -22, 30, 0 }, Head = { 10, -14, 0 }, RArm = { 82, 0, -58 }, LArm = { 10, 0, -40 }, RLeg = { 40, 0, 8 }, LLeg = { -30, 0, -8 } }
-- 찌르기(신데시 톤 아스트론): 몸째 뒤로 당겨(오른 어깨 뒤) 팔·칼을 한 줄로 겨눴다가 → 앞발을 내디디며 어깨째 꿰뚫는다
local DRAW = { Root = { 0, -0.25, 0.5, 0, -30, 0 }, Torso = { 6, -26, 0 }, Head = { 0, 30, 0 }, RArm = { 84, 0, 14 }, LArm = { 60, 0, -30 }, RLeg = { -12, 0, 8 }, LLeg = { 20, 0, -8 } }
local THRUST = { Root = { 0, -0.45, -0.75, 0, 18, 0 }, Torso = { -14, 22, 0 }, Head = { 10, -20, 0 }, RArm = { 94, 0, -6 }, LArm = { -24, 0, -18 }, RLeg = { 50, 0, 6 }, LLeg = { -38, 0, -6 } }
-- 칼춤(아스트로 세시): 웅크린 준비(칼 팔은 옆 뒤로) → 도약 → 두 팔을 수평으로 펴고 돈다
local CROUCH = { Root = { 0, -0.75, 0.35, 0, -30, 0 }, Torso = { -26, -20, 0 }, Head = { 22, 20, 0 }, RArm = { 30, 0, 78 }, LArm = { 40, 0, -50 }, RLeg = { 60, 0, 10 }, LLeg = { -10, 0, -10 } }
local LEAP = { Root = { 0, 1.8, -0.6, 0, -40, 0 }, Torso = { 8, -20, 0 }, Head = { -6, 20, 0 }, RArm = { 150, 0, 60 }, LArm = { 60, 0, -60 }, RLeg = { 50, 0, 8 }, LLeg = { -30, 0, -8 } }
local SPIN = { Root = { 0, -0.3, 0, 0, 0, 0 }, Torso = { -6, 0, 0 }, Head = { 0, 0, 0 }, RArm = { 4, 0, 92 }, LArm = { 4, 0, -92 }, RLeg = { 4, 0, 10 }, LLeg = { -4, 0, -10 } }
-- 카메라 겨눔: 몸을 틀어 왼 어깨를 앞으로, 왼팔을 쭉 뻗어 렌즈로 겨눈다(고개를 카메라 쪽으로 기울여 뷰파인더를 본다)
local AIM = { Root = { 0, 0, 0, 0, -30, 0 }, Torso = { 2, -18, 0 }, Head = { -2, 30, 0 }, RArm = { 22, 0, 18 }, LArm = { 90, 0, 0 }, RLeg = { 6, 0, 4 }, LLeg = { -4, 0, -4 } }
local AIM_EYE = With(AIM, { Head = { 4, 38, 12 }, Torso = { 4, -22, 0 } })
-- 심베라즈마: 멱살 잡기 → 들어 올림 → 던질 준비 → 내던짐
local GRAB = With(AIM, { LArm = { 96, 0, 4 }, Torso = { -10, -14, 0 }, Root = { 0, -0.1, 0, 0, -20, 0 }, Head = { 0, 20, 0 } })
local LIFT = With(AIM, { LArm = { 126, 0, 4 }, Torso = { 10, -10, 0 }, Head = { 8, 24, 0 }, Root = { 0, 0.05, 0.1, 0, -20, 0 }, RLeg = { -6, 0, 4 }, LLeg = { 14, 0, -4 } })
local WIND = With(AIM, { LArm = { 120, 30, 40 }, Torso = { 6, 32, 0 }, Head = { 0, -10, 0 }, Root = { 0, -0.1, 0.25, 0, 14, 0 } })
local THROW = With(AIM, { LArm = { 40, -30, -70 }, Torso = { -16, -38, 0 }, Head = { 6, 30, 0 }, Root = { 0, -0.25, -0.25, 0, -44, 0 }, RLeg = { 30, 0, 8 }, LLeg = { -26, 0, -8 } })

--=== 2·3페이즈 자세(북두칠성 망치 — callisto_hammer_gen.py 로 구함) ===--
-- 대기(2026-11-01 사용자: "팔뚝을 팔이라 정의해서, 180도정도 뒤집은 다음 망치를 어깨에 걸치게"): R6 팔을 아래팔로 보고 위로 세운다(RArm X≈183 — 손이 오른쪽 귀 곁 머리 높이).
-- 오른손 하나로 쥔 자루가 오른 어깨 윗면 뒤쪽 가장자리를 넘어(몸통과 틈 0.01) 머리는 등 뒤 아래에 걸린다(몸통·머리·왼팔과 안 겹침, 자루가 오른팔에 파고드는 건 쥐는 자리 0.42뿐).
-- 몸은 1페이즈 관찰자 그대로. 왼팔은 허벅지 곁으로 늘어뜨려 손목 카메라가 앞을 본다. 계산: callisto_hammer_gen.py hobs
local HOBS = { Root = { 0, 0, 0, 0, 20, 0 }, Torso = { 4, -6, 0 }, Head = { -6, -16, 6 }, RArm = { 183.2, 76.8, 4.6 }, LArm = { 14, 6, -6 }, RLeg = { 8, 0, 4 }, LLeg = { -6, 0, -4 }, W = { 0, 0, 0, -52, 26.1, 121.4 } }
-- 들썩: 손·몸은 대기 그대로, 망치만 손 둘레로 돌려 머리가 어깨 위 하늘을 본다. 대기 ↔ 두 손 자세 사이에 거쳐 망치가 몸통·머리를 가로지르지 않게 한다(callisto_hammer_gen.py)
local HPOP = With(HOBS, { W = { 0, 0, 0, -59, -40.6, 27.3 } })
-- 두 손 낮은 겨눔(머리는 앞 오른쪽 무릎 높이)
local HREADY = { Root = { 0, -0.35, 0.1, 0, 30, 0 }, Torso = { -10, 14, 0 }, Head = { 8, -18, 0 }, RArm = { 64.2, 29.8, -2.2 }, LArm = { 77.4, -57.7, 25.8 }, RLeg = { 22, 0, 8 }, LLeg = { -14, 0, -8 }, W = { 0, -0.01, -0.01, -78.1, -164.3, 49.3 } }
-- 머리 위로 치켜듦(망치 머리는 등 뒤 위 — 내려찍기 준비)
local HRAISE = { Root = { 0, -0.1, 0.25, 0, 10, 0 }, Torso = { 12, 6, 0 }, Head = { -2, -6, 0 }, RArm = { 159.6, 25.9, -51.5 }, LArm = { 126.5, -34.4, 31.7 }, RLeg = { -10, 0, 6 }, LLeg = { 16, 0, -6 }, W = { 0.01, 0, -0.01, -0.6, -241.2, -23.6 } }
-- 내려찍은 끝(무릎을 굽혀 앞 땅에)
local HSMASH = { Root = { 0, -0.65, -0.45, 0, 6, 0 }, Torso = { -26, 0, 0 }, Head = { 16, 0, 0 }, RArm = { 76.2, 27.6, -11.6 }, LArm = { 79.7, -48.6, 37.5 }, RLeg = { 48, 0, 8 }, LLeg = { -36, 0, -8 }, W = { 0, -0.02, 0, -81.8, -358.4, -38.9 } }
-- 가로치기 준비(몸을 오른쪽으로 감고 망치는 오른쪽 뒤 허리 높이) · 끝(왼쪽으로 풀려 망치는 왼쪽 뒤까지 감긴다)
local HCOIL = { Root = { 0, -0.3, 0, 0, -40, 0 }, Torso = { -8, -30, 0 }, Head = { 0, 30, 0 }, RArm = { 52.6, 65.1, -3.9 }, LArm = { 54, -13.5, 20.9 }, RLeg = { 14, 0, 8 }, LLeg = { -10, 0, -8 }, W = { -0.02, 0.06, -0.02, -58.3, -181.2, 191.4 } }
local HSWEEP = { Root = { 0, -0.35, -0.25, 0, 30, 0 }, Torso = { -12, 32, 0 }, Head = { 4, -24, 0 }, RArm = { 82.5, 32.6, -45.4 }, LArm = { 80.5, -63.1, 24 }, RLeg = { 26, 0, 8 }, LLeg = { -18, 0, -8 }, W = { 0.02, -0.01, -0.01, -79.2, -185.5, 361.3 } }
-- 하늘로 곧추세움(머리가 하늘을 본다 — 별을 부를 때)
local HSKY = { Root = { 0, 0.2, 0, 0, 0, 0 }, Torso = { 12, 0, 0 }, Head = { 28, 0, 0 }, RArm = { 158.7, 21.9, -32.9 }, LArm = { 114.1, -44.9, 42.8 }, RLeg = { 0, 0, 4 }, LLeg = { 0, 0, -4 }, W = { 0.01, -0.02, -0.01, -78.1, -213.7, 33.3 } }
-- 한 손 올려치기 끝(머리가 앞 위 — 별을 쏘아 올린다)
local HUPPER = { Root = { 0, 0.05, -0.2, 0, 10, 0 }, Torso = { 8, -10, 0 }, Head = { -10, 4, 0 }, RArm = { 123.1, 26.4, -12.9 }, LArm = { 40, 0, -40 }, RLeg = { -6, 0, 4 }, LLeg = { 24, 0, -4 }, W = { 0, 0, 0, -20.6, -130.1, 54.9 } }
-- 막기(자루를 가로로 얼굴 앞에)
local HGUARD = { Root = { 0, -0.3, 0.2, 0, 10, 0 }, Torso = { -8, 6, 0 }, Head = { 12, -6, 0 }, RArm = { 114.1, 39, -5.2 }, LArm = { 112.1, -37.1, 4.5 }, RLeg = { 20, 0, 8 }, LLeg = { -14, 0, -8 }, W = { 0, 0, -0.01, -26, -226.6, 89.5 } }

-- 맞음·막음·피함·쓰러짐·버릇(대기 자세 base 위에). guard = 막을 때 자세(무기 포함)
local function reactions(base: { [string]: any }, guard: { [string]: any }, fidgets: { any }): { [string]: any }
	return {
		-- 맞음: 머리가 먼저 젖혀지고(0.05) 몸통이 뒤따르며 반 걸음 밀린다 → 버티고 → 고개를 털며 돌아옴
		Hit = M({
			Duration = 0.62,
			Keys = {
				K(0, nil, base),
				K(0.05, "expoOut", base, { Head = { 26, -8, 0 }, Torso = { 10, 8, 0 } }),
				K(0.12, "quadOut", base, { Torso = { 18, 12, 0 }, Head = { 20, -6, 0 }, Root = { 0, -0.05, 0.7, 0, 28, 0 }, LArm = { 20, 0, -24 } }),
				K(0.3, "sineOut", base, { Torso = { 8, 6, 0 }, Head = { 6, 10, 0 }, Root = { 0, -0.1, 0.5, 0, 24, 0 } }),
				K(0.62, "sineInOut", base),
			},
		}),
		Guard = M({
			Duration = 0.6,
			Keys = {
				K(0, nil, base),
				K(0.08, "expoOut", guard),
				K(0.16, "quadOut", guard, { Root = { (guard.Root or base.Root)[1], (guard.Root or base.Root)[2] - 0.08, ((guard.Root or base.Root)[3]) + 0.25, 0, (guard.Root or base.Root)[5], 0 } }),
				K(0.6, "sineInOut", base),
			},
		}),
		-- 피함: 무게를 오른발에 싣고 옆으로 미끄러지듯 반 바퀴 비켜섰다가 돌아온다
		Dodge = M({
			Duration = 0.6,
			Keys = {
				K(0, nil, base),
				K(0.05, "quadIn", base, { Root = { -0.2, -0.15, 0, 0, 24, 0 }, Torso = { -4, 6, 0 } }),
				K(0.16, "expoOut", base, { Root = { -1.5, -0.05, 0.5, 0, 40, 12 }, Torso = { -8, 12, 0 }, Head = { 0, -10, 0 }, RLeg = { -10, 0, 18 }, LLeg = { 10, 0, -6 } }),
				K(0.6, "sineInOut", base),
			},
		}),
		-- 쓰러짐: 휘청 → 한 무릎을 꿇고 하늘(아들의 별)을 올려다본 뒤 → 천천히 고개를 떨군다
		Death = M({
			Duration = 2.0,
			Keys = {
				K(0, nil, base),
				K(0.15, "expoOut", base, { Torso = { 18, 0, 0 }, Head = { 24, 0, 0 }, Root = { 0, 0, 0.5, 0, 20, 0 } }),
				K(0.42, "quadIn", base, { Torso = { -10, 0, 0 }, Head = { -6, 0, 0 }, Root = { 0, -0.6, 0.4, 0, 20, 0 }, RLeg = { 40, 0, 6 } }),
				K(0.8, "sineOut", base, { Root = { 0, -1.3, 0.2, 0, 20, 0 }, Torso = { 8, 0, 0 }, Head = { 34, 0, 0 }, RLeg = { 88, 0, 6 }, LLeg = { -8, 0, -6 }, LArm = { 120, 0, -10 } }),
				K(1.25, nil, base, { Root = { 0, -1.3, 0.2, 0, 20, 0 }, Torso = { 10, 0, 0 }, Head = { 38, 0, 0 }, RLeg = { 88, 0, 6 }, LLeg = { -8, 0, -6 }, LArm = { 126, 0, -10 } }),
				K(2.0, "sineInOut", base, { Root = { 0, -1.5, 0.2, 0, 20, 0 }, Torso = { -34, 0, 0 }, Head = { -30, 0, 0 }, RLeg = { 88, 0, 6 }, LLeg = { -8, 0, -6 }, LArm = { 10, 0, -10 } }),
			},
		}),
		Fidgets = fidgets,
	}
end

-- 1페이즈 버릇: 카메라를 들어 찰칵 · 고개를 반대로 갸웃하며 상대를 훑어봄
local BLADE = reactions(OBS, { RArm = { 84, 0, -62 }, LArm = { 60, 0, -10 }, Torso = { -6, 10, 0 }, Root = { 0, -0.15, 0.25, 0, 26, 0 } }, {
	M({
		Duration = 1.5,
		Keys = {
			K(0, nil, OBS),
			K(0.35, "sineOut", OBS, { LArm = { 86, 14, 0 }, Head = { -2, 8, 4 } }),
			K(0.85, nil, OBS, { LArm = { 88, 14, 0 }, Head = { -2, 10, 6 } }),
			K(0.9, "expoOut", OBS, { LArm = { 92, 14, 0 }, Head = { -4, 10, 6 } }),
			K(1.5, "sineInOut", OBS),
		},
	}),
	M({
		Duration = 1.8,
		Keys = {
			K(0, nil, OBS),
			K(0.6, "sineInOut", OBS, { Head = { -4, 14, -10 }, Torso = { 4, 4, 0 } }),
			K(1.2, nil, OBS, { Head = { -2, 18, -12 }, Torso = { 4, 6, 0 } }),
			K(1.8, "sineInOut", OBS),
		},
	}),
})
-- 망치 버릇: 어깨를 으쓱해 망치를 들썩이며 고쳐 메기(손이 올라 망치 머리가 등에서 살짝 뜨고 → 툭 내려앉음) · 별을 올려다봄
local HAMMER = reactions(HOBS, HGUARD, {
	M({
		Duration = 1.3,
		Keys = {
			K(0, nil, HOBS),
			K(0.2, "quadOut", HOBS, { Root = { 0, 0.07, 0, 0, 20, 0 }, Torso = { 7, -6, 0 }, RArm = { 177, 76.8, 4.6 }, W = { 0, 0, 0, -43.9, 13.4, 102.3 } }),
			K(0.36, "quadIn", HOBS, { Root = { 0, -0.05, 0, 0, 20, 0 }, Torso = { 3, -6, 0 }, RArm = { 186, 76.8, 4.6 } }),
			K(0.5, "backOut", HOBS, { Root = { 0, 0.01, 0, 0, 20, 0 } }),
			K(1.3, "sineInOut", HOBS),
		},
	}),
	M({
		Duration = 2.2,
		Keys = {
			K(0, nil, HOBS),
			K(0.8, "sineInOut", HOBS, { Head = { 30, -6, 0 }, Torso = { 10, -6, 0 } }),
			K(1.5, nil, HOBS, { Head = { 32, -10, 0 }, Torso = { 10, -6, 0 } }),
			K(2.2, "sineInOut", HOBS),
		},
	}),
})
HAMMER.Idle = Kit.Breath(HOBS, { Duration = 4.2, Chest = 2.4, Rise = 0.05, Head = -1.2 })

-- 알코르(2페이즈 소환체 — 떠 있는 작은 별, 클라이언트 Combat/Alcor). 채널은 Root 하나: 위아래로 흔들리며 돈다
local ALCOR_IDLE = {
	Duration = 2.4,
	Loop = true,
	Keys = {
		{ t = 0, Root = { 0, 0, 0, 0, 0, 0 } },
		{ t = 1.2, e = "sineInOut", Root = { 0, 0.35, 0, 0, 180, 0 } },
		{ t = 2.4, e = "sineInOut", Root = { 0, 0, 0, 0, 360, 0 } },
	},
}
local ALCOR = {
	Idle = ALCOR_IDLE,
	Windup = ALCOR_IDLE,
	Hit = {
		Duration = 0.45,
		Keys = {
			{ t = 0, Root = { 0, 0, 0, 0, 0, 0 } },
			{ t = 0.06, e = "expoOut", Root = { 0, 0.15, 0.7, 0, 40, 0 } },
			{ t = 0.45, e = "sineInOut", Root = { 0, 0, 0, 0, 0, 0 } },
		},
	},
	-- 하늘로 돌아간다
	Death = {
		Duration = 1.2,
		Keys = {
			{ t = 0, Root = { 0, 0, 0, 0, 0, 0 } },
			{ t = 1.2, e = "sineIn", Root = { 0, 3, 0, 0, 540, 0 } },
		},
	},
	Skills = {},
}

return {
	Idle = Kit.Breath(OBS, { Duration = 3.8, Chest = 2.2, Rise = 0.04, Head = -1.2 }),
	Hit = BLADE.Hit,
	Guard = BLADE.Guard,
	Dodge = BLADE.Dodge,
	Death = BLADE.Death,
	Fidgets = BLADE.Fidgets,
	-- 무기 종류 StarHammer 일 때 이 묶음(CombatMotions.ByType)
	Hammer = HAMMER,
	Alcor = ALCOR,
	Skills = {
		--=== 1페이즈 성위 보는 자(칼 팔 · 손목 카메라) ===--
		-- 1-1 세시 파라티리시: 다가가며 칼 팔을 어깨 위 뒤로 감아 들고(칼날이 번뜩 — 말레니아의 신호) → 짧은 멈춤 → 비스듬히 내려벤다.
		-- 베인 자리는 [화상]이라 날을 따라 불꽃이 남는다
		CallistoSlash = {
			Duration = 1.4,
			Keys = {
				K(0, nil, OBS),
				Roll(0.01, "linear", { Root = { 0, -0.01, 0.01, 0, 18, 0 }, Torso = { 4.5, -7.4, 0 }, Head = { -5.5, -13.2, 5.5 }, RArm = { 43.1, -49.8, -22.9 }, LArm = { 52.6, 9.2, -5.3 }, RLeg = { 6.3, 0, 4.3 }, LLeg = { -3.8, 0, -4.3 } }),
				Roll(0.069, "linear", { Root = { 0, -0.05, 0.05, 0, 6.6, 0 }, Torso = { 7.1, -15.3, 0 }, Head = { -2.9, 2.6, 2.9 }, RArm = { 57.1, -97.6, -74.8 }, LArm = { 56.1, 4.8, -12.3 }, RLeg = { -3.3, 0, 6.1 }, LLeg = { 8.4, 0, -6.1 } }),
				K(0.2, "quadOut", With(READY_HI, { RArm = { 35.1, -141.8, -122.6 }, Root = { 0, -0.1, 0.1, 0, -6, 0 } })),
				K(0.34, "quadOut", READY_HI, { RArm = { 6.1, -167.7, -142.7 } }),
				K(0.42, nil, READY_HI, { RArm = { -4.5, -164.3, -141.5 }, Torso = { 12, -28, 0 } }),
				Roll(0.423, "linear", { Root = { 0, -0.26, 0.07, 0, -7.1, 0 }, Torso = { 2, -11, 0 }, Head = { 2.9, 10, 0 }, RArm = { 24.8, -147.4, -153.6 }, LArm = { 45.4, 0, -25.9 }, RLeg = { 1.8, 0, 8 }, LLeg = { 6.8, 0, -8 } }),
				Roll(0.425, "linear", { Root = { 0, -0.29, -0.01, 0, -0.7, 0 }, Torso = { -2.9, -2.6, 0 }, Head = { 4.4, 5.1, 0 }, RArm = { 38.3, -130.5, -149.2 }, LArm = { 38.1, 0, -28.8 }, RLeg = { 9.7, 0, 8 }, LLeg = { -0.8, 0, -8 } }),
				Roll(0.427, "linear", { Root = { 0, -0.31, -0.08, 0, 4.4, 0 }, Torso = { -6.9, 4.2, 0 }, Head = { 5.5, 1.1, 0 }, RArm = { 45.3, -109.3, -136.8 }, LArm = { 32.3, 0, -31.1 }, RLeg = { 15.9, 0, 8 }, LLeg = { -6.8, 0, -8 } }),
				Roll(0.431, "linear", { Root = { 0, -0.34, -0.18, 0, 11.7, 0 }, Torso = { -12.5, 13.7, 0 }, Head = { 7.2, -4.5, 0 }, RArm = { 45.7, -73.4, -111.3 }, LArm = { 24, 0, -34.4 }, RLeg = { 24.8, 0, 8 }, LLeg = { -15.4, 0, -8 } }),
				K(0.48, "expoOut", SLASH_END, { RArm = { 21.1, -30.1, -85.5 } }),
				K(0.6, "backOut", SLASH_END, { Torso = { -24, 36, 0 }, RArm = { 11, -24.8, -85.6 } }),
				Roll(0.775, "sineIn", { Root = { 0, -0.4, -0.35, 0, 24, 0 }, Torso = { -19, 30, 0 }, Head = { 10, -14, 0 }, RArm = { 44.5, -26, -80.9 }, LArm = { 10, 0, -40 }, RLeg = { 40, 0, 8 }, LLeg = { -30, 0, -8 } }),
				Roll(0.838, "linear", { Root = { 0, -0.4, -0.35, 0, 24, 0 }, Torso = { -16.3, 26.8, 0 }, Head = { 10, -14, 0 }, RArm = { 62.1, -21.1, -73.2 }, LArm = { 10, 0, -40 }, RLeg = { 40, 0, 8 }, LLeg = { -30, 0, -8 } }),
				K(0.95, "quadOut", SLASH_END, { Torso = { -14, 24, 0 }, RArm = { 76, 0, -50 } }),
				K(1.4, "sineInOut", OBS),
			},
			Events = {
				{ t = 0.06, k = "Dash", to = "Target", gap = 3.4, d = 0.26 },
				{ t = 0.3, k = "Fx", n = "SlashGlint" },
				{ t = 0.4, k = "Trail", on = true, slot = "W" },
				{ t = 0.45, k = "Fx", n = "BladeArc" },
				{ t = 0.47, k = "Hit", i = 1 },
				{ t = 0.47, k = "Fx", n = "BurnSlash" },
				{ t = 0.47, k = "Shake", a = 0.3, d = 0.14 },
				{ t = 0.47, k = "Stop", d = 0.06 },
				{ t = 0.66, k = "Trail", on = false, slot = "W" },
				{ t = 1.0, k = "Dash", to = "Home", d = 0.32 },
			},
		},
		-- 1-2 파라티리시: 몸을 틀어 손목 카메라를 들고 → 뷰파인더에 고개를 붙인 채 포착 원이 대상에게 좁혀지는 동안 멈춤(셔터 찬스)
		-- → 찰칵(페이탈 프레임 — 흰 섬광, 대상 둘레 사진 틀) → 반동 → 찍은 것을 보듯 고개를 갸웃(회피 불가)
		CallistoPhoto = {
			Duration = 1.3,
			Keys = {
				K(0, nil, OBS),
				K(0.26, "sineOut", With(AIM, { LArm = { 70, 0, -4 } })),
				K(0.42, "quadOut", AIM_EYE),
				K(0.62, nil, AIM_EYE, { Head = { 4, 40, 14 } }),
				K(0.67, "expoOut", AIM_EYE, { LArm = { 104, 0, 0 }, Torso = { 8, -20, 0 }, Root = { 0, 0, 0.12, 0, -30, 0 } }),
				K(0.9, "sineOut", AIM, { LArm = { 70, 10, -6 }, Head = { -8, 14, -16 } }),
				K(1.3, "sineInOut", OBS),
			},
			Events = {
				{ t = 0.4, k = "Fx", n = "Focus" },
				{ t = 0.63, k = "Fx", n = "Flash" },
				{ t = 0.65, k = "Hit", i = 1 },
				{ t = 0.65, k = "Shake", a = 0.12, d = 0.08 },
			},
		},
		-- 2-1 트로히아(2026-11-06 5연격 — QTE 1개 안 Hit 1~5): 칼 팔을 가슴 앞으로 접어 감고(짧은 멈춤) → 등손·손등 번갈아 가로베기 4연타(약·약·중·중, 간격 0.07~0.08 — 고르지 않게)
		-- → 칼 팔을 왼쪽 뒤로 활짝 감아 든 채 숨을 죽였다가(0.58~0.66) → 5타 가장 센 큰 가로 쓸어베기(약 210° 한 번에, 몸째 앞으로 꽂힘) → 여운
		CallistoTrohia = {
			Duration = 1.6,
			Keys = {
				K(0, nil, OBS),
				Roll(0.01, "linear", { Root = { 0, -0.03, 0, 0, 23.2, 0 }, Torso = { 2.1, 0.7, 0 }, Head = { -5, -18.9, 5 }, RArm = { 17, 78.8, 45.3 }, LArm = { 46.9, 8.4, -6.6 }, RLeg = { 9, 0, 4.6 }, LLeg = { -6.6, 0, -4.6 } }),
				Roll(0.05, "linear", { Root = { 0, -0.13, 0, 0, 33.2, 0 }, Torso = { -3.9, 21.7, 0 }, Head = { -2, -27.9, 2 }, RArm = { 25.3, 138.8, 77.8 }, LArm = { 30.9, 3.4, -14.6 }, RLeg = { 12, 0, 6.6 }, LLeg = { -8.6, 0, -6.6 } }),
				K(0.12, "quadOut", { Root = { 0, -0.2, 0, 0, 40, 0 }, Torso = { -8, 36, 0 }, Head = { 0, -34, 0 }, RArm = { 7, 176, 89.9 }, LArm = { 20, 0, -20 }, RLeg = { 14, 0, 8 }, LLeg = { -10, 0, -8 } }),
				K(0.16, nil, { Root = { 0, -0.2, 0, 0, 40, 0 }, Torso = { -8, 36, 0 }, Head = { 0, -34, 0 }, RArm = { 7, 182, 90.1 }, LArm = { 20, 0, -20 }, RLeg = { 14, 0, 8 }, LLeg = { -10, 0, -8 } }),
				K(0.22, "expoOut", { Root = { 0, -0.25, -0.1, 0, -10, 0 }, Torso = { -6, -24, 0 }, Head = { 4, 18, 0 }, RArm = { 5, 28, 90 }, LArm = { 34, 0, -40 }, RLeg = { 24, 0, 8 }, LLeg = { -18, 0, -8 } }),
				K(0.29, "expoOut", { Root = { 0, -0.25, -0.15, 0, 16, 0 }, Torso = { -6, 26, 0 }, Head = { 0, -20, 0 }, RArm = { 5, 156, 90 }, LArm = { 20, 0, -20 }, RLeg = { 14, 0, 8 }, LLeg = { -10, 0, -8 } }),
				K(0.37, "expoOut", { Root = { 0, -0.3, -0.25, 0, -26, 0 }, Torso = { -10, -36, 0 }, Head = { 4, 18, 0 }, RArm = { 7, 10, 90.3 }, LArm = { 34, 0, -40 }, RLeg = { 24, 0, 8 }, LLeg = { -18, 0, -8 } }),
				K(0.45, "expoOut", { Root = { 0, -0.3, -0.3, 0, 38, 0 }, Torso = { -10, 40, 0 }, Head = { 0, -34, 0 }, RArm = { 3, 178, 90.1 }, LArm = { 20, 0, -20 }, RLeg = { 14, 0, 8 }, LLeg = { -10, 0, -8 } }),
				K(0.58, "sineOut", { Root = { 0, -0.1, 0.2, 0, 56, 0 }, Torso = { 8, 46, 0 }, Head = { 0, -34, 0 }, RArm = { 3.2, 207.9, 89.1 }, LArm = { 40, 0, -30 }, RLeg = { -12, 0, 8 }, LLeg = { 20, 0, -8 } }),
				K(0.66, nil, { Root = { 0, -0.15, 0.25, 0, 62, 0 }, Torso = { 10, 52, 0 }, Head = { 0, -34, 0 }, RArm = { 1.8, 215.9, 87.6 }, LArm = { 40, 0, -30 }, RLeg = { -12, 0, 8 }, LLeg = { 20, 0, -8 } }),
				Roll(0.667, "linear", { Root = { 0, -0.31, -0.2, 0, 10.2, 0 }, Torso = { -2.7, 5.6, 0 }, Head = { 3.6, -5.8, 0 }, RArm = { 4.1, 115.2, 92 }, LArm = { 30.9, 0, -36.4 }, RLeg = { 13.5, 0, 8 }, LLeg = { -4.6, 0, -8 } }),
				K(0.74, "expoOut", { Root = { 0, -0.5, -0.75, 0, -52, 0 }, Torso = { -18, -50, 0 }, Head = { 8, 28, 0 }, RArm = { 5, -6, 90 }, LArm = { 20, 0, -44 }, RLeg = { 44, 0, 8 }, LLeg = { -34, 0, -8 } }),
				K(0.86, "backOut", { Root = { 0, -0.6, -0.8, 0, -58, 0 }, Torso = { -22, -56, 0 }, Head = { 8, 28, 0 }, RArm = { 5, -22, 90 }, LArm = { 20, 0, -44 }, RLeg = { 44, 0, 8 }, LLeg = { -34, 0, -8 } }),
				K(1, "sineOut", { Root = { 0, -0.5, -0.7, 0, -46, 0 }, Torso = { -18, -50, 0 }, Head = { 8, 28, 0 }, RArm = { 5, -22, 90 }, LArm = { 20, 0, -44 }, RLeg = { 44, 0, 8 }, LLeg = { -34, 0, -8 } }),
				Roll(1.183, "quadIn", { Root = { 0, -0.39, -0.55, 0, -32, 0 }, Torso = { -13.3, -40.7, 0 }, Head = { 5, 18.7, 1.3 }, RArm = { 12.5, -0.7, 90.1 }, LArm = { 26.8, 2.1, -35.5 }, RLeg = { 36.4, 0, 7.2 }, LLeg = { -28.1, 0, -7.2 } }),
				Roll(1.258, "linear", { Root = { 0, -0.3, -0.43, 0, -20.2, 0 }, Torso = { -9.4, -32.8, 0 }, Head = { 2.5, 10.8, 2.3 }, RArm = { 23, 13.8, 83.9 }, LArm = { 32.5, 3.9, -28.4 }, RLeg = { 29.9, 0, 6.4 }, LLeg = { -23.1, 0, -6.4 } }),
				Roll(1.3, "linear", { Root = { 0, -0.25, -0.35, 0, -13, 0 }, Torso = { -7, -28, 0 }, Head = { 1, 6, 3 }, RArm = { 28.1, 19.5, 77 }, LArm = { 36, 5, -24 }, RLeg = { 26, 0, 6 }, LLeg = { -20, 0, -6 } }),
				K(1.6, "sineOut", OBS),
			},
			Events = {
				{ t = 0, k = "Dash", to = "Target", gap = 3.2, d = 0.14 },
				{ t = 0.13, k = "Trail", on = true, slot = "W" },
				{ t = 0.2, k = "Fx", n = "BladeArc", style = "Back", sz = 0.7 },
				{ t = 0.2, k = "Hit", i = 1 },
				{ t = 0.2, k = "Shake", a = 0.08, d = 0.05 },
				{ t = 0.27, k = "Fx", n = "BladeArc", style = "Back", sz = 0.7, flip = true },
				{ t = 0.27, k = "Hit", i = 2 },
				{ t = 0.27, k = "Shake", a = 0.08, d = 0.05 },
				{ t = 0.35, k = "Fx", n = "BladeArc", style = "Back", sz = 0.95 },
				{ t = 0.35, k = "Hit", i = 3 },
				{ t = 0.35, k = "Shake", a = 0.14, d = 0.07 },
				{ t = 0.35, k = "Stop", d = 0.02 },
				{ t = 0.43, k = "Fx", n = "BladeArc", style = "Back", sz = 0.95, flip = true },
				{ t = 0.43, k = "Hit", i = 4 },
				{ t = 0.43, k = "Shake", a = 0.14, d = 0.07 },
				{ t = 0.43, k = "Stop", d = 0.02 },
				{ t = 0.5, k = "Trail", on = false, slot = "W" },
				{ t = 0.6, k = "Fx", n = "SlashGlint" },
				{ t = 0.67, k = "Trail", on = true, slot = "W" },
				{ t = 0.72, k = "Fx", n = "BladeArc", style = "Back", sz = 1.5 },
				{ t = 0.72, k = "Hit", i = 5 },
				{ t = 0.72, k = "Fx", n = "BurnSlash" },
				{ t = 0.72, k = "Shake", a = 0.34, d = 0.16 },
				{ t = 0.72, k = "Stop", d = 0.07 },
				{ t = 0.92, k = "Trail", on = false, slot = "W" },
				{ t = 1.1, k = "Dash", to = "Home", d = 0.3 },
			},
		},
		-- 2-2 심베라즈마: 멱살을 잡아(왼손) 들어 올리고 → 손목 카메라가 얼굴 바로 앞 — 찰칵 → 몸을 감았다가 내던진다(회피 불가)
		CallistoSymberasma = {
			Duration = 1.95,
			Keys = {
				K(0, nil, OBS),
				K(0.22, "expoOut", GRAB),
				K(0.5, "sineOut", LIFT),
				K(0.72, nil, LIFT, { Head = { 10, 28, 8 } }),
				K(0.76, "expoOut", LIFT, { LArm = { 130, 0, 4 }, Torso = { 12, -12, 0 } }),
				K(1.0, "sineIn", WIND),
				K(1.14, "expoOut", THROW),
				K(1.4, "sineOut", THROW, { Torso = { -12, -44, 0 } }),
				K(1.95, "sineInOut", OBS),
			},
			Events = {
				{ t = 0.04, k = "Dash", to = "Target", gap = 1.4, d = 0.2 },
				{ t = 0.22, k = "Fx", n = "Grab" },
				{ t = 0.6, k = "Fx", n = "Focus" },
				{ t = 0.75, k = "Fx", n = "Flash" },
				{ t = 1.14, k = "Hit", i = 1 },
				{ t = 1.14, k = "Fx", n = "Throw" },
				{ t = 1.14, k = "Shake", a = 0.38, d = 0.2 },
				{ t = 1.42, k = "Dash", to = "Home", d = 0.34 },
			},
		},
		-- 3-1 신데시 톤 아스트론(2026-11-06 QTE 1개 안 3비트 — Hit 1·2·3): 손이 칼날 — 약(짧게 쏘는 첫 찌름 0.36) · 중(당겼다 찌름 0.68) · 강(몸째 크게 뒤로 감았다 어깨째 꿰뚫음 1.0 — 셋째가 가장 세다)
		CallistoSynthesis = {
			Duration = 1.64,
			Keys = {
				K(0, nil, OBS),
				Roll(0.006, "linear", { Root = { 0, -0.01, 0.02, 0, 17.9, 0 }, Torso = { 4.1, -6.9, 0 }, Head = { -5.7, -14, 5.7 }, RArm = { 35.6, -58.3, -26.4 }, LArm = { 52.3, 9.6, -5.1 }, RLeg = { 7.1, 0, 4.2 }, LLeg = { -4.9, 0, -4.2 } }),
				Roll(0.01, "linear", { Root = { 0, -0.02, 0.04, 0, 16.4, 0 }, Torso = { 4.1, -7.4, 0 }, Head = { -5.6, -12.7, 5.6 }, RArm = { 20.9, -84.6, -40.2 }, LArm = { 52.6, 9.3, -5.9 }, RLeg = { 6.6, 0, 4.3 }, LLeg = { -4.1, 0, -4.3 } }),
				K(0.22, "sineOut", DRAW, { RArm = { 21.3, -101.8, -83.7 } }),
				K(0.3, nil, DRAW, { RArm = { 16.4, -102.4, -83.9 }, Root = { 0, -0.28, 0.6, 0, -34, 0 } }),
				K(0.36, "expoOut", THRUST, { RArm = { 3.4, -84.2, -94 }, Root = { 0, -0.3, -0.45, 0, 4, 0 }, Torso = { -8, 10, 0 }, RLeg = { 30, 0, 6 }, LLeg = { -22, 0, -6 } }),
				K(0.52, "quadOut", DRAW, { RArm = { 18, -96, -86 }, Root = { 0, -0.2, 0.25, 0, -16, 0 } }),
				K(0.6, nil, DRAW, { RArm = { 16.4, -102.4, -83.9 }, Root = { 0, -0.24, 0.4, 0, -24, 0 } }),
				K(0.68, "expoOut", THRUST, { RArm = { 3.4, -84.2, -94 }, Root = { 0, -0.4, -0.62, 0, 12, 0 }, Torso = { -12, 18, 0 } }),
				K(0.82, "sineOut", DRAW, { RArm = { 16.4, -102.4, -83.9 }, Root = { 0, -0.28, 0.6, 0, -34, 0 } }),
				K(0.93, nil, DRAW, { RArm = { 16.4, -102.4, -83.9 }, Root = { 0, -0.3, 0.64, 0, -36, 0 } }),
				K(1, "expoOut", THRUST, { RArm = { 3.4, -84.2, -94 } }),
				K(1.1, "backOut", THRUST, { RArm = { 3.4, -84.2, -94 }, Root = { 0, -0.48, -0.85, 0, 20, 0 } }),
				K(1.3, "sineInOut", THRUST, { RArm = { 3.4, -84.2, -94 }, Torso = { -10, 16, 0 }, Root = { 0, -0.4, -0.6, 0, 14, 0 } }),
				Roll(1.407, "quadIn", { Root = { 0, -0.31, -0.46, 0, 15.4, 0 }, Torso = { -6.8, 11, 0 }, Head = { 6.4, -19.1, 1.4 }, RArm = { 22, -84.7, -81.2 }, LArm = { -6.9, 2.3, -14.8 }, RLeg = { 40.5, 0, 5.5 }, LLeg = { -30.8, 0, -5.5 } }),
				Roll(1.469, "linear", { Root = { 0, -0.2, -0.3, 0, 17, 0 }, Torso = { -3.1, 5.1, 0 }, Head = { 2.1, -18, 3 }, RArm = { 42.8, -70.4, -58.3 }, LArm = { 13.6, 5, -11.1 }, RLeg = { 29.2, 0, 5 }, LLeg = { -22.1, 0, -5 } }),
				Roll(1.473, "linear", { Root = { 0, -0.19, -0.29, 0, 17.1, 0 }, Torso = { -2.8, 4.7, 0 }, Head = { 1.8, -17.9, 3.1 }, RArm = { 43.9, -68.6, -56.1 }, LArm = { 15.1, 5.1, -10.8 }, RLeg = { 28.4, 0, 5 }, LLeg = { -21.6, 0, -5 } }),
				Roll(1.475, "linear", { Root = { 0, -0.19, -0.29, 0, 17.1, 0 }, Torso = { -2.7, 4.5, 0 }, Head = { 1.6, -17.9, 3.1 }, RArm = { 44.5, -67.5, -54.9 }, LArm = { 15.8, 5.2, -10.7 }, RLeg = { 28, 0, 5 }, LLeg = { -21.3, 0, -5 } }),
				Roll(1.538, "linear", { Root = { 0, -0.08, -0.12, 0, 18.8, 0 }, Torso = { 1.1, -1.5, 0 }, Head = { -2.7, -16.8, 4.8 }, RArm = { 50.2, -28.4, -13.9 }, LArm = { 36.3, 7.9, -6.9 }, RLeg = { 16.7, 0, 4.4 }, LLeg = { -12.6, 0, -4.4 } }),
				K(1.64, "quadOut", OBS),
			},
			Events = {
				{ t = 0.04, k = "Dash", to = "Target", gap = 4.0, d = 0.2 },
				{ t = 0.24, k = "Fx", n = "SlashGlint" },
				{ t = 0.34, k = "Fx", n = "Stab", s = 1 },
				{ t = 0.36, k = "Hit", i = 1 },
				{ t = 0.36, k = "Shake", a = 0.12, d = 0.08 },
				{ t = 0.36, k = "Stop", d = 0.02 },
				{ t = 0.66, k = "Fx", n = "Stab", s = 2 },
				{ t = 0.68, k = "Hit", i = 2 },
				{ t = 0.68, k = "Shake", a = 0.18, d = 0.1 },
				{ t = 0.68, k = "Stop", d = 0.03 },
				{ t = 0.8, k = "Fx", n = "SlashGlint" },
				{ t = 0.98, k = "Fx", n = "Stab", s = 3 },
				{ t = 1, k = "Hit", i = 3 },
				{ t = 1, k = "Shake", a = 0.32, d = 0.16 },
				{ t = 1, k = "Stop", d = 0.07 },
				{ t = 1.28, k = "Dash", to = "Home", d = 0.28 },
			},
		},
		-- 3-2 미크리 아르크토스 하라시: 뒤로 물러서 손목 카메라를 겨누고 → 렌즈에 별빛이 빨려 들며 팔이 떨리는 동안 버팀
		-- → 쏘는 순간 반동으로 미끄러진다(아군 칸 전부를 태움 — 막기만)
		CallistoArktos = {
			Duration = 2.3,
			Keys = {
				K(0, nil, OBS),
				K(0.32, "sineOut", AIM_EYE, { Root = { 0, -0.12, 0.8, 0, -30, 0 }, RArm = { 30, 0, 40 }, RLeg = { 14, 0, 8 }, LLeg = { -14, 0, -8 } }),
				K(0.6, nil, AIM_EYE, { Root = { 0, -0.18, 0.82, 0, -30, 0 }, RArm = { 34, 0, 44 }, LArm = { 90, 1, 0 }, RLeg = { 14, 0, 8 }, LLeg = { -14, 0, -8 } }),
				K(0.75, "sineInOut", AIM_EYE, { Root = { 0, -0.2, 0.82, 0, -30, 0 }, RArm = { 34, 0, 44 }, LArm = { 91, -1, 0 }, RLeg = { 14, 0, 8 }, LLeg = { -14, 0, -8 } }),
				K(0.9, "sineInOut", AIM_EYE, { Root = { 0, -0.22, 0.82, 0, -30, 0 }, RArm = { 34, 0, 44 }, LArm = { 90, 1.5, 0 }, RLeg = { 16, 0, 8 }, LLeg = { -16, 0, -8 } }),
				K(1.04, "sineInOut", AIM_EYE, { Root = { 0, -0.24, 0.82, 0, -30, 0 }, RArm = { 34, 0, 44 }, LArm = { 90.5, -1.5, 0 }, RLeg = { 16, 0, 8 }, LLeg = { -16, 0, -8 } }),
				K(1.12, "expoOut", AIM_EYE, { Root = { 0, -0.15, 1.35, 0, -30, 0 }, LArm = { 102, 0, 0 }, Torso = { 14, -22, 0 }, RArm = { 40, 0, 50 } }),
				K(1.6, "sineOut", AIM, { Root = { 0, -0.1, 1.2, 0, -30, 0 }, LArm = { 86, 0, -4 } }),
				K(2.3, "sineInOut", OBS),
			},
			Events = {
				{ t = 0.34, k = "Fx", n = "LensCharge" },
				{ t = 1.1, k = "Fx", n = "LensBurn" },
				{ t = 1.13, k = "Hit", i = 1 },
				{ t = 1.12, k = "Shake", a = 0.6, d = 0.4 },
				{ t = 1.12, k = "Stop", d = 0.05 },
			},
		},
		-- 강화 아스트로 세시(아케인 리니지 블레이드 댄서 칼춤 + 말레니아 물새 춤): 칼 팔을 옆 뒤로 감고 웅크림(신호) → 도약해 잠깐 떠 있다가
		-- → 두 팔을 수평으로 펴고 회전 묶음 셋(묶음 사이 짧은 틈 — 한 묶음 두 바퀴, 내려오며) → 착지와 함께 칼바람 고리(회피 불가)
		CallistoAstro = {
			Duration = 2.35,
			Keys = {
				K(0, nil, OBS),
				Roll(0.01, "linear", { Root = { 0, -0.05, 0.02, 0, 17, 0 }, Torso = { 2.2, -6.8, 0 }, Head = { -4.3, -13.8, 5.6 }, RArm = { 10.9, 53.3, 40.8 }, LArm = { 51.3, 9.4, -6.8 }, RLeg = { 11.1, 0, 4.4 }, LLeg = { -6.2, 0, -4.4 } }),
				K(0.26, "sineOut", CROUCH, { RArm = { -14.2, 8.7, 79.3 } }),
				K(0.4, nil, CROUCH, { Root = { 0, -0.85, 0.4, 0, -34, 0 } }),
				Roll(0.402, "linear", { Root = { 0, -0.56, 0.29, 0, -34.7, 0 }, Torso = { -22.3, -20, 0 }, Head = { 18.9, 20, 0 }, RArm = { 43.1, 0, 76 }, LArm = { 42.2, 0, -51.1 }, RLeg = { 58.9, 0, 9.8 }, LLeg = { -12.2, 0, -9.8 } }),
				K(0.52, "expoOut", LEAP),
				K(0.62, nil, LEAP, { Root = { 0, 2.0, -0.6, 0, -40, 0 } }),
				Roll(0.656, "quadIn", { Root = { 0, 1.89, -0.53, 0, -40, 0 }, Torso = { 3, -12.8, 0 }, Head = { -3.8, 12.8, 0 }, RArm = { 109.8, 11.8, 83.1 }, LArm = { 39.8, 0, -71.5 }, RLeg = { 33.4, 0, 8.7 }, LLeg = { -20.6, 0, -8.7 } }),
				Roll(0.669, "linear", { Root = { 0, 1.8, -0.47, 0, -40, 0 }, Torso = { -1.3, -6.7, 0 }, Head = { -2, 6.7, 0 }, RArm = { 75.1, -13.3, 69.2 }, LArm = { 22.7, 0, -81.3 }, RLeg = { 19.3, 0, 9.3 }, LLeg = { -12.7, 0, -9.3 } }),
				K(0.68, "linear", SPIN, { RArm = { 39, 1.5, 92.6 }, Root = { 0, 1.7, -0.4, 0, -40, 0 } }),
				Roll(0.683, "quadIn", { Root = { 0, 1.7, -0.4, 0, -39.7, 0 }, Torso = { -6, 0, 0 }, Head = { 0, 0, 0 }, RArm = { 4, 0, 92 }, LArm = { 4, 0, -92 }, RLeg = { 4, 0, 10 }, LLeg = { -4, 0, -10 } }),
				K(0.92, "sineInOut", SPIN, { Root = { 0, 1.3, -0.3, 0, 680, 0 } }),
				K(1.0, "sineOut", SPIN, { Root = { 0, 1.2, -0.3, 0, 700, 0 }, Torso = { -10, 0, 0 } }),
				K(1.04, "quadIn", SPIN, { Root = { 0, 1.1, -0.2, 0, 720, 0 } }),
				K(1.26, nil, SPIN, { Root = { 0, 0.6, -0.1, 0, 1400, 0 } }),
				K(1.32, "sineOut", SPIN, { Root = { 0, 0.5, -0.1, 0, 1420, 0 }, Torso = { -12, 0, 0 } }),
				K(1.36, "quadIn", SPIN, { Root = { 0, 0.4, 0, 0, 1440, 0 } }),
				K(1.62, nil, SPIN, { Root = { 0, -0.3, 0, 0, 2140, 0 } }),
				K(1.74, "expoOut", CROUCH, { Root = { 0, -0.7, 0, 0, 2160, 0 }, RArm = { -34.9, 4.4, 85.8 }, LArm = { 30, 0, -86 } }),
				Roll(2.075, "sineIn", { Root = { 0, -0.3, 0, 0, 2171.5, 0 }, Torso = { -8.7, -11.9, 0 }, Head = { 5.8, -0.8, 3.5 }, RArm = { -14.9, 43, 52.3 }, LArm = { 42.7, 5.8, -38.7 }, RLeg = { 30, 0, 6.5 }, LLeg = { -7.7, 0, -6.5 } }),
				Roll(2.25, "linear", { Root = { 0, -0.05, 0, 0, 2178.7, 0 }, Torso = { 2.1, -6.9, 0 }, Head = { -4.2, -13.7, 5.6 }, RArm = { 3.8, 60.4, 42.1 }, LArm = { 50.6, 9.4, -9.3 }, RLeg = { 11.4, 0, 4.4 }, LLeg = { -6.3, 0, -4.4 } }),
				Roll(2.285, "linear", { Root = { 0, -0.02, 0, 0, 2179.4, 0 }, Torso = { 3.2, -6.4, 0 }, Head = { -5.2, -15, 5.8 }, RArm = { 28.9, 30.3, 31.5 }, LArm = { 51.4, 9.7, -6.3 }, RLeg = { 9.4, 0, 4.2 }, LLeg = { -6.1, 0, -4.2 } }),
				K(2.35, "quadOut", OBS, { Root = { 0, 0, 0, 0, 2180, 0 } }),
			},
			Events = {
				{ t = 0.04, k = "Dash", to = "Target", gap = 2.2, d = 0.3 },
				{ t = 0.3, k = "Fx", n = "SlashGlint" },
				{ t = 0.52, k = "Fx", n = "LeapDust" },
				{ t = 0.68, k = "Trail", on = true, slot = "W" },
				{ t = 0.68, k = "Fx", n = "BladeStorm" },
				{ t = 1.1, k = "Hit", i = 1 },
				{ t = 1.1, k = "Shake", a = 0.5, d = 0.5 },
				{ t = 1.62, k = "Trail", on = false, slot = "W" },
				{ t = 1.66, k = "Fx", n = "StormEnd" },
				{ t = 1.66, k = "Shake", a = 0.35, d = 0.2 },
				{ t = 1.85, k = "Dash", to = "Home", d = 0.36 },
			},
		},

		--=== 등장 · 페이즈 전환(전투 화면이 튼다) ===--
		-- 등장(2026-11-01 사용자 사양): 마주 본 채 왼발 클로즈업 → 카메라가 왼쪽 위로 올라가며, 의수 칼날이 잘 나오는지 시험하는 모습
		-- (팔을 들어 보고 → 날이 미끄러져 나옴 → 손목을 비틀어 날을 봄 → 허공을 한 번 그음) → 날을 다시 넣고 전투 시작
		CallistoIntro = {
			Duration = 4.6,
			Keys = {
				K(0, nil, OBS),
				K(1.2, nil, OBS),
				K(1.6, "sineOut", OBS, { Torso = { 0, 12, 0 }, Head = { -14, 26, 0 }, RArm = { 82, 0, -34 } }),
				Roll(1.858, "sineIn", { Root = { 0, 0, 0, 0, 20, 0 }, Torso = { 0, 12, 0 }, Head = { -15.1, 27.1, 0 }, RArm = { 69.6, -40.9, -73.1 }, LArm = { 52, 10, -4 }, RLeg = { 8, 0, 4 }, LLeg = { -6, 0, -4 } }),
				K(2.1, "sineOut", OBS, { Torso = { 0, 12, 0 }, Head = { -16, 28, 0 }, RArm = { 56.5, -50.1, -80.8 } }),
				K(2.45, "sineInOut", OBS, { Torso = { 0, 14, 0 }, Head = { -12, 30, 4 }, RArm = { 45, -64, -90 } }),
				K(2.75, "sineInOut", OBS, { Torso = { 0, 10, 0 }, Head = { -12, 26, 0 }, RArm = { -0.5, -53.9, -85.1 } }),
				K(3.0, "expoOut", OBS, { Root = { 0, -0.1, 0, 0, -10, 0 }, Torso = { -4, -16, 0 }, Head = { -6, 10, 0 }, RArm = { -1.3, -136.1, -94.2 } }),
				K(3.25, "sineOut", OBS, { Torso = { 0, 6, 0 }, Head = { -10, 18, 0 }, RArm = { 1.2, -79.6, -80.2 } }),
				Roll(3.379, "quadIn", { Root = { 0, 0, 0, 0, 20, 0 }, Torso = { 0.6, 4.1, 0 }, Head = { -9.1, 16.1, 0 }, RArm = { 14.1, -78.5, -75 }, LArm = { 52, 10, -4 }, RLeg = { 8, 0, 4 }, LLeg = { -6, 0, -4 } }),
				Roll(3.421, "linear", { Root = { 0, 0, 0, 0, 20, 0 }, Torso = { 1, 2.9, 0 }, Head = { -8.4, 14.9, 0 }, RArm = { 26.2, -74.8, -70.1 }, LArm = { 52, 10, -4 }, RLeg = { 8, 0, 4 }, LLeg = { -6, 0, -4 } }),
				Roll(3.442, "linear", { Root = { 0, 0, 0, 0, 20, 0 }, Torso = { 1.3, 2.1, 0 }, Head = { -8.1, 14.1, 0 }, RArm = { 31.5, -72.2, -66.8 }, LArm = { 52, 10, -4 }, RLeg = { 8, 0, 4 }, LLeg = { -6, 0, -4 } }),
				K(3.75, "sineOut", OBS, { Head = { -4, 6, 0 }, RArm = { 50, 0, 6 } }),
				K(4.6, "sineInOut", OBS),
			},
			Events = {
				{ t = 0, k = "Fx", n = "IntroShot", d = 4.6 },
				{ t = 1.75, k = "Fx", n = "BladeOut" },
				{ t = 2.9, k = "Trail", on = true, slot = "W" },
				{ t = 3.15, k = "Trail", on = false, slot = "W" },
				{ t = 3.45, k = "Fx", n = "BladeIn" },
			},
		},
		-- 2페이즈(2026-11-01): 의수 팔을 크게 휘두르면 주변이 우주로 바뀌며 빠르게 돌다 느려지고, 팔 검이 부서져 우주를 담은 팔이 채운다.
		-- 얼굴도 우주로. 하늘에서 별빛이 모여 북두칠성 망치가 손에 맺히고 어깨에 멘다
		CallistoPhase2 = M({
			Duration = 4.6,
			Keys = {
				K(0, nil, OBS),
				K(0.7, "sineIn", OBS, { Root = { 0, -0.2, 0, 0, 30, 0 }, Torso = { -6, 34, 0 }, Head = { 0, -26, 0 }, RArm = { 70, 0, -72 }, LArm = { 24, 0, -20 }, RLeg = { 12, 0, 8 }, LLeg = { -10, 0, -8 } }),
				K(1.0, "expoOut", OBS, { Root = { 0, -0.3, 0, 0, -26, 0 }, Torso = { -10, -38, 0 }, Head = { 6, 18, 0 }, RArm = { 92, 0, 96 }, LArm = { 30, 0, -40 }, RLeg = { 22, 0, 8 }, LLeg = { -18, 0, -8 } }),
				K(1.8, nil, OBS, { Root = { 0, -0.25, 0, 0, -22, 0 }, Torso = { -8, -32, 0 }, Head = { 10, 14, 0 }, RArm = { 90, 0, 92 }, LArm = { 30, 0, -38 } }),
				K(2.8, "sineInOut", OBS, { Root = { 0, 0.15, 0, 0, 0, 0 }, Torso = { 10, 0, 0 }, Head = { 24, 0, 0 }, RArm = { 50, 0, 44 }, LArm = { 50, 0, -44 } }),
				K(3.6, "sineInOut", HSKY),
				K(3.95, nil, HSKY, { Head = { 32, 0, 0 } }),
				K(4.25, "sineInOut", HPOP),
				K(4.6, "sineInOut", HOBS),
			},
			Events = {
				{ t = 0, k = "Fx", n = "PhaseShot", d = 4.6, p = 2 },
				{ t = 1.0, k = "Fx", n = "PhaseTwo" },
				{ t = 1.0, k = "Shake", a = 0.5, d = 0.6 },
				{ t = 3.6, k = "Fx", n = "PageBurst" },
			},
		}),
		-- 3페이즈(2026-11-01): 망치를 하늘로 곧추세우자 옷이 모두 사라지며 우주 몸만 남고(등 뒤 일식 후광 · 검은 띠 팔이 펼쳐짐),
		-- 우주의 회전이 점점 빨라지고, 우리은하가 전투 필드 아래에 생겨난다
		CallistoPhase3 = M({
			Duration = 4.8,
			Keys = {
				K(0, nil, HOBS),
				K(0.25, "quadOut", HPOP),
				K(0.8, "sineOut", HSKY, { Root = { 0, 0.4, 0, 0, 0, 0 } }),
				K(2.2, nil, HSKY, { Root = { 0, 0.55, 0, 0, 0, 0 }, Head = { 34, 0, 0 } }),
				K(3.6, "sineInOut", HREADY, { Root = { 0, 0.1, 0.1, 0, 30, 0 } }),
				K(4.3, "sineInOut", HPOP),
				K(4.8, "sineInOut", HOBS),
			},
			Events = {
				{ t = 0, k = "Fx", n = "PhaseShot", d = 4.8, p = 3 },
				{ t = 0.8, k = "Fx", n = "PhaseThree" },
				{ t = 2.0, k = "Fx", n = "SpinUp" },
				{ t = 2.4, k = "Fx", n = "GalaxyRise" },
			},
		}),
		-- 페이즈 전환(옛 컷신 — 시험용으로 남김): 무릎을 꿇었다가 별을 올려다보고, 두 팔을 펴며 일어서 별빛이 터진다
		CallistoPageShift = {
			Duration = 2.7,
			Keys = {
				K(0, nil, OBS),
				K(0.35, "expoOut", OBS, { Root = { 0, -1.3, 0.2, 0, 20, 0 }, Torso = { -20, 0, 0 }, Head = { -24, 0, 0 }, RLeg = { 88, 0, 6 }, LLeg = { -8, 0, -6 }, RArm = { 12, 0, 16 }, LArm = { 20, 0, -16 } }),
				K(1.3, "sineInOut", OBS, { Root = { 0, -1.3, 0.2, 0, 20, 0 }, Torso = { 10, 0, 0 }, Head = { 32, 0, 0 }, RLeg = { 88, 0, 6 }, LLeg = { -8, 0, -6 }, RArm = { 40, 0, 30 }, LArm = { 110, 0, -10 } }),
				K(1.95, "sineOut", OBS, { Root = { 0, 0.4, 0, 0, 0, 0 }, Torso = { 12, 0, 0 }, Head = { 20, 0, 0 }, RArm = { 140, 0, 50 }, LArm = { 140, 0, -50 }, RLeg = { 0, 0, 4 }, LLeg = { 0, 0, -4 } }),
				K(2.7, "sineInOut", OBS),
			},
			Events = {
				{ t = 0, k = "Fx", n = "PageShot", d = 2.7 },
				{ t = 1.9, k = "Fx", n = "PageBurst" },
				{ t = 1.9, k = "Shake", a = 0.4, d = 0.4 },
			},
		},

		--=== 2페이즈 성위 품은 자(북두칠성 망치) ===--
		-- 평타 수많은 성위 아래 파묻혀: 다가가며 어깨의 망치를 두 손으로 머리 위로(국자 별이 밝아짐) → 꼭대기에서 짧게 멈춤
		-- → 가속하며 내려찍는다(땅이 갈라지고 금빛 고리) → 망치를 뽑아 다시 어깨에
		CallistoBuried = M({
			Duration = 1.4,
			Keys = {
				K(0, nil, HOBS),
				K(0.1, "quadOut", HPOP),
				K(0.3, "sineOut", HRAISE),
				K(0.38, nil, HRAISE, { Torso = { 16, 6, 0 }, Root = { 0, -0.05, 0.3, 0, 10, 0 } }),
				K(0.46, "quadIn", HSMASH),
				K(0.6, "sineOut", HSMASH, { Root = { 0, -0.7, -0.45, 0, 6, 0 }, Torso = { -28, 0, 0 } }),
				K(0.92, "sineInOut", HREADY),
				K(1.14, "sineInOut", HPOP),
				K(1.4, "sineInOut", HOBS),
			},
			Events = {
				{ t = 0.04, k = "Dash", to = "Target", gap = 3.8, d = 0.26 },
				{ t = 0.22, k = "Fx", n = "HammerGlow" },
				{ t = 0.34, k = "Trail", on = true, slot = "W" },
				{ t = 0.45, k = "Fx", n = "HammerSmash" },
				{ t = 0.46, k = "Hit", i = 1 },
				{ t = 0.46, k = "Shake", a = 0.36, d = 0.16 },
				{ t = 0.46, k = "Stop", d = 0.06 },
				{ t = 0.56, k = "Trail", on = false, slot = "W" },
				{ t = 0.95, k = "Dash", to = "Home", d = 0.32 },
			},
		}),
		-- 알리오스: 제자리에서 살짝 뛰어 망치를 머리 위로 → 온몸으로 땅을 내려찍어 아군 필드로 금빛 장판이 물결처럼 번진다 → 누른 채 버팀
		CallistoAlioth = M({
			Duration = 1.9,
			Keys = {
				K(0, nil, HOBS),
				K(0.14, "quadOut", HPOP),
				K(0.4, "sineOut", HRAISE, { Root = { 0, 0.55, 0.2, 0, 10, 0 } }),
				K(0.54, nil, HRAISE, { Root = { 0, 0.65, 0.2, 0, 10, 0 }, Torso = { 16, 6, 0 } }),
				K(0.66, "quadIn", HSMASH, { Root = { 0, -0.75, -0.45, 0, 6, 0 } }),
				K(1.25, nil, HSMASH, { Root = { 0, -0.72, -0.45, 0, 6, 0 }, Torso = { -28, 0, 0 } }),
				K(1.58, "sineInOut", HPOP),
				K(1.9, "sineInOut", HOBS),
			},
			Events = {
				{ t = 0.25, k = "Fx", n = "HammerGlow" },
				{ t = 0.4, k = "Trail", on = true, slot = "W" },
				{ t = 0.66, k = "Fx", n = "AliothField" },
				{ t = 0.68, k = "Hit", i = 1 },
				{ t = 0.66, k = "Shake", a = 0.5, d = 0.3 },
				{ t = 0.66, k = "Stop", d = 0.06 },
				{ t = 0.76, k = "Trail", on = false, slot = "W" },
			},
		}),
		-- 메그레즈: 다가가며 망치를 어깨에서 내려 몸을 오른쪽으로 감고(짧은 멈춤) → 몸을 풀며 가로로 후려친다 → 망치에 끌려 반 바퀴 더
		CallistoMegrez = M({
			Duration = 1.35,
			Keys = {
				K(0, nil, HOBS),
				K(0.28, "sineOut", HCOIL),
				K(0.34, nil, HCOIL, { Root = { 0, -0.32, 0, 0, -46, 0 } }),
				K(0.42, "expoOut", HSWEEP),
				K(0.62, "sineOut", HSWEEP, { Root = { 0, -0.35, -0.25, 0, 44, 0 }, Torso = { -12, 38, 0 } }),
				K(0.9, "sineInOut", HREADY),
				K(1.1, "sineInOut", HPOP),
				K(1.35, "sineInOut", HOBS),
			},
			Events = {
				{ t = 0.04, k = "Dash", to = "Target", gap = 3.6, d = 0.22 },
				{ t = 0.3, k = "Trail", on = true, slot = "W" },
				{ t = 0.37, k = "Fx", n = "MegrezSwing" },
				{ t = 0.39, k = "Hit", i = 1 },
				{ t = 0.39, k = "Shake", a = 0.32, d = 0.14 },
				{ t = 0.39, k = "Stop", d = 0.04 },
				{ t = 0.55, k = "Trail", on = false, slot = "W" },
				{ t = 0.86, k = "Dash", to = "Home", d = 0.3 },
			},
		}),
		-- 성위는 떠돌이, 갈 곳 잃은 아이를 바로잡아(소환): 망치를 하늘로 곧추세우면 국자 별이 밝아지고 미자르 곁의 작은 별(알코르)이
		-- 망치에서 떨어져 나와 적 진영으로 날아가 내려앉는다(공격 아님 — 타격 없음)
		CallistoAlcor = M({
			Duration = 2.0,
			Keys = {
				K(0, nil, HOBS),
				K(0.16, "quadOut", HPOP),
				K(0.55, "sineOut", HSKY),
				K(0.95, nil, HSKY, { Head = { 34, -8, 0 } }),
				K(1.0, "expoOut", HSKY, { Root = { 0, 0.3, 0, 0, 0, 0 }, Torso = { 14, 0, 0 } }),
				K(1.55, "sineInOut", HPOP),
				K(2.0, "sineInOut", HOBS),
			},
			Events = {
				{ t = 0.6, k = "Fx", n = "HammerGlow" },
				{ t = 0.98, k = "Fx", n = "SummonStar" },
			},
		}),
		-- 페크다: 다가가 높이 뛰어올라 망치를 머리 위로(꼭대기에서 멈춤) → 떨어지며 대상이 선 열을 내리찍고 그 열로 별빛 기둥이 차례로 꽂힌다
		CallistoPhecda = M({
			Duration = 1.8,
			Keys = {
				K(0, nil, HOBS),
				K(0.12, "quadOut", HPOP),
				K(0.36, "sineOut", HRAISE, { Root = { 0, 2.6, 0.2, 0, 10, 0 } }),
				K(0.5, nil, HRAISE, { Root = { 0, 2.9, 0.2, 0, 10, 0 }, Torso = { 16, 6, 0 } }),
				K(0.64, "expoIn", HSMASH),
				K(1.0, "sineOut", HSMASH, { Torso = { -30, 0, 0 }, Root = { 0, -0.72, -0.45, 0, 6, 0 } }),
				K(1.3, "sineInOut", HREADY),
				K(1.52, "sineInOut", HPOP),
				K(1.8, "sineInOut", HOBS),
			},
			Events = {
				{ t = 0.04, k = "Dash", to = "Target", gap = 4.4, d = 0.32 },
				{ t = 0.3, k = "Fx", n = "HammerGlow" },
				{ t = 0.36, k = "Trail", on = true, slot = "W" },
				{ t = 0.63, k = "Fx", n = "PhecdaColumn" },
				{ t = 0.65, k = "Hit", i = 1 },
				{ t = 0.64, k = "Shake", a = 0.55, d = 0.3 },
				{ t = 0.65, k = "Stop", d = 0.07 },
				{ t = 0.78, k = "Trail", on = false, slot = "W" },
				{ t = 1.25, k = "Dash", to = "Home", d = 0.36 },
			},
		}),
		-- 메라크: 제자리에서 깊게 몸을 감고(가장 긴 준비) → 온몸을 풀어 가로로 휘두르면 금빛 초승달 충격파가 대상의 행을 쓸고 지나간다(회피 불가)
		CallistoMerak = M({
			Duration = 1.7,
			Keys = {
				K(0, nil, HOBS),
				K(0.46, "sineOut", HCOIL, { Root = { 0, -0.45, 0.15, 0, -60, 0 }, Torso = { -10, -36, 0 } }),
				K(0.54, nil, HCOIL, { Root = { 0, -0.48, 0.18, 0, -64, 0 }, Torso = { -10, -38, 0 } }),
				K(0.62, "expoOut", HSWEEP),
				K(0.92, "sineOut", HSWEEP, { Root = { 0, -0.35, -0.25, 0, 58, 0 }, Torso = { -12, 40, 0 } }),
				K(1.25, "sineInOut", HREADY),
				K(1.47, "sineInOut", HPOP),
				K(1.7, "sineInOut", HOBS),
			},
			Events = {
				{ t = 0.2, k = "Fx", n = "HammerGlow" },
				{ t = 0.5, k = "Trail", on = true, slot = "W" },
				{ t = 0.58, k = "Fx", n = "MerakRow" },
				{ t = 0.62, k = "Hit", i = 1 },
				{ t = 0.6, k = "Shake", a = 0.45, d = 0.25 },
				{ t = 0.75, k = "Trail", on = false, slot = "W" },
			},
		}),
		-- 강화 북두칠성: 망치를 하늘로 곧추세우면 아군 진영 하늘에 일곱 별이 차례로 켜져 북두칠성으로 이어지고 → 높이 뛰어(꼭대기에서 멈춤)
		-- → 떨어지며 내리치는 순간 일곱 별이 아군 칸 전부에 쏟아진다
		-- 조율자 셉텐트리오네스의 강화형(2026-11-07) — 리듬 "따다다다다다다- 쿠구구구구- 콰앙!!!": 하늘의 별 일곱 → 레이저 연사(0.08초 간격) → 모으기·우르릉(0.85초) → 망치 강타.
		-- 시간표 이력: 처음(3.0초) 별 0.25 · 점프 1.25 · 강타 1.6 · Hit 1.64 → 2판(5.3초) 레이저 0.8~2.8 · 강타 3.9 · Hit 3.94 → 지금(3.4초) 레이저 0.6~1.08 · 모으기 1.15 · 강타 2.0 · Hit 2.04
		CallistoDipper = M({
			Duration = 6.0,
			Keys = {
				K(0, nil, HOBS),
				K(0.15, "quadOut", HPOP),
				K(0.45, "sineOut", HSKY),
				K(0.7, nil, HSKY, { Head = { 36, 0, 0 } }),
				K(3.2, nil, HSKY, { Head = { 36, 0, 0 } }),
				K(3.4, "sineOut", HRAISE, { Root = { 0, 3.2, 0.3, 0, 10, 0 } }),
				K(3.6, nil, HRAISE, { Root = { 0, 3.45, 0.3, 0, 10, 0 }, Torso = { 18, 6, 0 } }),
				K(4.55, nil, HRAISE, { Root = { 0, 3.45, 0.3, 0, 10, 0 }, Torso = { 18, 6, 0 } }),
				K(4.72, "expoIn", HSMASH, { Root = { 0, -0.8, -0.5, 0, 6, 0 } }),
				K(5.4, nil, HSMASH, { Root = { 0, -0.76, -0.5, 0, 6, 0 }, Torso = { -30, 0, 0 } }),
				K(5.65, "sineInOut", HPOP),
				K(6.0, "sineInOut", HOBS),
			},
			Events = {
				{ t = 0.15, k = "Fx", n = "Dipper" },
				{ t = 0.4, k = "Fx", n = "HammerGlow" },
				-- 레이저 일곱(가속: 간격 0.45 · 0.30 · 0.20 · 0.08 · 0.06 · 0.05): 별 번호는 하늘 별자리 순서(알카이드 → 두베), hold = 강타(4.7)까지 남은 초
				{ t = 2.3, k = "Fx", n = "DipperLaser", star = 1, nth = 1, hold = 2.4 },
				{ t = 2.75, k = "Fx", n = "DipperLaser", star = 2, nth = 2, hold = 1.95 },
				{ t = 3.05, k = "Fx", n = "DipperLaser", star = 3, nth = 3, hold = 1.65 },
				{ t = 3.25, k = "Fx", n = "DipperLaser", star = 4, nth = 4, hold = 1.45 },
				{ t = 3.33, k = "Fx", n = "DipperLaser", star = 5, nth = 5, hold = 1.37 },
				{ t = 3.39, k = "Fx", n = "DipperLaser", star = 6, nth = 6, hold = 1.31 },
				{ t = 3.44, k = "Fx", n = "DipperLaser", star = 7, nth = 7, hold = 1.26 },
				{ t = 3.25, k = "Fx", n = "DipperGather" },
				{ t = 3.5, k = "Trail", on = true, slot = "W" },
				{ t = 4.7, k = "Fx", n = "DipperCrash" },
				{ t = 4.74, k = "Hit", i = 1 },
				{ t = 4.72, k = "Shake", a = 2.4, d = 0.9 },
				{ t = 4.72, k = "Stop", d = 0.09 },
				{ t = 4.9, k = "Trail", on = false, slot = "W" },
			},
		}),

		--=== 3페이즈 뭇별의 어머니(우주 몸 · 등 뒤 일식 후광 · 같은 북두칠성 망치) ===--
		-- 공명적 성위(평타): 망치를 어깨에서 내려 낮게 → 한 손으로 앞 위로 올려치면 망치 머리에서 별이 튕겨 나가 대상에게 꽂힌다
		CallistoResonance = M({
			Duration = 1.15,
			Keys = {
				K(0, nil, HOBS),
				K(0.09, "quadOut", HPOP),
				K(0.26, "sineOut", HREADY),
				K(0.32, nil, HREADY, { Root = { 0, -0.4, 0.12, 0, 34, 0 } }),
				K(0.42, "expoOut", HUPPER),
				K(0.7, "sineOut", HUPPER, { Torso = { 12, -12, 0 }, Root = { 0, 0.1, -0.25, 0, 6, 0 } }),
				K(0.92, "sineInOut", HPOP),
				K(1.15, "sineInOut", HOBS),
			},
			Events = {
				{ t = 0.34, k = "Trail", on = true, slot = "W" },
				{ t = 0.4, k = "Fx", n = "StarBolt" },
				{ t = 0.55, k = "Hit", i = 1 },
				{ t = 0.55, k = "Trail", on = false, slot = "W" },
			},
		}),
		-- 인위적 별자리: 망치는 어깨에 둔 채 왼손으로 허공에 큰곰자리를 한 별씩 찍어 긋고(별마다 손이 잠깐 멈춤) → 주먹을 쥐어 내리꽂으면
		-- 별들이 대상 둘레로 떨어진다
		CallistoArtificial = M({
			Duration = 1.95,
			Keys = {
				K(0, nil, HOBS),
				K(0.25, "sineOut", HOBS, { LArm = { 140, -30, -20 }, Torso = { 4, -14, 0 }, Head = { 14, 10, 0 } }),
				K(0.36, "quadInOut", HOBS, { LArm = { 132, -14, -18 }, Torso = { 4, -14, 0 }, Head = { 14, 12, 0 } }),
				K(0.47, "quadInOut", HOBS, { LArm = { 120, -16, -26 }, Torso = { 4, -12, 0 }, Head = { 12, 14, 0 } }),
				K(0.58, "quadInOut", HOBS, { LArm = { 124, -32, -30 }, Torso = { 4, -12, 0 }, Head = { 12, 12, 0 } }),
				K(0.69, "quadInOut", HOBS, { LArm = { 134, -40, -24 }, Torso = { 4, -14, 0 }, Head = { 14, 10, 0 } }),
				K(0.8, "quadInOut", HOBS, { LArm = { 118, -50, -14 }, Torso = { 4, -16, 0 }, Head = { 12, 8, 0 } }),
				K(0.91, "quadInOut", HOBS, { LArm = { 104, -58, -6 }, Torso = { 4, -18, 0 }, Head = { 10, 6, 0 } }),
				K(1.02, "sineOut", HOBS, { LArm = { 150, -40, -10 }, Torso = { 10, -16, 0 }, Head = { 18, 10, 0 } }),
				K(1.1, "expoOut", HOBS, { LArm = { 62, 0, -10 }, Torso = { -10, -16, 0 }, Head = { 2, 12, 0 }, Root = { 0, -0.1, -0.1, 0, 20, 0 } }),
				K(1.95, "sineInOut", HOBS),
			},
			Events = {
				{ t = 0.25, k = "Fx", n = "Constellation" },
				{ t = 1.12, k = "Hit", i = 1 },
				{ t = 1.12, k = "Shake", a = 0.32, d = 0.2 },
			},
		}),
		-- 쏟아지는 뭇별(2026-11-06 QTE 1개 안 3비트 — Hit 1·2·3): 망치를 하늘로 치켜들어 별을 모으고 → 한 손으로 대상에게 내리그어 별을 쏟는다를 세 번.
		-- 강중약: 약(어깨만 짧게 그음 0.44) · 중(다시 치켜들었다 그음 0.74) · 강(떠올라 온몸을 실어 그음 1.08 — 별이 가장 많다)
		CallistoShower = M({
			Duration = 2.0,
			Keys = {
				K(0, nil, HOBS),
				K(0.1, "quadOut", HPOP),
				K(0.28, "sineOut", HSKY),
				K(0.34, nil, HSKY, { Head = { 30, 0, 0 } }),
				K(0.44, "expoOut", HUPPER, { Torso = { 4, -6, 0 }, Root = { 0, 0.05, -0.1, 0, 10, 0 } }),
				K(0.6, "quadOut", HSKY, { Head = { 24, 0, 0 } }),
				K(0.66, nil, HSKY, { Head = { 30, 0, 0 } }),
				K(0.74, "expoOut", HUPPER),
				K(0.9, "quadOut", HSKY, { Root = { 0, 0.3, 0, 0, 0, 0 }, Head = { 34, 0, 0 } }),
				K(1.0, nil, HSKY, { Root = { 0, 0.5, 0, 0, 0, 0 }, Head = { 36, 0, 0 }, Torso = { 16, 0, 0 } }),
				K(1.08, "expoOut", HUPPER, { Root = { 0, 0.1, -0.45, 0, 6, 0 }, Torso = { 14, -12, 0 } }),
				K(1.45, "sineOut", HUPPER, { Root = { 0, 0, -0.35, 0, 6, 0 }, Torso = { 10, -10, 0 } }),
				K(1.72, "sineInOut", HPOP),
				K(2.0, "sineInOut", HOBS),
			},
			Events = {
				{ t = 0.32, k = "Fx", n = "StarShower", s = 1 },
				{ t = 0.58, k = "Hit", i = 1 },
				{ t = 0.58, k = "Shake", a = 0.1, d = 0.08 },
				{ t = 0.62, k = "Fx", n = "StarShower", s = 2 },
				{ t = 0.9, k = "Hit", i = 2 },
				{ t = 0.9, k = "Shake", a = 0.16, d = 0.1 },
				{ t = 0.96, k = "Fx", n = "StarShower", s = 3 },
				{ t = 1.24, k = "Hit", i = 3 },
				{ t = 1.24, k = "Shake", a = 0.34, d = 0.2 },
				{ t = 1.24, k = "Stop", d = 0.06 },
			},
		}),
		-- 뭇별 아래에 잠기리: 떠올라 망치를 하늘로 곧추세우고(일식 후광이 타오름) → 허공을 내리쳐 하늘을 끌어내린다(장판 10턴, 회피 불가)
		CallistoSubmerge = M({
			Duration = 2.9,
			Keys = {
				K(0, nil, HOBS),
				K(0.3, "quadOut", HPOP),
				K(0.9, "sineOut", HSKY, { Root = { 0, 1.3, 0, 0, 0, 0 } }),
				K(1.55, nil, HSKY, { Root = { 0, 1.55, 0, 0, 0, 0 }, Head = { 36, 0, 0 } }),
				K(1.72, "expoIn", HSMASH, { Root = { 0, 0.6, -0.3, 0, 6, 0 } }),
				K(2.2, nil, HSMASH, { Root = { 0, 0.5, -0.3, 0, 6, 0 }, Torso = { -30, 0, 0 } }),
				K(2.55, "sineInOut", HPOP),
				K(2.9, "sineInOut", HOBS),
			},
			Events = {
				{ t = 0.2, k = "Fx", n = "Submerge" },
				{ t = 1.72, k = "Hit", i = 1 },
				{ t = 1.72, k = "Shake", a = 0.7, d = 0.6 },
				{ t = 1.72, k = "Stop", d = 0.08 },
			},
		}),

		--=== 케노스 아스테리스모스 — WWE 피니셔(2026-11-06 밤, 설계서 B절 · 두 턴 · 모션 이름은 프로그래밍과 계약) ===--
		-- 레퍼런스: WWE 피니셔 연출 — 시그니처 도발(한 팔을 하늘로 · 가리킨 뒤 주먹), 탑로프 엘보 드롭(로프를 밟고 올라 웅크렸다 몸을 던짐), 파워밤(들어 올렸다 내리찍음),
		-- 다이브 도중 끌어내림 → 바닥 쿵 → 어질어질(핀 폴). 3페이즈 몸 그대로(우주 몸 + 망치 — 망치는 내내 어깨에 멘 채, 대기 HOBS 출입).
		-- 높이는 Root Y 를 크게 쓴다(칼춤이 2 까지 — 여기는 8): 웅크린 자세 PERCH 가 판 위 8 스터드.
		-- 박자: 도발은 느린 올림(약) · 가리킴(중) · 주먹과 별 꺼짐(강), 탑로프는 가볍게 세 번 튀어(약중강 높이 2.4 · 5.2 · 8), 다이브는 느린 조준 → 번개 낙하 → 쿵.
		-- 시그니처 도발(1.8): 오른팔 + 망치를 하늘로(별을 부르는 자세, 고개를 천천히 듦) → 고개를 내려 정면으로 노려보며 왼손으로 가리킴 → 주먹을 꼭 쥐면 별 하나가 꺼지고 별들이 술렁인다. 피해 없음
		CallistoKenos = M({
			Duration = 1.8,
			Keys = {
				K(0, nil, HOBS),
				K(0.18, "quadOut", HPOP),
				K(0.55, "sineOut", HPOP, { Head = { 30, -4, 0 }, Torso = { 10, -4, 0 }, LArm = { 40, 0, -20 } }),
				K(0.9, "sineInOut", HPOP, { Head = { -4, -10, 0 }, Torso = { 0, -10, 0 }, LArm = { 92, -8, 0 }, Root = { 0, 0, 0, 0, 12, 0 } }),
				K(1.06, nil, HPOP, { Head = { -6, -10, 0 }, Torso = { 0, -10, 0 }, LArm = { 94, -8, 0 }, Root = { 0, 0, 0, 0, 12, 0 } }),
				K(1.14, "expoOut", HPOP, { Head = { -8, -10, 0 }, Torso = { -8, -12, 0 }, LArm = { 74, -6, 0 }, Root = { 0, -0.1, 0.05, 0, 12, 0 } }),
				K(1.3, "quadInOut", HPOP, { Head = { 10, -14, 4 }, Torso = { 2, -8, 0 }, LArm = { 74, -6, 0 } }),
				K(1.42, "quadInOut", HPOP, { Head = { 10, 8, -4 }, Torso = { 2, -14, 0 }, LArm = { 74, -6, 0 } }),
				K(1.55, "sineInOut", HPOP),
				K(1.8, "sineInOut", HOBS),
			},
			Events = {
				{ t = 0.2, k = "Fx", n = "KenosCall" },
				{ t = 1.14, k = "Fx", n = "KenosSnuff" },
				{ t = 1.24, k = "Fx", n = "KenosMurmur" },
				{ t = 1.14, k = "Shake", a = 0.12, d = 0.15 },
			},
		}),
		-- 탑로프: 별빛 발판 세 개를 가볍게 밟고(점프 셋 — 약중강) 판 뒤쪽 8 스터드 상공으로 올라가 웅크린다. 피해 없음
		CallistoKenosClimb = M({
			Duration = 2.2,
			Keys = {
				K(0, nil, HOBS),
				K(0.16, "quadOut", HOBS, { Root = { 0, -0.5, 0, 0, 20, 0 }, RLeg = { 40, 0, 8 }, LLeg = { -30, 0, -8 }, Torso = { 8, -6, 0 } }),
				K(0.34, "expoOut", HOBS, { Root = { 0, 3.2, 0, 0, 20, 0 }, RLeg = { -8, 0, 6 }, LLeg = { 20, 0, -6 }, LArm = { 120, 6, -14 } }),
				K(0.5, "sineIn", HOBS, { Root = { 0, 2.5, 0, 0, 20, 0 }, RLeg = { 10, 0, 6 }, LLeg = { -4, 0, -6 }, LArm = { 40, 6, -14 } }),
				K(0.62, "quadOut", HOBS, { Root = { 0, 2.0, 0, 0, 20, 0 }, RLeg = { 40, 0, 8 }, LLeg = { -30, 0, -8 }, Torso = { 8, -6, 0 } }),
				K(0.8, "expoOut", HOBS, { Root = { 0, 6.2, 0, 0, 20, 0 }, RLeg = { -10, 0, 6 }, LLeg = { 24, 0, -6 }, LArm = { 140, 6, -18 } }),
				K(0.96, "sineIn", HOBS, { Root = { 0, 5.0, 0, 0, 20, 0 }, RLeg = { 10, 0, 6 }, LLeg = { -4, 0, -6 }, LArm = { 50, 6, -14 } }),
				K(1.08, "quadOut", HOBS, { Root = { 0, 4.5, 0, 0, 20, 0 }, RLeg = { 44, 0, 8 }, LLeg = { -34, 0, -8 }, Torso = { 10, -6, 0 } }),
				K(1.3, "expoOut", HOBS, { Root = { 0, 9.8, 0, 0, 20, 0 }, RLeg = { -12, 0, 6 }, LLeg = { 28, 0, -6 }, LArm = { 160, 6, -20 }, Torso = { 4, -6, 0 } }),
				K(1.62, "sineOut", HOBS, { Root = { 0, 8.2, 0, 0, 20, 0 }, RLeg = { 30, 0, 8 }, LLeg = { -20, 0, -8 }, Torso = { 12, -6, 0 } }),
				K(2.2, "sineInOut", HOBS, { Root = { 0, 7.5, 0, 0, 20, 0 }, RLeg = { 50, 0, 8 }, LLeg = { -36, 0, -8 }, Torso = { 14, -6, 0 }, Head = { -14, -10, 6 } }),
			},
			Events = {
				{ t = 0.12, k = "Fx", n = "KenosStep", h = 2.2, s = 1 },
				{ t = 0.56, k = "Fx", n = "KenosStep", h = 4.6, s = 2 },
				{ t = 1.02, k = "Fx", n = "KenosStep", h = 7.4, s = 3 },
				{ t = 1.5, k = "Fx", n = "KenosCast" },
				{ t = 1.7, k = "Fx", n = "KenosRopes" },
			},
		}),
		-- 상공 대기(루프): 8 스터드 위에서 웅크린 채 판을 내려다본다. 숨 고르듯 몸이 오르내리고 고개가 느리게 훑는다 — 별 일곱 점이 머리 위를 돈다
		CallistoKenosPerch = M({
			Duration = 3.0,
			Loop = true,
			Keys = {
				K(0, "sineInOut", HOBS, { Root = { 0, 7.5, 0, 0, 20, 0 }, RLeg = { 50, 0, 8 }, LLeg = { -36, 0, -8 }, Torso = { 14, -6, 0 }, Head = { -14, -10, 6 } }),
				K(1.5, "sineInOut", HOBS, { Root = { 0, 7.62, 0, 0, 20, 0 }, RLeg = { 50, 0, 8 }, LLeg = { -36, 0, -8 }, Torso = { 17, -6, 0 }, Head = { -16, 8, -4 } }),
			},
			Events = {
				{ t = 0, k = "Fx", n = "KenosOrbit", c = 7 },
			},
		}),
		-- 다이브: 0.4 초 느린 조준(몸을 앞으로 기울여 겨눔) → 0.5 초 낙하(몸을 던져 팔꿈치를 앞세움 — 탑로프 엘보 드롭) → 착지(무릎 · 팔꿈치로 땅을 찍음, Hit)
		CallistoKenosDive = M({
			Duration = 1.4,
			Keys = {
				K(0, nil, HOBS, { Root = { 0, 7.5, 0, 0, 20, 0 }, RLeg = { 50, 0, 8 }, LLeg = { -36, 0, -8 }, Torso = { 14, -6, 0 }, Head = { -14, -10, 6 } }),
				K(0.4, "sineInOut", HOBS, { Root = { 0, 7.9, 0.1, 0, 10, 0 }, RLeg = { 56, 0, 8 }, LLeg = { -40, 0, -8 }, Torso = { 22, -2, 0 }, Head = { -20, -4, 0 }, LArm = { 120, 0, -8 } }),
				K(0.52, "quadIn", HOBS, { Root = { 0, 6.0, -0.6, 0, 6, 0 }, RLeg = { -20, 0, 6 }, LLeg = { 24, 0, -6 }, Torso = { -18, 0, 0 }, Head = { -16, 0, 0 }, LArm = { 150, 0, -10 } }),
				K(0.9, "expoIn", HOBS, { Root = { 0, -0.7, -0.5, 0, 6, 0 }, RLeg = { 48, 0, 8 }, LLeg = { -36, 0, -8 }, Torso = { -30, 0, 0 }, Head = { 16, 0, 0 }, LArm = { 70, 0, -12 } }),
				K(1.0, "backOut", HOBS, { Root = { 0, -0.72, -0.5, 0, 6, 0 }, RLeg = { 48, 0, 8 }, LLeg = { -36, 0, -8 }, Torso = { -30, 0, 0 }, Head = { 16, 0, 0 }, LArm = { 70, 0, -12 } }),
				K(1.4, "sineInOut", HOBS),
			},
			Events = {
				{ t = 0, k = "Fx", n = "KenosDiveShot", d = 0.4 },
				{ t = 0.4, k = "Dash", to = "Target", gap = 3.4, d = 0.5 },
				{ t = 0.4, k = "Fx", n = "KenosTail" },
				{ t = 0.9, k = "Fx", n = "KenosLanding" },
				{ t = 0.9, k = "Hit", i = 1 },
				{ t = 0.9, k = "Shake", a = 0.3, d = 0.3 },
				{ t = 0.9, k = "Stop", d = 0.06 },
				{ t = 1.05, k = "Dash", to = "Home", d = 0.35 },
			},
		}),
		-- 파워밤: 다가가 한 팔로 대상을 움켜쥐고(별빛 덩어리로 그린다) 머리 위로 들어 올려 버티다가(떨리며 한 박자 멈춤) → 온몸으로 내리찍는다(Hit, 슬로)
		CallistoKenosBomb = M({
			Duration = 1.8,
			Keys = {
				K(0, nil, HOBS),
				K(0.12, "sineOut", HOBS, { LArm = { 96, 0, 0 }, Torso = { 4, -14, 0 } }),
				K(0.3, "expoOut", HOBS, { LArm = { 100, 0, 4 }, Torso = { -6, -16, 0 }, Root = { 0, -0.15, 0.2, 0, 20, 0 } }),
				K(0.38, nil, HOBS, { LArm = { 100, 0, 4 }, Torso = { -6, -16, 0 }, Root = { 0, -0.15, 0.2, 0, 20, 0 } }),
				K(0.62, "sineOut", HOBS, { LArm = { 172, -6, 4 }, Torso = { 14, -6, 0 }, Head = { 28, 0, 0 }, Root = { 0, 0.5, 0, 0, 20, 0 } }),
				K(0.78, "quadInOut", HOBS, { LArm = { 174, -4, 6 }, Torso = { 16, -6, 0 }, Head = { 32, 0, 0 }, Root = { 0, 0.62, 0, 0, 20, 0 } }),
				K(0.9, "quadInOut", HOBS, { LArm = { 172, -8, 2 }, Torso = { 16, -6, 0 }, Head = { 32, 0, 0 }, Root = { 0, 0.56, 0, 0, 20, 0 } }),
				K(0.96, nil, HOBS, { LArm = { 174, -6, 4 }, Torso = { 18, -6, 0 }, Head = { 34, 0, 0 }, Root = { 0, 0.6, 0, 0, 20, 0 } }),
				K(1.04, "expoIn", HOBS, { LArm = { 36, 0, -10 }, Torso = { -26, 0, 0 }, Head = { 16, 0, 0 }, Root = { 0, -0.7, -0.45, 0, 6, 0 }, RLeg = { 48, 0, 8 }, LLeg = { -36, 0, -8 } }),
				K(1.5, "sineOut", HOBS, { LArm = { 30, 0, -12 }, Torso = { -20, 0, 0 }, Head = { 12, 0, 0 }, Root = { 0, -0.6, -0.4, 0, 6, 0 }, RLeg = { 44, 0, 8 }, LLeg = { -32, 0, -8 } }),
				K(1.8, "sineInOut", HOBS),
			},
			Events = {
				{ t = 0.04, k = "Dash", to = "Target", gap = 1.8, d = 0.24 },
				{ t = 0.3, k = "Fx", n = "KenosGrab" },
				{ t = 0.62, k = "Fx", n = "KenosLift" },
				{ t = 1.04, k = "Fx", n = "KenosSlam" },
				{ t = 1.05, k = "Hit", i = 1 },
				{ t = 1.04, k = "Shake", a = 0.55, d = 0.4 },
				{ t = 1.05, k = "Stop", d = 0.12 },
				{ t = 1.4, k = "Dash", to = "Home", d = 0.34 },
			},
		}),
		-- 끌어내림(핀 폴): 다이브 도중 한쪽 별빛이 끊겨(몸이 휘청) → 허우적대며 한 바퀴 돌아 추락 → 바닥에 쿵(튀어 오름) → 무릎을 꿇고 어질어질. 끝 자세 = 스턴 루프 첫 키
		CallistoKenosFall = M({
			Duration = 2.5,
			Keys = {
				K(0, nil, HOBS, { Root = { 0, 7.5, 0, 0, 20, 0 }, RLeg = { 50, 0, 8 }, LLeg = { -36, 0, -8 }, Torso = { 14, -6, 0 }, Head = { -14, -10, 6 } }),
				K(0.14, "expoOut", HOBS, { Root = { 0, 7.0, 0, 0, 20, 0 }, Torso = { -18, 6, 0 }, Head = { 24, 10, 0 }, LArm = { 150, 40, 40 }, RLeg = { 20, 0, 20 }, LLeg = { -10, 0, -20 } }),
				K(0.5, "sineIn", HOBS, { Root = { 0, 4.6, -0.2, 0, 200, 0 }, Torso = { -24, 0, 0 }, Head = { 20, 0, 0 }, LArm = { 150, -40, -40 }, RLeg = { 24, 0, 24 }, LLeg = { -20, 0, -24 } }),
				K(0.86, "quadIn", HOBS, { Root = { 0, 0.4, -0.3, 0, 380, 0 }, Torso = { -34, 0, 0 }, Head = { 12, 0, 0 }, LArm = { 100, -30, -30 }, RLeg = { 20, 0, 18 }, LLeg = { -16, 0, -18 } }),
				K(0.96, "expoOut", HOBS, { Root = { 0, -1.2, 0.2, 0, 380, 0 }, Torso = { -40, 0, 0 }, Head = { 20, 0, 0 }, LArm = { 40, -20, -30 }, RLeg = { 60, 0, 20 }, LLeg = { -30, 0, -20 } }),
				K(1.12, "quadOut", HOBS, { Root = { 0, -0.5, 0.2, 0, 380, 0 }, Torso = { -20, 0, 0 }, Head = { 10, 0, 0 }, LArm = { 40, -20, -30 }, RLeg = { 70, 0, 12 }, LLeg = { -20, 0, -10 } }),
				K(1.6, "sineInOut", HOBS, { Root = { 0, -1.3, 0.2, 0, 380, 0 }, Torso = { 16, 0, 0 }, Head = { -22, 0, 0 }, RLeg = { 88, 0, 6 }, LLeg = { -8, 0, -6 }, LArm = { 20, 0, -12 } }),
				K(2.5, "sineInOut", HOBS, { Root = { 0, -1.3, 0.2, 0, 380, 0 }, Torso = { 16, 0, 0 }, Head = { -22, 0, 0 }, RLeg = { 88, 0, 6 }, LLeg = { -8, 0, -6 }, LArm = { 20, 0, -12 } }),
			},
			Events = {
				{ t = 0.1, k = "Fx", n = "KenosSever" },
				{ t = 0.9, k = "Fx", n = "KenosCrash" },
				{ t = 0.9, k = "Shake", a = 0.6, d = 0.4 },
				{ t = 1.3, k = "Fx", n = "KenosOrbit", c = 5, stun = true },
			},
		}),
		-- 스턴 루프: 무릎을 꿇은 채 머리가 어질어질 돌고(몸이 느리게 흔들림), 머리 위로 별 다섯이 돈다
		CallistoKenosStun = M({
			Duration = 2.4,
			Loop = true,
			Keys = {
				K(0, "sineInOut", HOBS, { Root = { 0, -1.3, 0.2, 0, 20, 0 }, Torso = { 16, 0, 0 }, Head = { -22, 0, 0 }, RLeg = { 88, 0, 6 }, LLeg = { -8, 0, -6 }, LArm = { 20, 0, -12 } }),
				K(0.8, "sineInOut", HOBS, { Root = { 0, -1.3, 0.2, 0, 20, 0 }, Torso = { 14, 6, 4 }, Head = { -20, 18, 8 }, RLeg = { 88, 0, 6 }, LLeg = { -8, 0, -6 }, LArm = { 24, 0, -12 } }),
				K(1.6, "sineInOut", HOBS, { Root = { 0, -1.3, 0.2, 0, 20, 0 }, Torso = { 14, -6, -4 }, Head = { -20, -18, -8 }, RLeg = { 88, 0, 6 }, LLeg = { -8, 0, -6 }, LArm = { 24, 0, -12 } }),
			},
			Events = {
				{ t = 0, k = "Fx", n = "KenosOrbit", c = 5, stun = true },
			},
		}),
	},
}

