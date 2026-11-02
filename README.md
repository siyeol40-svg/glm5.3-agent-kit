# glm5.3-agent-kit

GLM-5.3이 원본 PPT 디자인을 보존하면서 새 내용을 넣도록 절차와 검증 증거를 묶는 v0.1 Kit입니다. “더 잘 검토”라는 지시 대신 잘못된 경로·누락·오래된 증거를 차단합니다. 향후 Excel·Word·코드 Skill을 같은 전역 규칙 아래 추가합니다.

**현재 구현:** 공통 지침, PPT 상위 Skill, 읽기 전용 OOXML manifest/무결성 검사, exact 구조 diff, 영역 crop, 순차 gate와 최종 영수증. **미구현:** PPT Master 자체의 편집 기능, 렌더러, 자동 시각 결함 판정, MCP adapter. 별도 엔진과 실제 시각 검토가 필요합니다.

## 구성과 역할

| 파일/폴더 | 역할 |
|---|---|
| AGENTS.md | 200줄 이내 공통 언어·실행·근거·보안 규칙 |
| .agents/skills/ppt-reference-fidelity/SKILL.md | PPT 디자인 보존 작업의 상위 통제 |
| references/workflow.md | 순차 단계·증거 JSON·CLI 사용 |
| references/ppt-master-routing.md | upstream 검토 결과·호환 경계·연결 명령 |
| references/content-authority.md, content-mapping.md | 사실/디자인 권위와 슬롯 잠금 |
| references/pptx-integrity.md, visual-qa.md | 구조/패키지/영역별 QA |
| references/failure-patterns.md | 실제 실패를 일반화한 회귀 규칙 |
| scripts/common.py | JSON·해시·OPC 경로 공통 함수 |
| scripts/preflight.py | 실제 imports·엔진 파일·실행 파일 점검 |
| scripts/inspect_pptx.py | 그룹 재귀, 텍스트·스타일·좌표·media manifest |
| scripts/compare_manifests.py | 정확한 before/after 허용 목록 외 변경 FAIL |
| scripts/validate_pptx.py | 표준 라이브러리 PPTX package 검사 |
| scripts/render_regions.py | 렌더 이미지에서 영역 crop; 기본 NOT REVIEWED |
| scripts/gate.py | 단계 순서·증거/후보 해시·최종 receipt 재검증 |
| docs/ | 회사 read-only 설정·마이그레이션·런타임·Vision MCP |
| tests/ppt-reference-fidelity/ | 임시 합성 fixture 생성·회귀 테스트·수용 기준 |
| .github/workflows/tests.yml | 표준 라이브러리 검사와 별도 Pillow 검사 |

## 먼저 실행

Python 3.10+가 필요합니다. 무결성·manifest·diff·gate의 비시각 단계는 외부 dependency가 없습니다. `render_regions.py`와 최종 visual gate는 Pillow가 필요합니다. 핵심 검사는 python-pptx/lxml을 사용하지 않습니다.

```bash
python3 -m unittest discover -s tests/ppt-reference-fidelity -v
python3 .agents/skills/ppt-reference-fidelity/scripts/validate_pptx.py /local-run/candidate.pptx -o /local-run/package_integrity.json
```

실제 문서는 Git checkout 밖에서 작업하십시오. [전체 실행 절차](.agents/skills/ppt-reference-fidelity/references/workflow.md)를 읽고 preflight부터 진행합니다. 검증 스크립트는 입력 파일을 고치지 않습니다. 실패 시 출력 JSON과 종료 코드 1을 반환합니다.

## PPT Master와 연결

[PPT Master](https://github.com/hugohe3/ppt-master)를 실행 엔진으로 유지하며 fork하거나 전체 복사하지 않습니다. 원본 PPTX+디자인 유지 작업은 `Edit Native PPTX` roundtrip을 사용합니다. 이 Kit은 엔진 export 결과를 candidate로 받아 추가 검증합니다. [확인한 문서·파일 해시와 차이](.agents/skills/ppt-reference-fidelity/references/ppt-master-routing.md)를 참고하십시오.

v0.1은 같은 슬라이드 수·순서와 객체 구조를 보존하는 작업에 범위를 좁혔습니다. 슬라이드 재배열/증감, 복잡한 차트·표 데이터 교체는 별도 지원 전까지 자동 완료 처리하지 않습니다. 엔진이 재구축한 수정 객체에서 예상치 않은 서식 변화가 생기면 FAIL할 수 있습니다.

## 시각 검토 연결

GLM-5.3 자체의 입력은 text-only이므로 이미지 파일을 만들었다고 직접 검토했다고 보고할 수 없습니다. 별도 시각 모델을 호출하는 MCP 또는 사람의 검토가 필요합니다. [Vision MCP 연결](docs/vision-mcp-setup.md)에 공급자와 분리한 연결 계약과 영역별 검사 절차를 정리했습니다. 현재 회사에서 Z.ai 방식은 사용 불가이며 외부 제공자 도메인 통신 제한이 확인되었으며 별도 허용 API 경로는 미확인입니다. 공개 문서 조사 기록을 실제 사용 가능한 연결로 오해하지 마십시오. Skill만 설치해 이미지 인식이 생기는 것은 아닙니다.

## 기존 지침 마이그레이션 — 삭제부터 하지 마십시오

**백업 → 자동 로딩 해제 → 충돌 검사 → 새 Kit 적용 → 테스트 → 기존 파일 삭제 여부 결정**

1. 실제 자동 로딩 위치와 기존 AGENTS.md/SKILL.md 목록을 확인합니다.
2. 사내 필수 규칙/명령을 읽고 폴더 전체를 회사 로컬에 백업합니다.
3. 역할이 겹치는 기존 커스텀 PPT 지침만 자동 로딩 해제합니다. **PPT Master는 유지합니다.**
4. 경로·언어·Generate/Native 경로·QA 기준 충돌을 검사하고 회사 전용 규칙은 로컬 overlay에 보존합니다.
5. 새 Kit을 적용하고 실제 로딩된 규칙과 Skill을 확인합니다.
6. 합성 회귀 테스트와 회사 로컬 smoke test를 실행합니다.
7. 문제가 없을 때 기존 파일 삭제/보관 여부를 결정합니다. 삭제는 필수가 아닙니다.

[상세 Migration Guide와 롤백](docs/migration-guide.md) · [회사 read-only 적용](docs/company-readonly-setup.md) · [GLM 실행기 설정 확인](docs/glm53-runtime-check.md)

## 완료 조건과 한계

`생성됨 ≠ 실행됨 ≠ 렌더됨 ≠ 검토됨 ≠ 검증 통과`입니다. 모든 gate가 실제 candidate 해시로 PASS여야 `final_receipt.json`을 생성합니다. 전체 썸네일만 검토하거나 카드 한 개가 NOT REVIEWED면 완료할 수 없습니다. 모든 content 슬롯은 별도 상세 QA region으로도 커버해야 합니다.

로컬 파일을 검증하는 협조적 실행자용 도구입니다. 악의적 JSON 조작을 막는 인증 시스템, 전체 OOXML 표준 적합성 검사, 시각적 완벽성 증명은 아닙니다. 내용 의미·폰트 대체·실제 PPT 렌더·시각 판단은 별도 검사/검토가 남습니다. 미검증이면 그대로 보고합니다.

## 공개 저장소 경계

일반화한 코드·규칙·합성 테스트만 저장합니다. 회사 문서·고객정보·실제 금융상품 데이터·사내 경로/주소·인증정보는 저장하지 않습니다. 회사에서 이 저장소는 read-only로 사용합니다. 업무 증거와 preflight 로그도 회사 허용 로컬 폴더에만 둡니다. gitignore만으로 비밀정보가 차단된다고 가정하지 않습니다.

## 테스트와 다음 버전

[수용 사례](tests/ppt-reference-fidelity/acceptance-cases.md), [이번 실행 결과](docs/validation-report.md)를 확인하십시오. fixture는 테스트 때 임시 생성·폐기하며 실제 업무 자료가 없습니다.

v0.2 후보: 승인된 Vision MCP의 실제 schema adapter, upstream quality JSON 자동 판정, 대표 PPT roundtrip E2E, 텍스트/도형 박스 기반 자동 이상 징후 검사, 테마 상속의 유효 스타일 계산, 승인된 슬라이드 roster 변경, 표/차트 내용 검증. 엔진 fork와 거대한 multi-agent 구조는 필요성이 확인되기 전 도입하지 않습니다.
