---
name: ppt-reference-fidelity
description: 레퍼런스 PPT의 디자인 문법을 유지하면서 새 메시지·사진·도해를 기획해 제작합니다. DRM 환경에서는 PowerPoint COM 객체 편집과 사용자 제공 캡처만 사용하며, 기존 콘텐츠 잔존·문장만 치환한 결과·도구의 허위 시각 QA 통과를 차단합니다.
---

# PPT Reference Fidelity · v0.3

**디자인을 보존하되 콘텐츠를 새로 설계하십시오.** 기존 사진·도해·문장을 그대로 남기는 복사 작업과 구분하십시오. 현 환경의 기본 프로필은 `COM_USER_CAPTURE`입니다.

## 필요한 문서만 단계적으로 읽기

1. [com-workflow.md](references/com-workflow.md): 현재 기본 실행·파일 계약.
2. 접근/편집 전에 [com-precautions.md](references/com-precautions.md): DRM·COM·서식·복사본·재열기 주의사항.
3. 계획 전에 [content-adaptation.md](references/content-adaptation.md), [content-authority.md](references/content-authority.md): 메시지·새 시각 자료와 사실 근거.
4. 캡처 검토 전에 [user-capture-qa.md](references/user-capture-qa.md): 도구 의견·미확인·사용자 지적·최종 수용 분리.
5. ZIP 경로가 실제 허용된 일반 문서 작업에만 [ppt-master-routing.md](references/ppt-master-routing.md), [workflow.md](references/workflow.md)의 legacy 경로를 읽으십시오.

전체 XML/manifest/base64와 모든 참조 문서를 한 번에 대화에 넣지 마십시오. 200,000토큰 실행기 예산과 이미지 도구별 제한을 분리하십시오.

## COM_USER_CAPTURE 실행 순서

`실제 권한 확인 → COM 원본 객체 목록 → 메시지·시각 콘텐츠 기획 → 슬롯/변경 허용 잠금 → COM 복사본 편집 → 저장·닫기·재열기 → COM 속성·내용 비교 → 사용자 캡처 대기 → 잔여 결함 검토/수정 → 사용자 최종 수용`

- 현 프로필에서 `inspect_pptx.py`, `validate_pptx.py`, legacy `gate.py`, PPT Master roundtrip을 DRM 문서에 실행하지 마십시오. 이들은 패키지 접근을 요구합니다.
- `com_native_manifest.ps1`은 읽기 전용 객체 목록 도구입니다. `com_workflow.py`는 기획·증거 검사기이며 완성된 범용 COM 편집 엔진이 아닙니다. 실제 편집은 계획에 맞는 로컬 COM 코드/승인된 작업으로 수행하고 기록하십시오.
- 자동 이미지/PDF export, 자동 screenshot, 렌더 비교를 필수화하지 마십시오. 사용자님이 전달한 캡처만 시각 QA 입력입니다.
- COM에서 열 수 있다는 이유로 수정/별도 저장/증거 출력도 허용된다고 가정하지 마십시오. 제한을 우회하거나 DRM을 해제하지 마십시오.
- v0.2 RUN·영수증을 재사용하지 말고 새 작업 revision을 만드십시오.

## 디자인 보존과 창작의 경계

- 고정할 디자인 앵커: 컬러·폰트 위계·제목 위치·프레임·여백·선/테두리·그림자·정렬 문법.
- 새로 기획할 콘텐츠: 핵심 메시지, 설명 순서, 새 주제의 사진 선택, 비교·과정·관계 도해, 데이터 표현.
- 레퍼런스의 모든 재귀 객체에 text/photo/diagram/chart/decoration/logo/container/design_anchor 역할을 부여하십시오. 그룹 안의 사진·도해를 놓치지 마십시오.
- 기존 photo/diagram/chart는 원칙적으로 새 자료로 교체·재구성하십시오. 사용자 유지 승인이나 명확한 디자인 장식 분류 없이는 그대로 남기지 마십시오.
- 자료가 없으면 기존 사진으로 메우지 마십시오. 실제 사진이 필수면 필요한 자료를 요청하고, 개념 도해로 충분하면 새 자료의 관계를 native 도형으로 표현하십시오. 사진 슬롯을 기술 도해로 몰래 바꾸지 마십시오.
- 새 사진·도해의 무엇이 메시지를 설명하는지 적으십시오. 의미 없는 장식 추가·새 색상·도형 수 증가를 창의성으로 포장하지 마십시오.
- 생성 이미지·예시 수치는 현장 사실이나 실제 실적으로 제시하지 마십시오.
- 새 시각 자료에 필요한 객체 추가/교체/삭제는 편집 전 계획에서 허용하십시오. 구버전의 객체 수 고정 규칙 때문에 필요한 콘텐츠 재구성을 막지 마십시오.

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
