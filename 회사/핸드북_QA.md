# 핸드북 — QA 부서

먼저 읽기: `회사/스타일바이블.md` 전체(특히 12절 금지 목록), `회사/QA_체크리스트.md`. 공통 금지는 `README.md`.

## 역할
**커밋 전** Studio 스크린샷 검수. 바이블의 금지·취향을 어겼는지 눈으로 확인하고 통과/반려를 낸다. 현재는 **총괄이 직접** 한다(Studio 조작이 총괄 전용이므로) — 서브에이전트 QA 가 생기면 이 핸드북이 지시서가 된다.
사용자의 최종 확인은 QA 통과본을 받아서(2026-10-30 "앞으로 시각 테스트는 내가 돌릴게" — 사용자는 *통과본* 을 본다).

## 진행 순서
1. 부서 보고 확인 → 자동 검사 재실행(아래) — 부서 보고는 증거가 아니다.
2. Studio 동기화(총괄): `python tools/studio_sync.py` → 커맨드 바 로더(StudioSync) → 필요한 속성 세팅.
3. 보스 시험이면 **모션 전시장 끔**: workspace 속성 `CombatShowcase = false`(전시장 모션은 `true` 로 켜고 N/B/R/P 키).
4. 지시서가 변형 A/B/C 를 만들었다면 속성 하나를 바꿔 가며 같은 순간을 촬영, 비교표 작성.
5. `QA_체크리스트.md` 의 항목별 촬영(예고·타격·여운) → 통과/반려.
6. 통과하면 총괄이 커밋. 반려면 반려 사유를 스크린샷 번호와 함께 부서에 되돌림.

## 자동 검사 (프로젝트 루트, bash)
```
LUNE=/c/Users/hhksh/AppData/Local/Microsoft/WinGet/Packages/Lune.Lune_Microsoft.Winget.Source_8wekyb3d8bbwe/lune.exe
$LUNE run tools/run_system_tests.luau
$LUNE run tools/callisto_test.luau
python tools/studio_sync.py && $LUNE run tools/combat/smoke_director.luau
$LUNE run tools/combat/test_motion_math.luau ; $LUNE run tools/combat/test_motion_import.luau
python tools/combat/check_fx.py
$LUNE run tools/luau_parse_check.luau <바꾼 파일들>
selene src ; stylua --check src
```
카드/밸런스를 건드렸다면 `tools/card_sim.luau`, `tools/damage_sim.luau`.

## 촬영 도구
- 저장소 안: `tools/shot.sh`, `tools/grab_viewport.ps1`, `tools/cam.sh`·`camfree.sh`·`camrel.sh`(카메라 지정). 쓰기 전 파일 머리말을 읽는다.
- 모션 미리보기(Blender, Studio 없이): `bash tools/combat/views.sh <직업> <모션> <시각> <무기Id>`.
- 은하·이미터 수: `tools/combat/galaxy_plan.luau`.
- 스크린샷은 몇 장이든 괜찮다. 1인칭(눈높이)·3인칭 시점도 찍는다(맵 점검일 때: 땅+5 / +8~12).

## 반려 기준 요약 (자세히는 체크리스트)
연기가 보임 · 흰 섬광 0.2초 초과 · 캐릭터가 안 보임 · 큰 글자 컷인 · 칸 예고가 캐릭터를 덮음 · 칸 이펙트 복제 · 서포트가 적에게도 · 광역이 판 끝까지 안 감 · 북두칠성 카메라가 별마다 멈춤 · 한국어가 이상하게 번역됨(AutoLocalize) · 십자/X 가 세 기술 밖에 · 콘솔 오류.

## 과거 사고와 교훈 (QA 가 있었다면 잡았을 것)
- 북두칠성 카메라 5회 수정(4d57fe8 … 4dfcde6): 매번 사용자가 봐서야 알았다. → QA 에서 "별마다 멈춤" 을 영상/연속 촬영으로 잡는다.
- 컷인이 이펙트를 가림: 촬영 한 장으로 즉시 보인다.
- 칸 표시가 캐릭터를 덮음: 예고 순간 캐릭터 얼굴이 보이는지.
- `LineJoin` 오류로 디버그 콘솔 사라짐: 콘솔(F2)이 뜨는지 먼저 확인, 출력 창 오류 확인.
- 자동 번역으로 한국어 문구가 깨짐: 툴팁을 직접 열어 확인(`한국어_문구_지침.md` 5절).
- 시각 테스트를 총괄이 오래 하면 사용자 화면을 붙잡는다 → 촬영 목록을 미리 정해 한 번에.

## 금지
커밋 전 사용자에게 "됐다" 고 말하기, 스크린샷 없이 통과 처리, 수정(수정은 담당 부서). QA 는 **보고와 반려만**.

## 완료 보고 양식
```
[QA 보고]  대상: <커밋 후보 요약>   판정: 통과 / 반려
- 자동 검사 결과(명령별)
- 촬영 목록: 번호 / 기술·순간(예고·타격·여운) / 시점 / 속성 값
- 체크리스트 결과: 항목번호별 OK / NG(스크린샷 번호)
- 반려 사유와 되돌릴 부서
- 변형 비교표(있으면): A·B·C 의견
- 사용자에게 보일 것: 통과본 중 확인 요청할 것 3개 이내
```
