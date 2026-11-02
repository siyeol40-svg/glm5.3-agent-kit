# 요소별 필수 반복 계약 · v0.4

## 읽기 순서

이 문서는 전체 기획 확인 후 요소별 편집 시 읽습니다. 환경 한계는 [nonvisual-capabilities.md](nonvisual-capabilities.md), 전체 파일 계약은 [com-workflow.md](com-workflow.md)를 따릅니다.

## 먼저 전체를 짧게, 세부는 요소별로

레퍼런스 전 페이지의 구성·패턴·불명확한 점을 간단히 목록화하고, 새 자료의 메시지와 보유/부족 자료를 검토합니다. 모든 페이지를 깊게 분석하거나 모든 원본 구조를 재현하지 않습니다. 추천 구성·선택할 디자인 문법·기존 자산 재사용 여부를 사용자와 확인합니다. 이 전체 기획 확인은 com_workflow.py lock으로 잠급니다.

이후 카드 하나, 제목 영역 하나, 연결된 하단 도해 하나처럼 의미가 연결된 unit마다 **분석 → 필요한 질문 → 편집 허가 → 적용 → 실제 COM 재조회 비교 → 체크포인트**를 반복합니다. 사진·제목·설명을 서로 무관한 도형으로 쪼개지 않습니다. 의존하는 도해 노드/연결선도 한 unit으로 묶습니다.

## 강제되는 부분과 한계

- unit_gate.py는 이전 검사·사용자 답변·입력 해시·실제 조회값을 검사하는 로컬 상태 기계입니다. READY가 없으면 check를 받지 않고, 앞 의존 unit 미통과/다른 unit 편집 중이면 READY를 발급하지 않습니다.
- 에이전트는 READY 출력 확인 전 COM 편집 코드를 실행하지 않습니다. 한 호출씩 실행하고 짧게 보고합니다. 최종 audit도 unit gate 완료를 요구합니다.
- 이 도구가 외부 shell/COM 호출을 운영체제 수준에서 가로막지는 않습니다. 에이전트가 직접 JSON을 조작하거나 편집기를 우회하는 행위까지 막는 인증 시스템은 아닙니다. 로컬 로그도 의미를 증명하는 서명이 아닙니다.
- 편집 후 해당 unit 밖의 COM-readable 객체/페이지 크기/페이지 수 변화가 있으면 FAIL입니다. unit 안의 최종 허용 차이는 전체 native diff로 다시 검사합니다. 그림 내용 동일성 같은 미관측 내부 변화는 탐지할 수 없습니다.

## 파일 계약

새 RUN의 unit_plan.json:

```json
{
  "schema": "kit.unit-plan.v1",
  "baseline": {"path": "<saved working-copy COM snapshot JSON>", "sha256": "<JSON hash>"},
  "units": [{
    "id": "card-01", "slide": 1, "purpose": "새 근거를 설명하는 첫 카드",
    "targets": ["shape-4", "shape-5"], "depends_on": [],
    "new_shapes": [{"name": "new-card-01-callout", "bounds": [100, 100, 200, 100]}]
  }]
}
```

실제 페이지/그룹 key/좌표로 작성합니다. 모든 선택 원본 객체를 어느 unit에서 다룰지 지정합니다. depends_on은 앞에 선언한 unit만 참조합니다. 신규 객체는 미리 이름과 허용 사각형(point)을 정하며 이름 중복·영역 밖·회전 신규 객체는 이 gate의 지원 범위 밖입니다. 중첩 그룹 새 객체는 좌표 변환을 입증하지 못하면 사용하지 않습니다. 신규 객체 허용은 전체 blueprint의 native_policy에도 필요합니다.

요소별 analysis-01.json:

```json
{
  "unit_id": "card-01",
  "facts": ["COM으로 확인한 프레임/객체/기존 내용의 사실"],
  "source_refs": ["새 자료의 실제 절/페이지"],
  "adaptation": "채택할 패턴, 바꿀 구조, 새 자료 표현 방법",
  "unknowns": [{"description": "기존 사진 재사용 가능 여부", "question_id": "reuse-photo"}],
  "questions": [{"id": "reuse-photo", "question": "기존 사진을 그대로 사용해도 될까요?"}],
  "before": {"path": "<fresh working-copy COM snapshot JSON>", "sha256": "<JSON hash>"},
  "checks": [
    {"id": "title-text", "kind": "text", "target": "shape-4", "expected": "확인된 새 제목"},
    {"id": "frame", "kind": "property", "target": "shape-5", "property": "geometry", "expected": [100, 100, 200, 100, 0]},
    {"id": "callout", "kind": "exists", "result_name": "new-card-01-callout"}
  ]
}
```

unknowns/questions는 없을 때도 빈 배열로 명시합니다. 중요한 미확인을 빈 배열로 숨기지 않습니다. 모르는 점마다 질문 ID를 연결합니다. 사용자 답변은 새 analysis-02.json에 resolution=ANSWERED, answer, message_evidence{path,sha256}로 기록합니다. 사용자가 대안을 허용했다면 resolution=USER_WAIVED와 alternative도 필요합니다. 실제 답변 원문은 회사 로컬에만 둡니다. 이미 gate가 참조한 분석 파일을 덮어쓰지 말고 새 파일로 답변을 반영합니다.

답변 전 해당 편집은 NEEDS_INPUT입니다. 확실한 근거가 있는 다른 unit 분석은 가능하지만 질문 대상에 의존하는 편집은 진행하지 않습니다. 질문을 줄이려고 레퍼런스 그림을 임시로 최종본에 남기지 않습니다. 기존 명시적 허가를 다시 묻지는 않고 그 근거를 연결합니다.

## 명령과 상태

```text
python <SKILL>/scripts/unit_gate.py init --work <RUN>
python <SKILL>/scripts/unit_gate.py analyze --work <RUN> --unit card-01 --analysis <RUN>/analysis-01.json
python <SKILL>/scripts/unit_gate.py analyze --work <RUN> --unit card-01 --analysis <RUN>/analysis-02.json
python <SKILL>/scripts/unit_gate.py ready --work <RUN> --unit card-01
```

init 전에 실제 작업 복사본만 생성하고 저장된 baseline을 수집합니다. 원본 자체를 baseline으로 쓰지 않습니다. ready는 분석/답변/의존 검사/현재 before 상태/구체적인 기대값을 확인하여 편집 허가를 기록합니다. 실행기에서 이 종료 코드와 READY 출력을 확인한 뒤 해당 unit의 COM 작업만 실행합니다.

편집 후 저장하고 읽기 도구로 새 snapshot JSON을 수집합니다. 현재 com_native_manifest.ps1은 저장된 문서만 수집하므로 별도 저장되지 않은 메모리 상태를 수집했다고 가장하지 않습니다. 각 snapshot과 실행 로그는 다른 파일명으로 보존합니다. 그 뒤:

```text
python <SKILL>/scripts/unit_gate.py check --work <RUN> --unit card-01 --after <RUN>/card-01-after.json --log <RUN>/card-01-operation.log
```

도구는 예상 text/property/exists/absent를 실제 snapshot과 비교합니다. property는 geometry/z_order/fill/line/shadow/picture_crop/font_runs/text_frame/type/name/parent만 지원합니다. 값 비교는 정확 일치이며 null을 PASS로 처리하지 않습니다. 경계 오차가 필요한 별도 검사는 검증한 후 추가하고 임의 반올림으로 통과시키지 않습니다. 그림 exists는 객체 존재만 뜻하며 내용 확인은 아닙니다.

- NEEDS_INPUT: 종료 코드 2, 사용자 답변 대기.
- ANALYZED: 분석 기록 완료, 아직 편집 허가 아님.
- READY: 종료 코드 0, 지정된 unit 편집 가능.
- REQUIRES_FIX: 종료 코드 2, 기대값 불일치/범위 밖 변경. 다음 편집 차단.
- NONVISUAL_CHECKED: 종료 코드 0, 해당 snapshot의 지원 검사만 일치. 시각 QA 통과 아님.
- 입력·증거·의존·지원 검사 오류: 종료 코드 1, 편집/완료 차단.

실패 또는 재작업 시 reason을 기록하여 해당 unit과 의존 unit을 무효화합니다. 이전 기록은 history에 보존합니다. PPT 자체를 되돌리지는 않습니다. 범위 밖 변경이 있었다면 그 복구도 새 기획/작업 범위에 명시해야 하며, 편집 허가 범위를 몰래 늘리지 않습니다.

```text
python <SKILL>/scripts/unit_gate.py invalidate --work <RUN> --unit card-01 --reason "확인한 결함과 재작업 이유"
```

현재 파일 상태를 before로 다시 분석하고 질문/허가/수정/재검사를 반복합니다. 초기 전체 계획·질문 답변·unit roster를 바꾸면 새 RUN을 만들고 이전 작업은 현재 파일을 읽어 재검증합니다. 기준 snapshot을 과거로 되감거나 완료 요소를 무조건 재편집하지 않습니다. 공통 스타일/전체 구성 변경이면 영향 unit 전체를 무효화하거나 새 RUN으로 전환합니다.

## 최종 문서 검사

모든 unit을 마친 뒤 저장·닫기·재열기하여 result_native.json을 수집합니다. 원본도 승인된 읽기 경로로 다시 읽어 source_readback.json을 생성합니다. 원본 bytes/hash는 읽지 않습니다. source_readback은 읽힌 속성만 일치하는지 확인하며 원본 전체의 비트 단위 동일성을 증명하지 않습니다.

```text
python <SKILL>/scripts/unit_gate.py finish --work <RUN>
python <SKILL>/scripts/com_workflow.py audit --work <RUN>
```

finish는 모든 unit 검사 완료와 최종 COM snapshot의 일치를 확인합니다. audit는 전체 기획·예상 텍스트·예정 밖 차이·원본 readback·시각 자료 실행 기록·사용자 지적을 함께 검사합니다. 최종 구조 비교가 실패하면 unit 검사가 모두 맞아도 통과가 아닙니다. 이후 사용자 캡처와 최종 수용을 별도로 진행합니다. unit_state.json은 체크포인트이며 숨은 추론 내용을 저장할 필요는 없습니다.
