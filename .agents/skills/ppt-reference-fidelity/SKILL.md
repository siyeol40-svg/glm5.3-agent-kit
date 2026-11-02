---
name: ppt-reference-fidelity
description: 레퍼런스 PPT의 디자인 문법을 유지하면서 새 메시지·사진·도해를 기획해 제작합니다. DRM 환경에서는 PowerPoint COM 객체 편집과 사용자 제공 캡처만 사용하며, 기존 콘텐츠 잔존·문장만 치환한 결과·도구의 허위 시각 QA 통과를 차단합니다. 요소별 분석·질문·편집 허가·비시각 재조회 검사를 반복합니다.
---

# PPT Reference Fidelity · v0.4

**레퍼런스에서 필요한 디자인 문법을 선택하고 새 콘텐츠에 맞춰 재구성하십시오.** 기존 사진·도해·문장을 그대로 남기는 복사 작업과 구분하십시오. 현 환경의 기본 프로필은 `COM_USER_CAPTURE`입니다.

## 필요한 문서만 단계적으로 읽기

1. [com-workflow.md](references/com-workflow.md): 현재 기본 실행·파일 계약.
2. 접근/편집 전에 [com-precautions.md](references/com-precautions.md): DRM·COM·서식·복사본·재열기 주의사항.
3. 계획 전에 [content-adaptation.md](references/content-adaptation.md), [content-authority.md](references/content-authority.md): 메시지·새 시각 자료와 사실 근거.
4. 캡처 검토 전에 [user-capture-qa.md](references/user-capture-qa.md): 도구 의견·미확인·사용자 지적·최종 수용 분리.
5. 중단·긴 도구 실행 전 [short-step-execution.md](references/short-step-execution.md): 한 도구씩 실행·짧은 보고·인코딩·복구.
6. 요소 편집 전 [unit-workflow.md](references/unit-workflow.md), [nonvisual-capabilities.md](references/nonvisual-capabilities.md): 상태 gate와 실제 관측 한계.
7. ZIP 경로가 실제 허용된 일반 문서 작업에만 [ppt-master-routing.md](references/ppt-master-routing.md), [workflow.md](references/workflow.md)의 legacy 경로를 읽으십시오.

전체 XML/manifest/base64와 모든 참조 문서를 한 번에 대화에 넣지 마십시오. 200,000토큰 실행기 예산과 이미지 도구별 제한을 분리하십시오.

## COM_USER_CAPTURE 실행 순서

`실제 권한 확인 → COM 원본 객체 목록 → 레퍼런스 상세 분석 → 보유 자료 활용/부족 자료 검토 → 추천 구성·재사용 대상 사용자 확인 → 전체 기획 잠금 → 작업 복사본 → 각 unit의 분석·질문·READY·편집·재조회 QA 반복 → 저장·닫기·재열기 → COM 속성·내용 비교 → 사용자 캡처 대기 → 잔여 결함 검토/수정 → 사용자 최종 수용`

- 현 프로필에서 `inspect_pptx.py`, `validate_pptx.py`, legacy `gate.py`, PPT Master roundtrip을 DRM 문서에 실행하지 마십시오. 이들은 패키지 접근을 요구합니다.
- `com_native_manifest.ps1`은 읽기 전용 객체 목록 도구입니다. `com_workflow.py`는 기획·증거 검사기이며 완성된 범용 COM 편집 엔진이 아닙니다. 실제 편집은 계획에 맞는 로컬 COM 코드/승인된 작업으로 수행하고 기록하십시오.
- 자동 이미지/PDF export, 자동 screenshot, 렌더 비교를 필수화하지 마십시오. 사용자님이 전달한 캡처만 시각 QA 입력입니다.
- COM에서 열 수 있다는 이유로 수정/별도 저장/증거 출력도 허용된다고 가정하지 마십시오. 제한을 우회하거나 DRM을 해제하지 마십시오.
- v0.2 RUN·영수증을 재사용하지 말고 새 작업 revision을 만드십시오.

## 디자인 보존과 창작의 경계

- 사용자와 선택해 계승할 디자인 앵커(모두 고정하지 않음): 컬러·폰트 위계·제목 위치·프레임·여백·선/테두리·그림자·정렬 문법.
- 새로 기획할 콘텐츠: 핵심 메시지, 설명 순서, 새 주제의 사진 선택, 비교·과정·관계 도해, 데이터 표현.
- 선택해 활용할 원본 페이지의 모든 재귀 객체에 text/photo/diagram/chart/decoration/logo/container/design_anchor 역할을 부여하십시오. 그룹 안의 사진·도해를 놓치지 마십시오.
- 기존 photo/diagram/chart는 원칙적으로 새 자료로 교체·재구성하십시오. 로고/장식까지 유지 대상은 구체적으로 확인하고 실제 사용자 허가 근거 없이 그대로 남기지 마십시오.
- 자료가 없으면 기존 사진으로 메우지 마십시오. 실제 사진이 필수면 필요한 자료를 요청하고, 개념 도해로 충분하면 새 자료의 관계를 native 도형으로 표현하십시오. 사진 슬롯을 기술 도해로 몰래 바꾸지 마십시오.
- 새 사진·도해의 무엇이 메시지를 설명하는지 적으십시오. 의미 없는 장식 추가·새 색상·도형 수 증가를 창의성으로 포장하지 마십시오.
- 생성 이미지·예시 수치는 현장 사실이나 실제 실적으로 제시하지 마십시오.
- 새 시각 자료에 필요한 객체 추가/교체/삭제는 편집 전 계획에서 허용하십시오. 구버전의 객체 수 고정 규칙 때문에 필요한 콘텐츠 재구성을 막지 마십시오.

원본 페이지 수·카드 수·모든 좌표를 강제하지 마십시오. reference_slide로 출력 구성을 선택하고 구조 변경 이유·허용 범위를 사용자 확인 후 잠급니다. 분석·자료·기획의 실제 확인 근거 없이는 lock이 실패합니다.

## 요소별 필수 반복

- 전체는 패턴/메시지/자료 활용안 수준에서 먼저 확인하고 세부는 의미 있는 unit마다 분석하십시오.
- unit_gate.py의 init → analyze → ready → 실제 COM 편집 → check 순서를 따르십시오. 답변 없는 중요한 미확인은 NEEDS_INPUT이며 해당 편집을 실행하지 마십시오.
- 앞 의존 unit 미통과·다른 편집 진행 중·관측값 불일치이면 다음 편집을 중단하십시오. unknowns/questions가 없을 때도 빈 목록으로 명시하고 근거 없이 감추지 마십시오.
- 원본 그림 재사용·내용/수치·부족한 자료·지원 API·중요 구조 변경이 불명확하면 작성 전에 질문하십시오. 기존 명시적 답변은 근거를 연결하여 재사용하십시오.
- unit 실패/수정은 invalidate로 이력과 의존 검사를 무효화한 뒤 재분석·재검사하십시오. 최종 audit는 모든 unit 검사 완료를 요구합니다.
- 이 gate는 외부 COM 호출을 OS 차원에서 차단하는 보안 장치가 아닙니다. 편집 허가 준수와 실제 재조회 파일이 필요합니다.
- 실효 축소 글자 크기·그림 내용 동일성·차트/OLE 내부·숨김 상태·상속 완전성은 미확인으로 보존하십시오. null/0/nominal 값을 검증 통과로 바꾸지 마십시오.

## COM 편집

- 원본을 프로그램 내부에서 승인된 복사본으로 만들고 해당 복사본만 수정하십시오. 처음부터 모든 도형을 새로 그리지 마십시오.
- 그룹/shape identity와 서식을 기록하고 의도된 대상만 변경하십시오. 혼합 서식 텍스트를 통째로 덮어써 스타일을 잃지 마십시오.
- 사진 교체 시 프레임뿐 아니라 crop·종횡비·회전·레이어·테두리·그림자를 확인하십시오. 새 이미지를 크기에 억지로 늘리지 마십시오.
- COM에서 읽을 수 없는 속성·SmartArt·차트/표 내부 데이터는 모른다고 기록하십시오. 사용자 캡처 수용을 ZIP 무결성 검증으로 바꾸지 마십시오.

## 검토 상태

- 스크립트·도구 보고만으로 시각적 완벽함이나 창의성을 보장하지 마십시오.
- 캡처를 받기 전 `AWAITING_USER_CAPTURE`, 검토 의견 후 `AWAITING_USER_ACCEPTANCE`로 남기십시오.
- 사용자 지적은 known_issues.json에 기록하고, 근거 없이 오탐·취향·의도라고 정당화하지 마십시오.
- 도구가 이미지를 처리했다는 증거가 없거나 결함을 알아보지 못하면 그 의견은 신뢰 가능한 검증 증거가 아닙니다. 더 많은 같은 호출을 반복하지 마십시오.
- 현재 결과에 대한 실제 사용자 수용만 `USER_ACCEPTED_WITH_LIMITATIONS`로 기록하십시오. 누락된 속성·패키지 검사까지 PASS라고 주장하지 마십시오.
