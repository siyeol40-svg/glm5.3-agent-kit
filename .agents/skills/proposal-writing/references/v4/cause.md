# V4 원인 분석

먼저 [공통 입력](common.md)을 읽고 [현재 빈 틀](../../assets/stage-inputs/v4/cause.json) 하나만 채웁니다. 필수 순서: evidence:table|asset → causal:flow|bullets. 별도 조건이 있으면 boundary:bullets를 마지막에 추가합니다. 총 두~세 패널입니다.

공급사 분석·사실·가설·미입증 연결을 구분합니다. 병렬 조건은 bullets로 쓰고 임의 순서나 확정 원인을 만들지 않습니다. 빈도가 없으면 비율을 만들지 않습니다. 독립 검증·실제 로그 분석으로 바꾸거나 효과를 중복 귀속하지 않습니다.

table은 headers와 같은 너비의 rows이며 열 네 개·행 다섯 개 이하입니다. 수량 셀은 정확한 [[ID]]이고 첫 셀은 원장 metric과 같아야 합니다. asset일 때만 [사진 규칙](asset.md)을 읽습니다. bullets icon이나 flow step_icons를 고를 때만 [도해](glyphs.md)를 읽습니다.

causal bullets의 줄을 분류할 때만 line_states와 [문장 상태](states.md)를, 근거표의 특정 행을 해석 줄에 붙일 때만 statement_links와 [문장 연결](statement-links.md)을 읽습니다. causal flow의 근거를 단계에 붙일 때만 [흐름 연결](evidence-links.md)을 읽습니다. 두 연결 방식의 전체/부분 선택 규칙을 섞지 않습니다.

validate 뒤 render -StageId cause를 실행하고 실제 검사·주장 상태·추가 근거만 보고합니다. 실패나 확인불가면 다음 단계로 넘기지 않습니다.
