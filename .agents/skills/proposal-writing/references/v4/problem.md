# V4 문제 현상

먼저 [공통 입력](common.md)을 읽고 이 단계만 작성합니다. 빈 틀은 [사진 없음](../../assets/stage-inputs/v4/problem-no-photo.json) 또는 [사진 있음](../../assets/stage-inputs/v4/problem-photo.json) 중 하나입니다.

필수 순서: context:bullets|asset → phenomenon:flow. 별도 근거가 있으면 마지막에 impact:bullets를 추가합니다. 총 두~세 패널입니다. 대상·관찰 현상·근거를 쓰고 빈 사진 틀이나 빈 문구로 채우지 않습니다. 발생 횟수·시간이 없으면 영·시간축을 만들지 않습니다. 한 사례를 전체 빈도로 확대하지 않습니다. 정상 과정·원인·대책·효과를 임의로 보충하지 않습니다.

bullets에는 icon, flow에는 step_icons가 필요하며 그때만 [도해 목록](glyphs.md)을 읽습니다. asset을 쓸 때만 [사진 규칙](asset.md)을 읽습니다. phenomenon에 근거 항목을 붙일 때만 [흐름 연결](evidence-links.md)을 읽습니다.

두 패널·사진 없는 구성에서 context를 첫 흐름 단계에 모두 연결하면 배경 띠와 등폭 도식을 씁니다. 이 구성은 context.outcome을 지원하지 않습니다. 중요한 결론을 버리지 말고 지원하는 다른 구성을 고릅니다. 사진 구성은 별도 impact를 마지막 단계에 연결할 수 있습니다.

validate 뒤 지정된 열린 문서에 render -StageId problem을 실행합니다. 실제 검사와 모르는 항목을 짧게 보고합니다. 화면을 보지 않았으면 실제 가독성 합격으로 쓰지 않습니다.
