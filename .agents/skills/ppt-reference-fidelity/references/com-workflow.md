# COM_USER_CAPTURE 실행 계약 · v0.4

현재 회사용 기본 프로필입니다. ZIP/XML 직접 접근, 자동 렌더·export·화면 캡처를 요구하지 않습니다. 구버전 gate.py는 PACKAGE_NATIVE_LEGACY 전용이며 이 프로필에서 실행하지 않습니다.

## 1. 로컬 적용과 준비

루트 README의 bootstrap check/apply/verify를 따르고 실제 활성 지침을 확인합니다. instruction_loading.json에는 status=PASS, active_files[{path,sha256}], evidence{path,sha256}, bootstrap_receipt{path,sha256}를 기록합니다. 실제 로딩 근거가 없으면 PASS로 만들지 않습니다. 파일 배포 성공과 활성 로딩 성공은 다릅니다.

새 RUN을 만듭니다. source와 candidate 경로를 분리하고 회사 허용 로컬 증거 폴더만 씁니다. com_capabilities.json의 route는 COM_USER_CAPTURE입니다. operations의 open/read_objects/create_copy/edit/save/reopen 각각 실제 status, exit_code, log{path,sha256}를 기록합니다. 수행 전에는 NOT TESTED로 남깁니다. 이 파일은 테스트 프로그램이 실제 실행했다는 기록이며 사용자가 임의로 PASS를 기입할 양식이 아닙니다. export는 현재 프로필에서 시도하지 않습니다.

## 2. 원본 객체와 기획

승인된 PowerPoint COM 경로로 원본을 읽고 reference_native.json을 생성합니다.

```text
powershell -NoProfile -File <SKILL>/scripts/com_native_manifest.ps1 -Pptx <REFERENCE> -Output <RUN>/reference_native.json
```

이미 열린 문서에 연결해야 하는 환경에서만 -UseOpenPresentation을 사용합니다. 해당 옵션은 Windows PowerShell/.NET Framework의 active-object 연결 가능 여부를 실제 확인해야 합니다. 원본을 자동 저장하거나 사용자가 열어 둔 앱을 종료하지 않습니다. 실행 정책 우회 옵션은 쓰지 않습니다.

스냅샷은 slide-local 객체·그룹·읽을 수 있는 속성만 수집합니다. 원본 파일을 ZIP으로 읽거나 bytes hash하지 않습니다. identity는 경로/크기/mtime metadata이며 강한 내용 증명이 아닙니다. 읽을 수 없는 속성은 null과 unreadable_properties에 남깁니다. SmartArt/테이블/차트 내부까지 읽었다고 가장하지 않습니다.

[content-adaptation.md](content-adaptation.md)에 따라 reference_analysis.json과 material_review.json을 먼저 작성합니다. 활용할 패턴/구성·부족한 자료·기존 시각 자료 재사용 대상을 사용자에게 묶어 확인하고 plan_confirmation.json으로 실제 메시지와 세 파일 해시를 연결합니다. 확인 전에는 편집하지 않습니다.

content_blueprint.json을 [examples/content_blueprint.example.json](../examples/content_blueprint.example.json)에 맞춰 실제 원본 key·새 자료·메시지로 작성합니다. 이 예제를 그대로 실행 결과로 쓰지 않습니다. 선택한 원본 skeleton의 전체 객체 역할 분류, 옛 사진/그림별 결정, 새 시각 컨셉, 텍스트 슬롯, 캡처 요청 영역을 확정합니다. allowed_native_changes는 source/result의 COM-readable 속성에서 허용하는 exact path/before/after/reason입니다. 문구는 text_slots.expected_text로 직접 검사하므로 native allowance에서 텍스트 경로를 중복 허용할 필요가 없습니다. text bounds는 파생값이라 원본과 똑같아야 한다고 요구하지 않고, 회전/그룹 변환이 없는 지원 텍스트에서는 내부 공간 초과를 별도로 검사합니다. 그 외 fit·자동축소는 PARTIAL로 남겨 캡처에서 확인합니다. font_runs의 내용 문자열은 text readback으로, 인접한 동일 font run은 정규화하여 서식으로 비교합니다.

신규 객체는 새 내용을 표현하기 위해 필요한 경우 visual slot의 native_policy로 허용할 수 있습니다. 예: {"allow_new":true,"bounds":[100,300,700,150],"name_prefix":"new-topic-","max_new_objects":12,"remove_targets":["shape-8"]}. bounds는 원본 COM의 point 좌표로 확정한 콘텐츠 영역입니다. 실제 새 shape의 name/geometry/개수를 검사하며, 새 ID를 편집 전에 예측할 필요는 없습니다. 원본 삭제는 명시한 key만 허용합니다. 새로 만든 그룹의 로컬 좌표를 슬라이드 절대 좌표로 오인하지 않습니다. 필요한 경우 초기에는 그룹 없이 구성하고 캡처를 확인합니다. 전체 화면 재구성이 필요하면 선택한 디자인 앵커와 구체적 변경을 사용자 확인 계획에 명시합니다. 제한을 없애기 위해 전체 영역을 포괄 허용하지 않습니다.

원본 객체의 photo/diagram/chart 역할을 바꾸려면 role_change_reason에 근거를 적습니다. 슬롯 의미를 나중에 몰래 변경하지 않습니다. text_slots는 원본의 모든 내용 텍스트를 커버해야 합니다. 삭제한 텍스트는 decision=remove, 새 이름의 객체에 옮기면 result_name으로 새 객체를 찾도록 선언할 수 있습니다.

```text
python <SKILL>/scripts/com_workflow.py blueprint --work <RUN>
python <SKILL>/scripts/com_workflow.py lock --work <RUN>
```

reference_slide로 원본 skeleton을 선택/재배열/반복하며 출력 slide는 연속 번호입니다. 구성 변경은 adaptation_reason으로 설명합니다. 제외한 원본 페이지를 결과에 억지로 넣지 않습니다. COM 복사/슬라이드 재배열 이후 shape key가 변하면 확인된 새 매핑으로 새 기획 revision을 작성합니다.

lock은 실제 사용자 기획 확인과 해시 일치를 검사합니다. 확인 자료가 바뀌면 재확인하고 새 revision을 만듭니다. 잠금은 계획이 생겼다는 뜻이며 편집/검증 성공이 아닙니다. 잠금 이후 계획을 바꾸려면 변경 이유와 기존 RUN을 보존하고 새 revision으로 시작합니다. 결과 diff를 보고 모든 차이를 일괄 허용하지 않습니다.

## 3. COM 복사본 편집과 재열기

[short-step-execution.md](short-step-execution.md)에 따라 도구 하나씩 호출·확인하고 스크립트를 작은 완전한 단위로 저장합니다. 긴 응답에 코드를 몰아 출력하지 않습니다.

현재 문서에 맞는 승인된 COM 코드로 작업 복사본을 만들고 편집합니다. Kit은 범용 COM 편집 엔진을 제공하지 않습니다. 에이전트가 실제 도구/API와 객체에 맞춰 작성·실행해야 하며, 존재하지 않는 메서드를 추정하지 않습니다. PPT Master의 ZIP roundtrip으로 되돌아가지 않습니다.

[unit-workflow.md](unit-workflow.md)의 init/analyze/ready/check 반복을 필수로 수행합니다. baseline은 작업 복사본이며 각 요소는 READY 이후에만 편집합니다. unit_plan.json/unit_state.json과 버전별 분석·snapshot·로그를 보존합니다. [실제 비시각 한계](nonvisual-capabilities.md)는 PASS로 채우지 않습니다.

문장 치환뿐 아니라 계획한 새 사진·도해를 실제로 구현합니다. visual_implementation.json은 candidate_revision과 items를 갖습니다. 각 item: id/decision/result_targets/observations, 새 자료를 구현한 경우 implemented_concept, operation_log{path,sha256}; 새 사진이면 asset{path,sha256}도 필요합니다. 역할이 같은 기존 사진을 그대로 유지하려면 실제 사용자 유지 승인 근거가 있어야 합니다.

로그·새 asset 파일은 실행 흔적과 출처를 연결할 뿐 실제 삽입 이미지의 의미까지 자동 증명하지 않습니다. 실제 모습을 확인할 사용자 캡처 단계가 필요합니다.

저장·닫기·재열기 뒤 같은 manifest 도구로 result_native.json을 생성합니다. 재열기 성공만으로 시각 QA나 ZIP 무결성까지 통과한 것으로 보고하지 않습니다.

## 4. 사용자 캡처와 알려진 결함

사용자에게 현재 후보 revision/슬라이드/필요한 detail 영역을 명시하여 캡처를 요청합니다. 별도 이미지를 자동 추출하거나 캡처하지 않습니다. 캡처 대기 중 가능한 기획·내용 readback·COM 속성 비교는 마무리하되 시각 검토 완료로 처리하지 않습니다.

capture_qa.json에는 candidate_revision, regions를 기록합니다. regions의 각 항목:

- id: blueprint의 capture_regions id.
- provided_by=user, capture_origin=user_screenshot.
- image{path,sha256}: 사용자가 준 현재 후보 캡처.
- reference_image{path,sha256}: 사용자가 준 대응 원본 캡처/참조 이미지.
- reviewer, reviewer_mode(user/tool), observations, review_report{path,sha256}: 실제 검토 의견과 원문.
- tool 모드에서는 reviewer가 look_at 또는 call_omo_agent:multimodal-looker이며 tool_evidence{call_id,input_image_sha256}가 필요합니다. user 모드에는 user_review_evidence{path,sha256}를 남깁니다.
- checks: overview는 alignment/hierarchy/reference_structure/content_relevance/visual_brief_match. detail은 위 항목에 text_clipping/overlap/image_crop/spacing/shadow/border까지 포함합니다. 값은 PASS/FAIL/NOT REVIEWED입니다.

캡처가 불완전하거나 글자가 보이지 않으면 NOT REVIEWED입니다. look_at/looker가 실제 처리한 입력/응답을 남깁니다. 일반 보고 한 줄을 전체 PASS로 복제하지 않습니다. 사용자 캡처 자체도 현재 파일과의 관계가 사용자의 전달에 의존하므로 자동 증명이라고 주장하지 않습니다.

known_issues.json의 issues 배열에 사용자 지적을 보존합니다. 각 항목: id/description/reported_by/status/report_evidence. 사용자 지적을 RESOLVED로 닫을 때 fix_description, confirmed_by=user, confirmation_evidence{path,sha256}가 필요합니다. 같은 이전 사진이 남았다는 지적을 "스타일 유지 의도"로 반박하며 닫지 않습니다.

## 5. 최종 수용

```text
python <SKILL>/scripts/com_workflow.py audit --work <RUN>
```

이 명령은 source_readback.json으로 원본의 읽힌 속성만 비교하고, unit_gate.finish로 모든 요소 검사·최종 snapshot 일치를 확인한 뒤 native_diff.json과 com_receipt.json을 만듭니다. source readback은 내용 해시를 대체하지 않습니다. 종료 코드 0은 사용자 수용 기록 완료, 2는 캡처/수용 대기 또는 수정 필요, 1은 증거·필수 검사 실패입니다. 대기 상태를 오류가 없다는 이유로 PASS로 바꾸지 않습니다.

- AWAITING_USER_CAPTURE: 필요한 사용자 캡처 미확보.
- REQUIRES_FIX: 도구가 발견한 미해결 결함/열린 사용자 지적이 있음. 실제 사용자 확인으로 도구 오탐을 정정한 경우는 별도 기록.
- AWAITING_USER_ACCEPTANCE: 캡처 의견은 있으나 사용자 최종 수용 없음.
- USER_ACCEPTED_WITH_LIMITATIONS: 현재 후보/캡처 세트에 대해 실제 사용자가 수용했으며 검사 한계가 보존됨.
- FAIL: 변경 허용 범위·내용 readback·실제 실행 증거 등이 실패.

user_acceptance.json은 approved_by=user, decision=APPROVED, candidate_revision, capture_qa_sha256, acknowledged_limitations=true, message_evidence{path,sha256}입니다. 실제 사용자 메시지만 근거로 합니다. 캡처 업로드나 침묵을 승인으로 취급하지 않습니다. 사용자가 직접 검토했지만 도구가 판독하지 못한 항목은 수용할 수 있으며, 그 경우 model_unreviewed_regions를 남깁니다. 도구 오탐을 사용자가 명시적으로 정정하려면 해당 region.user_disposition에 decision=ACCEPT_AS_IS와 message_evidence를 기록합니다. 모델의 FAIL 의견은 삭제하지 않습니다. 객관적 COM 내용/구조 FAIL이나 미해결 사용자 지적은 사용자 수용 기록으로 덮어쓰지 않습니다.

이 프로필은 package_integrity=NOT_CHECKED_DRM_PROFILE, automatic_render=NOT_USED_USER_CAPTURE를 남깁니다. COM 속성 일부가 unreadable이면 native_properties=PARTIAL입니다. 최종 상태도 완전한 기술 검증 PASS가 아니라 한계를 가진 사용자 수용입니다. local JSON/로그는 서명된 도구 실행 인증이 아닙니다.

미해결 사용자 지적은 캡처가 아직 없어도 REQUIRES_FIX와 unresolved_issues로 유지합니다. pending_inputs에는 캡처/확인이 아직 필요한 점을 함께 표시합니다. 대기 상태 때문에 기존 결함 이력이 사라지지 않게 합니다.
