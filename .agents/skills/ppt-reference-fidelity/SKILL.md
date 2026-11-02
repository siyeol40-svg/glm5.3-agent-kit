---
name: ppt-reference-fidelity
description: 기존 PPTX에 새 콘텐츠를 넣으면서 원본 디자인, 객체 구조와 슬롯 의미를 보존할 때 사용합니다. PPT Master Edit Native PPTX를 통제하고 구조·패키지·영역별 시각 QA 증거가 없으면 최종 완료를 차단합니다. 이미지 레퍼런스만으로 새 PPT를 재창작하는 작업에는 적용하지 않습니다.
---

# PPT Reference Fidelity

기존 디자인을 다시 창작하지 마십시오. 이 Skill은 PPT Master의 상위 제약이며 실행 엔진의 대체 구현이 아닙니다.

## 실행 전 읽기

이 Skill의 실제 절대 경로를 `FIDELITY_DIR`, 설치된 PPT Master의 실제 절대 경로를 `PPT_MASTER_DIR`로 사용하십시오. 경로를 추정하지 마십시오.

1. [workflow.md](references/workflow.md)에서 실행 명령과 증거 형식을 읽으십시오.
2. [ppt-master-routing.md](references/ppt-master-routing.md)와 설치된 엔진의 `SKILL.md`, `workflows/routing.md`, `workflows/edit-native-pptx.md`를 읽으십시오. 엔진의 attribution guard가 실패하면 중단하십시오.
3. [content-authority.md](references/content-authority.md), [content-mapping.md](references/content-mapping.md)를 읽고 자료와 슬롯을 고정하십시오.
4. [pptx-integrity.md](references/pptx-integrity.md), [visual-qa.md](references/visual-qa.md)에서 자동 검사 범위와 시각 검토 조건을 확인하십시오.
5. [failure-patterns.md](references/failure-patterns.md)에서 이번 작업에 해당하는 회귀 조건을 확인하십시오.

## 고정 순서

`Preflight → Route Selection → Reference Authority Contract → Reference Manifest → Content Mapping Lock → Source-Preserving Edit → Structural Validation → PPTX Package Integrity → Full-slide Render → Region-by-region Visual QA → Final Delivery`

각 단계 파일을 만든 후 `scripts/gate.py advance --stage <stage>`를 실행하십시오. 이전 단계가 없거나 FAIL이면 다음 단계로 진입하지 마십시오. `gate.py finalize`가 현재 candidate 해시로 PASS 영수증을 생성하기 전에는 최종본으로 배포하지 마십시오. 파일이 존재한다는 사실만으로 통과시키지 마십시오.

## 원본 보존

- 원본 PPTX가 있고 디자인 유지가 목적이면 `Edit Native PPTX`를 선택하십시오. 이미지/PDF만 있으면 이 경로를 가장하지 말고 입력 부족을 보고하십시오.
- 원본 파일은 읽기 전용으로 다루고 candidate를 별도 파일로 만드십시오.
- 원본 구조로 요구를 만족시킬 수 없는 이유가 확인되면 기록하십시오. 다른 경로가 필요하면 이 Skill의 완료 처리를 중단하고 새 계획으로 전환하십시오.
- Generate 파이프라인, 임의 새 레이아웃, 슬라이드 XML만 deepcopy하는 복제를 사용하지 마십시오.
- 엔진의 native backing과 `data-pptx-*` 식별자를 보존하십시오. 비수정 객체·프레임·좌표·효과를 유지하십시오.
- 그룹 내부와 중첩 그룹의 텍스트까지 매핑하십시오. 상위 shapes만 검사하지 마십시오.
- 실제 객체 치수·회전·crop·그룹 변환을 먼저 읽으십시오. 로컬 좌표를 슬라이드 절대 좌표로 오인하지 마십시오.
- 텍스트가 넘치면 문장 압축 → 줄바꿈 조정 → 기존 공간 내 미세 조정 순으로 해결하십시오. 미세 조정도 잠금에 기록하십시오. 글자 축소나 구조 변경은 마지막 수단입니다.
- 사진 슬롯에는 사진, 하단 기술 도해 슬롯에는 기술 도해를 넣으십시오. 디자인 변경을 사후 정당화하지 마십시오.

## 검증과 중단

- 새 자료만 사실 근거로 사용하십시오. 레퍼런스의 기존 숫자·기관명·문장을 새 사실로 사용하지 마십시오.
- Mapping Lock의 정확한 before/after 허용 목록 외 구조 차이는 FAIL입니다. 결과를 본 뒤 차이를 일괄 허용하지 마십시오.
- 매핑·입력·candidate가 바뀌면 `gate.py invalidate --stage ... --reason ...`로 영향 단계부터 재실행하십시오.
- 전체 슬라이드와 제목·각 카드·하단 도해의 확대 이미지를 모두 검토하십시오. 검토하지 않은 항목은 `NOT REVIEWED`입니다.
- GLM-5.3의 텍스트 입력만으로 이미지 QA를 했다고 주장하지 마십시오. 실제 사람 또는 관측 가능한 이미지 분석 도구가 필요합니다.
- 검사 실패·렌더 불가·이미지 검토 수단 부재 시 candidate와 진단만 보고하십시오. 모든 상태를 PASS로 채워 넣지 마십시오.
- 이 도구는 협조적인 실행자의 실수를 막는 로컬 검증입니다. 조작 불가능한 증명이나 시각적 완벽성을 보장하지 않습니다.
