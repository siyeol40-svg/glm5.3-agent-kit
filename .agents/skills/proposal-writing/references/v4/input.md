# 처음 만드는 Case와 원장

사용자에게 JSON이나 코드를 요구하지 않고 모델이 짧은 업무 자료를 정리합니다. 회사 규칙을 먼저 읽고 비Office 입력·기록 파일의 회사 읽기/쓰기 가능 여부를 별도로 확인합니다.

Case는 schema_version:"1.0", case_id, title, sources, numbers, stages이며 identifiers는 선택입니다. stages에는 problem,cause,actions,effects,rollout 순서의 id만 먼저 준비할 수 있습니다. 미래 단계 내용은 쓰지 않습니다.

source는 id,text,kind 필수, url 선택입니다. kind는 public_vendor_case|public_document|user_observation|rollout_record|synthetic_asset입니다. 허용된 원문을 확인하고 공급사 발표·관찰·독립 검증을 구분합니다. URL 연결 성공은 원문·주장의 확인이 아닙니다. synthetic_asset은 사진 설명 자산에만 쓰고 사실·수치·식별자 근거로 쓰지 않습니다.

number는 id,value,metric,kind,source_ids 필수입니다. value는 십진수 문자열, kind는 reported|derived입니다. 선택 unit, qualifier(이상|이하|미만|초과), currency(USD|KRW), period(year|month)를 근거대로 씁니다. 미공개와 영을 구분합니다. derived는 formula:"sum",inputs를 쓰며 같은 통화·기간·단위만 합칩니다. 등록 수치는 [[ID]]로 표시합니다. 숫자가 섞인 설비명은 필요할 때만 [식별자 원장](../identifiers.md)을 읽습니다.

init 성공 뒤 context가 지정한 현재 단계 지침과 자료만 읽습니다. 신규 근거 추가가 생기면 [원장 추가](ledger-update.md)만 읽습니다.

reported는 원문에 보고된 값의 출처 분류입니다. 관측 실적·기술상 가능성·전망은 metric과 업무 문장에 구분해서 유지합니다. 예상 수명을 실측 수명으로 바꾸거나 미만/초과를 이하/이상으로 바꾸지 않습니다. 지표명은 회사 표기에 맞춰 원장·표·카드에서 일치시킵니다.
