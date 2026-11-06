# 참고형 V3 입력

현재 단계의 업무 사실과 허용된 자산 참조만 넣습니다. `layout_profile:"reference-v3"`와 패널 `role`은 아래 순서를 지킵니다. 좌표·색·글자 크기를 입력하지 않습니다. 사진 유무와 자료량에 맞는 지원 구성을 선택하고, 지원하지 않는 구조는 자료 보완 또는 분할로 처리합니다.

| 단계 | 필수 패널 순서와 kind | 선택 마지막 패널 |
|---|---|---|
| problem | context: bullets 또는 asset → phenomenon: flow | impact: bullets |
| cause | evidence: table 또는 asset → causal: flow 또는 bullets | boundary: bullets |
| actions | action: bullets, 세~여섯 개 | 없음 |
| effects | outcomes: metrics → details: table 또는 bars 또는 bullets | calculation: 검증된 sum flow |
| rollout | coverage: table → expansion: flow | checks: bullets |

actions 외에는 두~세 패널만 씁니다. 선택 패널에 별도 근거가 없으면 생략합니다. 출처 범위 설명을 큰 패널로 만들어 화면을 채우지 않습니다. `source_meta` 역할은 없습니다. 각 패널에는 역할에 맞는 제목을 쓰고, 조치 카드의 `outcome`을 쓸 때는 조치의 목적을 짧게 덧붙입니다. 본문을 반복하지 않습니다. 병렬 기여 조건은 causal의 bullets로 나타내고, 자료가 입증하지 않은 순서를 flow로 만들지 않습니다.

V3의 bullets에는 승인 목록의 `icon`을, flow에는 단계마다 하나씩 `step_icons`를 반드시 넣습니다. actions의 각 카드에는 짧은 `outcome`도 필수입니다. 아이콘은 설명용 고정 도형이며 실제 현장·측정 증거가 아닙니다. 빈 틀의 빈 문자열/배열은 작성할 자리이며 완성 입력이 아닙니다. 조치 다섯~여섯 개는 세 열·두 줄 고정 카드로, 세~네 개는 한 줄 카드로 배치됩니다. 사진의 가로/세로/정사각형 구분과 표 높이는 선언된 COM 비율·자료량으로 도구가 고릅니다.

모든 단계는 사람이 읽는 짧은 `citation`과 비가상 사실 출처를 가리키는 `source_ids`가 필요합니다. citation은 원장이나 출처 연결을 대신하지 않습니다. 수치·기간·설비 식별자는 기존 원장의 `[[ID]]` 연결로만 표시합니다. derived 합계는 모든 입력 출처를 단계와 해당 합계를 표시하는 패널의 source_ids에 모두 연결합니다. metrics의 label, 표의 수량 행 첫 셀, bars의 label은 원장 metric과 일치시킵니다.

비용이 없는 기술 성과도 effects에 넣을 수 있습니다. 감소율·가동 시간 등 확인된 지표를 outcomes에 넣고, 비교나 조건을 details에 씁니다. 금액·합계를 만들 필요가 없습니다. V3의 sum 관계는 calculation 역할에서만 허용하며, 통화가 USD 또는 KRW인 검증된 비용 합계만 넣습니다. 비금액 합계는 이 슬롯에 넣지 않고 기술 성과의 지표로 다룹니다. calculation을 추가할 때 `kind:"flow",relationship:"sum"`을 쓰며, 앞 두 원장의 같은 통화·기간·단위 합이 마지막 derived 원장과 연결되어야 합니다. 각 단계는 정확히 `"지표명 [[ID]]"` 형식이고, 세 번째 원장의 inputs는 앞 두 ID와 같은 순서로 일치해야 합니다.

사진 입력은 [사진용 빈 틀](../assets/stage-inputs/v3/problem-photo.json), 사진이 없으면 [사진 없는 빈 틀](../assets/stage-inputs/v3/problem-no-photo.json)에서 시작합니다. 현재 단계의 틀 하나만 읽고 빈 내용을 업무 사실로 채웁니다. 빈 패널이나 선택 패널을 늘려 지면을 채우지 않습니다. 다른 단계의 빈 틀은 같은 폴더에 있습니다.

asset은 지정된 동일 열린 작업 문서에 이미 있는 COM 객체만 참조합니다. 키는 `document_name,slide_index,shape_name,description,reference_kind,known_visible_aspect_ratio`, 선택 `origin`입니다. 현재 V3 자산 슬롯은 `reference_kind:"picture"`만 지원합니다. diagram은 기존 R2 경로에서만 지원하며 V3에서 사진으로 대체하지 않습니다. `origin`은 `provided|synthetic_test`이며 생략 시 provided입니다. picture의 비율은 COM에서 확인한 현재 보이는 프레임의 폭/높이인 양수 숫자입니다. 파일 정보나 이미지 내용 판독을 추정해 넣지 않습니다. 사진은 원 프레임을 보존하는 contain 배치로 들어가며 강제 잘라내기·가로세로 변형은 지원하지 않습니다.

Codex가 준비한 가상 시험 이미지는 `source.kind:"synthetic_asset"`와 `asset.origin:"synthetic_test"`를 함께 선언합니다. 이 출처는 해당 설명용 asset 패널의 source_ids에만 넣습니다. 단계 citation의 source_ids, 본문 패널, 수치·식별자 원장의 근거로 쓰지 않습니다. synthetic_test는 synthetic_asset 출처가 필수이고, synthetic_asset 출처를 provided 자산으로 표시할 수 없습니다. 엔진은 표시 위치에 가상 이미지임을 붙입니다. 이 자산은 실제 설비 상태·개선 실적을 증명하지 않으며 회사에서 생성 서비스나 새 연결을 요구하지 않습니다.

rollout은 `scope:"proposal"`이면 검토안·적용 실적 아님을 표시합니다. 이 경우 계획 패널은 빈 source_ids를 사용할 수 있으나 단계에는 공개 사실 출처가 필요하고, 숫자를 표시하면 해당 원장 근거도 연결합니다. `scope:"actual"`은 모든 패널에 rollout_record 근거가 있어야 합니다. 미공개 대수·일정·확대 실적을 만들지 않습니다.
