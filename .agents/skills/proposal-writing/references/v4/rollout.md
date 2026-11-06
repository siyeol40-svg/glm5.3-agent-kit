# V4 횡전개

먼저 [공통 입력](common.md)을 읽고 [현재 빈 틀](../../assets/stage-inputs/v4/rollout.json)만 채웁니다. 필수 순서: coverage:table → expansion:flow. 별도 확인 항목이 있으면 checks:bullets를 마지막에 넣습니다. 총 두~세 패널입니다. table은 열 네 개·행 다섯 개 이하이며 수량은 원장과 연결합니다.

scope:actual은 모든 패널에 rollout_record 근거가 필요합니다. 미공개 대수·날짜·상태·효과·확대 실적을 만들지 않습니다. scope:proposal은 '검토안 · 적용 실적 아님'으로 표시합니다. 계획 패널 source_ids는 비울 수 있지만 단계 citation과 source_ids에는 출발점인 실제 공개 사실이 필요합니다. 표시 수치는 원장 출처와 연결합니다. 시험 성과를 계획 대상 전체에 곱하지 않습니다.

flow step_icons·선택 bullets icon을 고를 때만 [도해](glyphs.md)를 읽습니다. expansion에 근거 항목을 붙일 때만 [흐름 연결](evidence-links.md)을 읽습니다. 네 단계 중 coverage가 앞 세 단계에만 연결되고 마지막에 추가 근거가 없으면 마지막은 마무리 띠입니다. 이 구성의 flow.outcome은 지원하지 않습니다. 중요한 문장을 버리거나 중복 결론을 추가하지 않습니다.

validate 뒤 render -StageId rollout을 실행합니다. 전 단계 성과를 다른 설비 성공으로 확대하지 않습니다. 완료 후 [최종 검사](../06-finalize.md)만 읽습니다.
