# 입력 JSON 계약 · 이전 실행 호환용

새 V4 작성은 이 문서를 통째로 읽지 않습니다. 처음에는 [최소 입력](v4/input.md), 이후에는 context가 지정한 현재 단계 leaf만 읽습니다.

최초 Case를 만들거나 현재 단계 입력을 쓸 때 해당 항목만 읽습니다. 사용자의 짧은 말을 모델이 변환하며 전체 예시·제작 소스 재독이나 사용자 직접 JSON 작성은 요구하지 않습니다. 모든 문자열은 확인된 자료로 채웁니다.

## Case와 원장

Case 키는 `schema_version:"1.0", case_id, title, sources:[], numbers:[], stages:[]`, 선택 `identifiers:[]`입니다. ID는 중복 없이 부여하고 계약 밖의 키는 추가하지 않습니다. 숫자가 섞인 설비명은 [식별자 원장](identifiers.md)을 필요한 때만 읽습니다.

- source: `id,text,kind` 필수, `url` 선택. kind는 `public_vendor_case|public_document|user_observation|rollout_record|synthetic_asset`만 허용합니다. 공급사 발표와 독립 검증을 구분합니다. `synthetic_asset`은 선언한 가상 설명 자산의 출처이며 asset 패널 참조에만 사용합니다. 단계·본문 패널·수치·식별자의 사실 근거로 사용하지 않습니다.
- number: `id,value,metric,kind,source_ids:[]` 필수. value는 정확한 decimal **문자열**, metric은 지표명입니다. 선택 키는 `unit,qualifier,currency,period`. qualifier는 빈 값 또는 `이상|이하`, currency는 빈 값 또는 `USD|KRW`, period는 빈 값 또는 `year|month`입니다. unit은 `%`, `건`, `시간` 등 근거의 단위입니다.
- number.kind는 `reported|derived`. derived에는 `formula:"sum",inputs:["N2","N3"]`를 추가하며 같은 통화·기간·단위의 원장 항목만 합산합니다. 미공개 값·환산·회수기간을 만들지 않습니다.

처음부터 내용 전체를 쓰지 않습니다. 아래는 **형식 초안**이며 출처·수치는 확인한 자료로 등록합니다. 원장 수치를 표시할 때만 `[[N1]]`처럼 연결하고 직접 숫자·통화·기간을 덧붙이지 않습니다.

```json
{"schema_version":"1.0","case_id":"<고유ID>","title":"<제안명>","sources":[],"numbers":[],"stages":[{"id":"problem"},{"id":"cause"},{"id":"actions"},{"id":"effects"},{"id":"rollout"}]}
```

## 현재 단계와 패널

단계는 위 ID 순서를 유지합니다. 현재 `stages/<id>.json`은 `id,title,subtitle,takeaway,source_ids:[],panels:[]`를 채웁니다. 미래 단계는 ID만 있어도 됩니다. rollout만 `scope:"proposal"|"actual"`을 추가합니다. actual은 `rollout_record` 근거가 필요하고 proposal은 검토안임을 표시합니다.

`layout_profile:"reference-v2"|"reference-v3"|"reference-v4"`는 지원된 참고 형식 배치를 선택합니다. 새 실행은 [V4 역할 계약](reference-v4.md), 기존 V3 실행은 [V3 역할 계약](reference-v3.md)을 따릅니다. V4는 아래 V3의 역할·패널 수·사진·출처·합계 규칙을 그대로 유지합니다. Core는 과거 데이터 재현을 위해 필드가 생략된 입력을 보존하지만, 일반 실행의 허용 조건은 아래와 같습니다. 다른 값·대소문자 변형·null은 허용하지 않습니다. `citation`은 사람이 읽는 짧은 출처 문자열입니다(예: `"Ecolab / Nalco Water 공개 고객사례 · 공급사 제공 데이터"`). V2에서는 선택, V3/V4에서는 필수입니다. citation도 제목·부제와 같은 숫자·식별자 원장 연결 및 단계 source_ids 대조 검사를 받으며, 출처 원장이나 source_ids를 대신하지 않습니다. 넣을 때는 빈 문자열·null 없이 작성합니다.

**일반 스킬 실행에서는 내용이 있는 단계에 `layout_profile:"reference-v2"`, `"reference-v3"` 또는 `"reference-v4"`가 필수입니다.** Core의 과거 데이터 호환성과 현재 제작 허용은 다릅니다. 기본 init은 패널이 있는 단계의 profile 누락을 파일 생성 전에 거부합니다. context·validate·render·repair·qa·save도 읽는 단계에 패널이 있는데 profile이 없으면 `needs_input`으로 멈춥니다. ID만 있는 미래 단계나 빈 panels 초안은 준비할 수 있고, 이후 내용을 채울 때 profile도 지정해야 합니다. 과거 상태의 status 조회는 가능합니다.

`-AllowLegacyFixture`는 개발자가 과거 시험·QA 기록을 재현할 때만 호출마다 명시하는 기술 옵션입니다. 스킬 작업 흐름에 넣지 않으며 상태에 영구 저장하지 않습니다. 과거 배치의 시각 품질 승인이나 새 회사 자료 제작 허가를 뜻하지 않습니다. profile을 빼고 실패한 과거 배치로 자동 전환하지 않습니다.

패널 공통 키는 `title,kind,source_ids:[]`, 선택 `tone:"normal"|"danger"|"success"`입니다. V3는 필수 `role`로 의미와 순서를 고정합니다. 허용 값은 `context|phenomenon|impact|evidence|causal|boundary|action|outcomes|details|calculation|coverage|expansion|checks`이며 단계별 위치·kind는 V3 계약을 따릅니다. 단계·패널의 source_ids에는 근거가 하나 이상 필요합니다. rollout의 proposal은 계획 패널의 빈 배열을 허용하되 asset은 항상 근거가 필요합니다. V3 단계에는 proposal도 비가상 사실 근거가 필요합니다. `source_label`은 모델 입력 금지이며 엔진이 만듭니다. V2 패널 수는 한~네 개, actions는 여섯 개까지입니다. V3는 단계마다 두~세 개, actions만 세~여섯 개입니다.

선택 `icon`은 `heat_exchanger|oil|water|microbe|clean|training|rotation|shield|monitor|check|cost|factory` 중 정확한 소문자 문자열만 허용합니다. 설명을 돕는 아이콘이며 실제 설비 사진·측정·원인 증거로 주장하지 않습니다. 선택 `outcome`은 패널의 결과·핵심을 적는 빈 값이 아닌 문자열입니다. 본문과 같은 원장 연결·출처 대조를 거치므로 숫자를 직접 쓰거나 무관한 source_ids로 표시할 수 없습니다. 예: `"세척 인건비 절감 [[N1]]"`. metrics·bars·표의 기존 metric 일치 검사와 실제 횡전개 근거 검사도 그대로 적용합니다. null·배열·객체는 허용하지 않습니다. 허용 kind는 그대로이며 다음 키만 추가합니다.

- bullets: `lines:["문구"]`, 한~여섯 줄.
- flow 또는 timeline: `steps:["단계"]`, 두~네 단계. 근거 없는 순서·시간축 금지.
- table: `table:{headers:["열명"],rows:[["셀"]]}`. 열은 네 개 이하, 데이터 행은 다섯 개 이하, 각 행의 셀 수는 header와 같습니다.
- metrics: `metrics:[{label,value_text,detail}]`, 세 항목 이하. detail은 생략/빈 값이 가능하고 나머지는 필수입니다. value_text는 정확히 `"[[N1]]"`, label은 해당 원장 metric과 완전히 같아야 합니다.
- bars: `bars:[{label,value_text,number_id}]`, 네 항목 이하. value_text=`"[[N1]]"`, number_id=`"N1"`, label=원장 metric. unit이 `%`이며 한정어 없는 정확한 값만 허용합니다. ratio는 모델이 쓰지 않습니다.
- asset: `asset:{document_name,slide_index,shape_name,description,reference_kind}`. reference_kind는 `picture|diagram`이며 현재 V3 자산 슬롯은 `picture`만 지원합니다. 선택 `origin`은 `provided|synthetic_test`이며 생략 시 provided입니다. `synthetic_test`는 패널 source_ids의 synthetic_asset 출처와 함께 선언하고, synthetic_asset을 provided로 감추지 않습니다. 가상 출처는 자산 외의 근거로 쓸 수 없습니다. `known_visible_aspect_ratio`는 COM 현재 보이는 프레임의 폭/높이이며, V3 picture에서는 유한한 양수 숫자로 필수입니다. V2에서는 선택 양수를 유지합니다. 지정된 **동일 열린 작업 문서**의 기존 객체만 가리킵니다. 파일 경로·다른 문서 참조 금지이며 지원/확인 실패 시 멈춥니다.

flow·timeline에만 선택 `step_icons:["microbe","heat_exchanger","clean"]`을 추가할 수 있습니다. steps와 개수가 정확히 같아야 하고 각 항목은 위 icon enum만 허용합니다. 배열의 순서가 단계별 아이콘의 순서입니다. 문자열 하나·null·알 수 없는 토큰·다른 kind의 step_icons는 거부합니다. 아이콘은 설명용이며 단계 순서와 인과관계의 근거는 여전히 source_ids로 확인합니다.

`reference-v4`에서만 icon·step_icons에 `vacuum_chamber|part|erosion|material|energy|tank|filter|membrane_stack`도 허용합니다. 선택 기준과 현재 단계의 지원 구성은 [V4 입력](reference-v4.md)의 해당 부분만 읽습니다. V2/V3의 아이콘 목록과 입력은 유지합니다.

V4의 `line_states`는 cause/causal/bullets에서는 선택, effects/details/bullets에서는 필수입니다. lines와 같은 길이의 배열로 정확한 문자열 `supported|hypothesis|unknown|boundary`만 허용하며 필수 위치의 누락·null·빈 배열과 비배열·다른 값은 거부합니다. 사용할 때 [문장의 상태](v4/states.md)를 읽습니다. 표·막대·이전 프로필 규칙과 기존 패널 source_ids 검사는 유지하며 줄별 근거 ID를 추가하지 않습니다.

V4 cause의 `role:"causal",kind:"bullets"`에는 선택 `statement_links:[{line_index,row_indices:[]}]`로 첫 evidence table의 행과 해석 줄을 연결할 수 있습니다. 모든 위치는 영부터 세는 정수이며 같은 line_index 중복·빈 row_indices·한 연결 안의 중복 행은 거부합니다. 일부 행만 선택할 수 있고, 다른 해석 줄이 같은 행을 다시 참조할 수 있습니다. 필요할 때만 [근거표와 해석 문장 연결](v4/statement-links.md)을 읽습니다. 기존 상태와 원본 표는 유지합니다.

V4 flow의 `role:"phenomenon"|"causal"|"expansion"`에만 선택 `evidence_links:[{step_index,panel_index,item_indices:[]}]`를 넣을 수 있습니다. phenomenon은 problem 단계에서만 허용합니다. 같은 단계의 다른 table.rows 또는 bullets.lines를 flow 단계에 연결할 필요가 있을 때만 [근거와 단계 연결](v4/evidence-links.md)을 읽습니다. 위치는 영부터 세는 정수이고 item_indices는 한~여섯 개입니다. 중복 step+panel·중복 원본 항목·참조 패널의 일부 항목 누락·flow에 포함되지 않은 출처는 거부합니다. V3 이하와 다른 역할/kind는 이 필드를 허용하지 않습니다. 원본 내용은 그대로 두고 연결 위치만 선언하며, 도구가 의미의 타당성을 보증하지 않습니다.

flow에만 선택 `relationship:"sum"`을 넣어 두 수치의 합을 표시할 수 있습니다. steps는 정확히 세 개이며 각각 `"해당 number.metric [[ID]]"` 형식이어야 합니다. 앞 두 ID는 서로 달라야 하고, 세 번째는 기존 `kind:"derived",formula:"sum"` 원장의 값이어야 합니다. 세 번째 원장의 inputs는 앞 두 ID와 **같은 순서로 정확히 두 개**여야 합니다. 기존 통화·기간·단위·합계·출처 검사를 그대로 적용하며 같은 합계값인 다른 실적을 끼워 넣지 않습니다. 이 필드를 생략한 flow는 일반 순서 화살표입니다. 다른 관계·timeline 등 다른 kind의 relationship은 허용하지 않습니다.

표의 수량 셀도 정확한 `[[N1]]`만 쓰고 같은 행 첫 셀은 원장 metric과 일치시킵니다. 모델명 숫자를 수량으로 가장하지 않습니다. 표·카드가 틀을 넘으면 내용을 정리하거나 지원하는 분할을 선택하며 글자를 줄여 밀어 넣지 않습니다.

## 자료 추가와 재개

후속 답변을 받으면 허용된 JSON에 `{"sources":[],"numbers":[],"identifiers":[]}`로 신규 ID만 준비합니다. `Invoke-Proposal.ps1 -Action update-ledger -RunDir <기록폴더> -LedgerPath <추가 JSON>` 후 `context`로 현재 단계만 읽습니다. `ledger_updated`는 추가 성공, `ledger_unchanged`는 동일 원장입니다. 기존 ID·값의 변경은 금지하며 정정은 새 실행으로 시작합니다. 완료 단계가 수정됐다면 원장 갱신도 멈춥니다. 원장 추가 후 현재 미완료 입력만 보완하고 `validate`부터 재개합니다.
