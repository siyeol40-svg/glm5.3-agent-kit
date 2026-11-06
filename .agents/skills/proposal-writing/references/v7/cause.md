# 원인 분석 · 일반 EDR 원리

[공통 규칙](common.md)과 [현재 빈 양식](../../assets/stage-inputs/v7/cause.json)만 읽습니다. `visuals.kind:"edr_mechanism"`, `scope:"general_principle"`로 공식 근거가 있는 일반 EDR 기전을 선택합니다. 실제 고객 배관도·설치 스택 수·현장 실측 검증으로 표현하지 않습니다.

패널 순서는 `system/bullets` 4문장, `evidence/table` 5행2열, `causal/bullets` 4문장, `boundary/bullets` 3문장입니다. 최소15항목을 유지합니다. 일반 원리와 해당 사례의 선정 근거·적용 조건을 구분합니다. 도해에서 Water는 Membrane 표면의 channel을 따라 흐르고, 선택된 Ion은 교대로 쌓은 Membrane을 통과합니다. 물 자체의 막 투과를 주원리로 그리지 않습니다.

`causal`에 EDR 자체의 특성과 전처리·통합 공정의 운전 관리가 함께 있으면 제목에 두 범위를 드러냅니다. 예를 들어 ‘EDR 특성과 운전 관리’ 아래에 ‘운전 관리 · 잔류 Chlorine으로 Biogrowth 제어’를 둡니다. 잔류 Chlorine 관리는 통합 공정 근거에 연결하고 Membrane이나 Polarity Reversal의 작용으로 설명하지 않습니다.

`evidence` 표에서 수치를 표시하는 셀은 정확히 단일 `[[ID]]` 하나만 사용합니다. `[[N1]]–[[N2]]`, `SDI ([[N3]] 측정)`, `[[N4]], 주로 Silica`처럼 복수 binding·범위·설명을 같은 수치 셀에서 임의 조합하지 않습니다. 범위나 측정 조건은 원장을 보존한 채 해당 역할에 맞는 지원 일반 문장 또는 구성으로 표현합니다. 일반 문장에서는 여러 원장 binding으로 범위를 쓸 수 있지만 조건을 삭제하거나 숫자를 새로 만들지 않습니다. 현재 빈 양식에 `notes` 같은 미지원 필드를 추가하지 않으며, 필요한 뜻을 지원 구성에 담을 수 없으면 미지원으로 남깁니다.

`visuals.feature_indices`에는 아래 네 키만 넣습니다. 값은 해당 `system.lines`의 번호인 정수0~3이며 네 값이 서로 달라야 합니다. 빈 양식의 `null`을 실제 번호로 바꾸고 문장 순서가 바뀌면 번호도 함께 맞춥니다.

| 키 | 연결할 설명에 필요한 English 의미 표지 |
|---|---|
| `electric_field` | `Electric Field` |
| `selective_membrane` | `Selective Membrane`, `Cation`, `Anion` 중 해당 표지 |
| `separate_channels` | `Diluate`와 `Concentrate` 모두 |
| `water_channel` | `Water`와 유로/channel/surface/표면 중 하나 |

표지는 문구와 도해 연결을 확인하는 제한된 규약이며 원문 근거를 대신하지 않습니다. 네 설명은 해당 도해 요소 가까이에 놓입니다. 화살표는 공식 물리적 경로에만 쓰며, 독립적인 대응 특성 사이에 인과 화살표를 넣지 않습니다.

조건표와 대응 특성의 관계가 근거에 명시되어 있으면 선택적으로 `visuals.condition_links`를 사용합니다. 키는 `silica/bio/variation` 세 개이며 각 값에 `condition`(evidence 행 번호0~4), `trait`(causal 문장 번호0~3)만 넣습니다. 행/문장 번호를 중복 사용하지 않습니다. Silica↔Silica, Temp·Organic·Biogrowth 조건↔Chlorine 관리, Feed 변동↔Voltage·TDS 대응이라는 지원 관계에만 쓰며 양쪽 직접 출처를 유지합니다. 도구가 A/B/C 참조기호를 붙입니다. 가능하면 연결된 행과 문장을 두 영역에서 같은 읽기 순서로 두고, 순서를 바꾼 뒤 번호를 다시 맞춥니다. 의미 표지 검사는 근거 검토를 대신하지 않으며 근거 없는 인과·확정 효과를 만들지 않습니다. 해당 세 관계가 없으면 필드 전체를 생략하고 임의 연결을 추가하지 않습니다.

현재 `causal`은 병렬 bullets만 지원합니다. `causal.line_states`는 생략 또는 문장마다 `supported`만 지원하며 `hypothesis/boundary/unknown`은 지원하지 않습니다. 다른 패널에 `line_states`를 추가하지 않습니다. 가설·미확인을 확정 사실로 바꾸지 말고 V6 지원 범위를 확인하거나 미지원으로 보고합니다. 모든 원문 조건과 출처를 유지합니다.
