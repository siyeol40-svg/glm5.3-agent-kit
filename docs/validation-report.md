# v0.2 검증 기록

실행일: 2026-11-03(Asia/Seoul). 개발 환경: Linux, Python 3.12.14, Pillow 12.3.0.

| 실제 실행 | 결과 |
|---|---|
| Python unittest 전체 | 62개 통과 |
| python -S unittest | 외부 패키지 없이 44개 통과, Pillow 의존 18개 명시적 skip |
| compileall: scripts/Skill scripts/tests | 통과 |
| 문서 내부 링크·Skill frontmatter·AGENTS 200줄 제한 | 검사 통과 |
| 기존 PPTX 무결성·중첩 그룹·스타일/내용 diff 회귀 | 통과 |
| bootstrap check/apply/verify/rollback CLI | 합성 프로젝트에서 통과 |
| bootstrap 사내 규칙 overlay 보존·백업·중복 Skill 해제·ppt-master 유지 | 자동 테스트와 독립 README 적용 작업에서 확인 |
| 기존 AGENTS 해시 변경·백업 경로 오류·후속 수동 변경 후 rollback | 의도대로 거절 |
| native snapshot 판정기: fit/overflow/누락/폰트/자동축소/미지원 geometry | 합성 측정 입력에서 기대한 PASS/FAIL/NOT REVIEWED |
| pixel diff: 동일 이미지·의도된 mask·외부 변화·과도한 mask·환경/해시 변경 | 합성 이미지에서 기대한 결과 |
| 보조 이미지 준비/기록 CLI | 입력 크기 제한·보고 항목 검사·미판독/자연어 자동 PASS 금지 확인 |
| 순차 gate 프로토콜 전체 | 합성 증거 통과, 미검토·후보/증거 변경 시 FAIL |
| 독립 에이전트의 README 적용 | 실제 자동 로딩 증거가 없음을 NOT VERIFIED로 남기고, 합성 ppt-master 실행 가능성을 가장하지 않음 |

합성 snapshot/엔진 로그는 판정 로직 테스트 전용입니다. Office나 회사 도구의 실제 실행 증거가 아닙니다. 독립 적용 작업은 테스트 추가 이전의 59개 회귀와 당시 Skill snapshot을 사용했고, 최종 전체 62개 테스트는 주 작업에서 다시 수행했습니다.

## 실제로 실행하지 못한 항목

- Windows PowerPoint COM: PowerShell과 Office가 없어 실행하지 못했습니다. scripts/powerpoint_probe.ps1은 제안 구현이며 대상 Windows에서 capability/정상 텍스트/overflow/중첩 그룹/회전/폰트 검증이 필요합니다. CI의 PowerShell parser job은 문법만 검사하며 COM 동작 보증이 아닙니다.
- PPT Master import→수정→roundtrip export E2E: 이 환경에 엔진 전체를 설치·복사하지 않았습니다.
- 회사 look_at 및 multimodal-looker: 사용자가 보고한 기능을 연결 계약에 반영했으며 실제 호출하지 않았습니다.
- 회사 에이전트의 실제 지침 자동 로딩·세션 갱신·20만 토큰 계측: 대상 실행기에서 확인해야 합니다.
- 업무 PPT 제작과 최종 시각 QA: 실제 입력이 제공되지 않았으므로 실행하지 않았습니다.

v0.1에서 python-pptx로 만든 합성 PPTX의 무결성·재귀 추출과 soffice→PDF→PNG·crop smoke는 실행했으나, 이를 v0.2 PowerPoint native 실측 성공으로 확대 해석하지 않습니다.

## 자동 완료 경계

기존 구조/내용 보존, native 측정, 픽셀 비교, 잔여 시각 QA 중 필수 gate가 FAIL 또는 NOT REVIEWED이면 strict 최종 영수증은 PASS가 아닙니다. 회전/그룹/표 등의 미지원 geometry가 남으면 candidate는 보존하되 미검증으로 보고합니다. 로컬 evidence는 협조적 실행자용 일관성 검사이며 서명된 도구 실행 인증이 아닙니다.
