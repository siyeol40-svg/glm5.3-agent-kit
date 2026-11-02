# v0.4 검증 기록

실행일: 2026-11-03(Asia/Seoul). 개발 환경: Linux, Python 3.12.14. Windows PowerPoint/회사 DRM/회사 이미지 도구는 이 환경에 없습니다.

## 실제 실행

| 검사 | 결과 |
|---|---|
| 전체 Python 합성 회귀 | 120개 통과 |
| python -S 표준 라이브러리 경로 | 102개 통과, Pillow 의존 18개 명시적 skip |
| compileall·문서 상대 링크·JSON 예제 파싱·Skill metadata·AGENTS 200줄 제한 | 확인 |
| COM 프로필 기획/lock/audit CLI | 합성 COM snapshot·증거에서 수행 |
| 옛 사진 결정 누락·장식으로 잘못 유지·사용자 승인 없는 콘텐츠 재사용 | 의도대로 거절 |
| 시각 표현 2안/선택 근거·새 시각 컨셉 누락·생성 사진의 현장 증거 주장·새 사진 asset 흔적 누락 | 의도대로 거절 |
| 캡처 없음·모델만 PASS | 사용자 수용으로 승격하지 않음 |
| 사용자 캡처 외 입력·tool 입력 흔적 없음·이미지/후보 revision 변경 | 의도대로 거절 |
| 사용자 지적 임의 종결·열린 결함 | 최종 수용 차단 |
| 실제 사용자 수용 기록·도구 오탐에 대한 사용자 정정 | 제한/기존 의견 보존한 수용 상태 |
| Office 문서 bytes 읽기 금지·ZIP 없이 metadata/snapshot으로 처리 | 회귀 확인 |
| COM 지원 텍스트 bounds overflow·예정 밖 위치 변경 | FAIL |
| 계획된 이름/영역/개수 내 신규 native 객체·명시적 삭제 | 허용; 영역 밖 변경은 FAIL |
| COM 미확인 속성/fit | PARTIAL로 보존; 전체 기술 검증 PASS로 바꾸지 않음 |
| 분석/자료 검토/실제 사용자 기획 확인 누락·변경 | lock/audit 차단 |
| 미응답 자료 질문·제외할 원본 페이지 분석 누락 | 편집 전 확인 단계에서 거절 |
| 원본 페이지 제외·재배열·패턴 반복 활용 | 전체 원본 복제를 강제하지 않음; 결과의 예상 밖 빈 페이지는 거절 |
| 로고/장식 재사용 | 분류 근거만으로 허용하지 않고 실제 사용자 허가 기록 요구 |
| unit analyze/ready/check/finish | 분석 전 편집·미답변 질문·미완료 의존 unit·기대값 불일치 차단 |
| unit snapshot·분석 증거 변경/현재 상태 불일치·unit 밖 변경 | 종료/다음 편집/최종 수용 차단 |
| invalidate·재분석·재검사 | 이전 이력 보존, 의존 unit 무효화, 현재 상태에서 재검사 |
| 실효 글자 크기/hidden 등 미지원 property의 PASS 주장 | 지원 검사 allowlist에서 거절 |
| source_readback·최종 재열기 snapshot | 원본 읽힌 속성 불일치/완료 unit과 최종 결과 불일치 차단 |

모든 COM snapshot·로그·캡처·사용자 승인 파일은 테스트에서 임시 합성한 프로토콜 fixture입니다. 실제 Office/DRM/이미지 분석/사용자 승인 실행을 증명하지 않습니다. “사진 의미가 적절하다/창의적이다”를 테스트 개수로 보장하지 않습니다.

독립적인 README/Skill 적용 검토에서 캡처 대기 전에 기존 사용자 지적을 확인하지 않는 상태 우선순위 오류를 발견하여 수정했고, 캡처 없이도 OPEN 이슈가 REQUIRES_FIX로 보존되는 회귀를 추가했습니다. 이 검토는 이미지 이해 능력 검증이 아닙니다.

위 상태 우선순위 독립 검토는 v0.3 때 수행했습니다. v0.4는 별도 시나리오로 Skill을 적용하는 독립 검토도 수행했습니다. 사진 부재·미승인 기존 사진·읽을 수 없는 차트 수치·COM 세션 부재에서 실제 결과를 꾸미지 않고 질문/자료 대기와 단계별 gate를 선택했습니다. 이 검토도 실제 COM 실행이나 시각 품질 검증은 아닙니다. v0.4의 짧은 단계 실행/인코딩/중단 복구는 운영 지침이며, 회사 실행기에서 thinking 폭주·무응답을 실제로 줄였는지는 아직 계측하지 않았습니다. 짧은 보고가 reasoning 길이를 강제한다는 보장은 없습니다.

## 아직 실행하지 못한 것

- com_native_manifest.ps1의 실제 Windows COM 읽기. 지원 속성·GetActiveObject·DRM 권한·세션 소유권은 대상 환경에서 확인해야 합니다.
- 실제 보호 문서의 복사본 생성/수정/저장/재열기. 이 Kit은 범용 COM 편집 엔진을 제공하지 않으며 에이전트가 계획에 맞는 승인된 코드를 작성·실행해야 합니다.
- 회사 look_at/looker의 실제 이미지 이해 및 결함 인지. 도구 이름/JSON/checklist만으로 정확성이 보장되지 않습니다.
- 실제 업무 자료를 바탕으로 새 사진/도해가 구현된 PPT. 현재 대화에서는 해당 PPT와 새 자료·결과 캡처를 읽지 않았으므로 실제 산출물이 개선됐다고 보고하지 않습니다.
- GitHub Actions 원격 결과. PowerShell parser job은 문법만 검사하며 COM/DRM E2E가 아닙니다.

## 의도적인 프로필 경계

COM_USER_CAPTURE에서는 ZIP package/media-byte integrity, 자동 export/render/pixel 비교를 수행하지 않습니다. 로컬 영수증에 NOT_CHECKED_DRM_PROFILE/NOT_USED_USER_CAPTURE를 남깁니다. 문서 identity는 metadata 기반으로 내용 해시보다 약합니다. 최종 상태는 USER_ACCEPTED_WITH_LIMITATIONS이며 “모든 기술·시각 검증 PASS”가 아닙니다.

기존 PACKAGE_NATIVE_LEGACY 코드와 회귀 테스트는 비보호 환경용으로 보존합니다. 해당 구버전 검사를 새 DRM 작업에 강제하지 않습니다.
