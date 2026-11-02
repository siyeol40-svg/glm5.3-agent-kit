# 실패 패턴 → 예방 → 회귀 검사

| 실패 | 예방 규칙 | 회귀 검사/수동 확인 |
|---|---|---|
| 렌더=검증으로 보고 | crop 기본값 NOT REVIEWED, 모든 항목 검사 | 미검토/부분 검토는 visual FAIL |
| 레퍼런스 구조 재창작 | native route + exact allowlist | geometry/shadow/border/add-shape diff FAIL |
| slide XML deepcopy로 이미지 소실 | roundtrip 엔진만 사용 | 누락 rel/media, unresolved id FAIL |
| 그룹 내부 문구 누락 | 재귀 key + 전체 콘텐츠 슬롯 매핑 | nested text readback/expected mismatch FAIL |
| 기존 숫자를 새 사실로 사용 | authority facts + 모든 문구 출처 | unmapped slot/stale quote FAIL; 의미는 내용 검토 |
| photo→diagram 임의 변경 | role/content_kind 잠금 | semantic mismatch FAIL; 이미지 분류는 수동 |
| 추정 면적 우선 | raw local EMU + 부모 xfrm 기록 | transform drift FAIL; 절대 영역은 렌더 검토 |
| 도해를 사진 카드에 배치 | slot 의미/상세 regions 고정 | region lock 변경 FAIL; 하단 문법은 수동 비교 |
| 깨진 lxml 반복 시도 | 실제 import subprocess와 오류 기록 | preflight 명령 실제 실행; 재시도 근거 기록 |
| 손상 후보를 최종 배포 | package + final gate | orphan slide/notes, broken ZIP/XML FAIL |
| 편집 후 이전 QA 재사용 | source/candidate/evidence 해시 결속 | 증거·후보 변경 후 finalize FAIL |

새 실패를 발견하면 이 표에 일반화된 규칙과 테스트를 추가합니다. 실제 업무 문서나 내부 오류 경로를 그대로 커밋하지 않습니다. 출처·내용 의미·시각 평가를 코드 검증으로 전부 대체했다고 주장하지 않습니다.
