# V4 효과 파악

먼저 [공통 입력](common.md)을 읽고 [현재 빈 틀](../../assets/stage-inputs/v4/effects.json)만 채웁니다. 필수 순서: outcomes:metrics → details:table|bars|bullets. 검증된 비용 합계가 있을 때만 calculation:flow를 마지막에 추가합니다. 총 두~세 패널입니다. 기술 성과만 있어도 되며 금액을 만들지 않습니다.

metrics는 세 항목 이하의 label,value_text,detail이며 label은 원장 metric, value_text는 정확한 [[ID]]입니다. table은 열 네 개·행 다섯 개 이하이고 수량 셀은 [[ID]], 첫 셀은 metric과 같아야 합니다. bars는 네 항목 이하의 label,value_text,number_id이며 한정어 없는 정확한 퍼센트만 씁니다. ratio를 입력하지 않습니다. 이상/이하를 없애지 않습니다.

공개 효과와 미산출·추가 확인 문장은 나누어 씁니다. details:bullets를 선택하면 lines와 같은 길이의 line_states가 필수이므로 [문장 상태](states.md)를 읽고 줄마다 직접 분류합니다. 누락·null·빈 배열은 제작 전에 거부합니다. details:table|bars에는 이 필드를 넣지 않습니다. supported는 독립 검증을 뜻하지 않습니다. bullets icon을 고를 때만 [도해](glyphs.md)를 읽습니다. calculation을 실제 넣을 때만 [비용 합계](sum.md)를 읽습니다.

비용의 항목·기간·통화를 유지합니다. 발표 절감액을 투자비·운영비를 뺀 순효과로 부르지 않습니다. 환산·회수기간·시간 현금화·전후 원자료·영 실적을 만들지 않습니다. 음수와 효과 없음도 보존합니다. validate 뒤 render -StageId effects를 실행하고 미산출 항목을 함께 보고합니다. 계산 통과는 경제성·미학 합격이 아닙니다.
