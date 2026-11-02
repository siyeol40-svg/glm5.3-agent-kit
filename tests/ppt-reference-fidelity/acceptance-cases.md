# v0.1 수용 사례

자동 실행: `python -m unittest discover -s tests/ppt-reference-fidelity -v`.
외부 설치 없이 확인: `python -S -m unittest discover -s tests/ppt-reference-fidelity -v`.

fixture는 테스트 중 임시 ZIP/XML/이미지로 생성·폐기합니다. 합성 OPC fixture는 일부 파트를 최소화한 검사 전용 자료이며 실제 PowerPoint 호환 문서로 주장하지 않습니다. 흰색 PNG와 합성 엔진 로그는 gate protocol 테스트용이며 실제 PPT 렌더/엔진 실행 증거가 아닙니다.

| 자동 사례 | 기대 결과 |
|---|---|
| 정상 합성 패키지 | PASS |
| ZIP 손상, XML 파싱 실패, DTD/entity | FAIL JSON + 종료 코드 1 |
| media 누락, image rel 누락, dangling owner | FAIL |
| orphan slide/notes | FAIL |
| ZIP/target 경로 이탈 | FAIL |
| percent-encoded 정상 target | PASS |
| 중복 relationship, 잘못된 slideId, 중복 shape id | FAIL |
| blip의 non-image 관계 | FAIL |
| 중첩 그룹 내부 문구 | 정확히 추출 |
| 동일 manifest | PASS |
| 허용하지 않은 문구/좌표/그림자/테두리/media 변경 | FAIL |
| 새 객체 추가 | FAIL |
| exact before/after 문구 변경만 허용 | PASS; after 불일치 FAIL |
| 그룹 문구 미교체, 매핑 누락, photo/diagram 선언 불일치 | FAIL |
| 출처 문구/파일 해시 변경 | FAIL |
| 엔진 경로 없는 preflight | FAIL, 경로 추정 안 함 |
| 중간 단계부터 advance, 빈 final gate | FAIL |
| 영역 crop 생성 | NOT REVIEWED 유지 |
| 영역 box 범위 오류 | FAIL |
| 일부 QA 항목 NOT REVIEWED | 전체 FAIL |
| 전체 합성 gate evidence | 순차 진행 후 PASS receipt |
| 통과 후 QA 파일/후보 파일 변경 | finalize FAIL |
| invalidate | 해당 단계 이후 제거·이전 receipt 제거 |

## 회사 환경에서 남은 수동/E2E 수용

- 실제 설치된 PPT Master guard/import/편집/export/delivery/readback가 성공하는가.
- 디자인 보존 작업이 Generate가 아닌 Edit Native PPTX로 라우팅되는가.
- 회사 GLM의 actual tool use, shell 권한, 지침 로딩이 확인되는가.
- reference/새 자료가 분리되고 기존 기관명·수치가 근거 없이 남지 않는가.
- 각 카드·제목·하단 도해가 실제 box/targets와 맞는가.
- 제목 잘림, crop 변경, 그림자 누락을 가진 합성 이미지에서 Vision MCP가 결함을 찾는가.
- 시각 MCP가 파일 bytes를 분석하는가. 이미지 경로나 base64만 반환하지 않는가.
- 수정 후 원래 QA를 재사용하면 gate가 차단하는가.
- 실제 대상 PowerPoint에서 열리고 글꼴/렌더 차이가 검토되는가.
- 새 Kit이 작동해도 사내 전용 명령·규칙이 보존되는가.

검사하지 않은 E2E 항목은 미검증으로 기록합니다. 자동 테스트 수를 시각 품질 점수로 해석하지 않습니다.

## v0.2 추가 수용

- README 진입점에서 로컬 bootstrap 계획 검사·백업·적용·verify·rollback을 실제 실행합니다.
- 원본 AGENTS 해시가 바뀌면 적용하지 않고, 적용 후 수동 변경이 있으면 rollback이 덮어쓰지 않습니다.
- 사내 공통/범위별 overlay를 보존하고 ppt-master 자체를 비활성화하지 않습니다.
- 파일 적용 성공과 실제 지침 로딩을 구분하며 loading 근거가 없으면 preflight gate를 차단합니다.
- layout checker는 overflow를 FAIL, 그룹/회전/폰트/자동축소 등 확인 불가를 NOT REVIEWED로 처리합니다.
- pixel diff는 렌더 환경·슬라이드·해시가 다르면 FAIL합니다. 승인 mask 밖 변경과 과도한 mask를 검출합니다.
- 전체 preview는 overview 3항목, 상세 영역은 10항목으로 검사하고 작은 글자를 전체 thumbnail에서 판정하지 않습니다.
- look_at/looker raw 보고가 불명확하거나 자연어뿐이면 모든 항목 PASS로 임의 복제하지 않습니다.
- 총 200,000토큰과 개별 이미지 도구의 제한을 구분합니다. 계측 없이 정확한 잔여량을 주장하지 않습니다.
- Windows PowerPoint probe는 대상 환경에서 실제 실행해야 합니다. 합성 snapshot 테스트는 COM E2E가 아닙니다.
