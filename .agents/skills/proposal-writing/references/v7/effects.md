# 효과 파악 · 지표 의미별 표현

[공통 규칙](common.md)과 [현재 빈 양식](../../assets/stage-inputs/v7/effects.json)만 읽습니다. 패널 순서는 `outcomes/metrics` 3개, `details/table` 5행2열, `operation/bullets` 4문장, `boundary/bullets` 정성3문장입니다. 최소15항목을 유지합니다. 아래 모든 지표와 조건에 근거가 있을 때만 이 profile을 선택합니다.

`visuals.kind:"performance"`이며 순서는 고정입니다. `metric_kinds`는 `[recovery_percent,removal_percent,upper_bound]`, `detail_kinds`는 `[combined_multiplier,projected_lifetime,supply_spec,biogrowth_control,silica_observation]`, `interval_line`은 정수0입니다. 항목을 교환하거나 종류만 바꿔 다른 뜻의 수치를 넣지 않습니다. 표 행·패널·원장의 지표명을 정확히 맞춥니다.

첫 두 지표는 각각 Recovery와 Removal의 확정%0~100이며 `value_text`에는 해당 원장 바인딩 하나만 넣습니다. 셋째는 농도의 엄격한 `미만` 상한입니다. 상한을 확정 농도나 법정 기준값으로 쓰지 않습니다. 상세표 첫 행은 병용 수명비(단위 배), 둘째는 예상/전망을 명시한 수명(년·초과), 나머지는 공급 수질·생물 관리·Silica 관찰입니다. 전망은 지표명과 문구에 남깁니다.

현재 `combined_multiplier`는 Filter와 Residual Chlorine 병용 성과만 지원합니다. 해당 숫자의 직접 출처에서 두 조건을 확인하며 도구는 수명비 옆에 병용 조건을 표시합니다. 비교 기준·절대 수명을 새로 만들지 않습니다.

`operation.lines[0]`은 `CIP 간격 [[하한ID]]–[[상한ID]]` 또는 `CIP Interval [[하한ID]]–[[상한ID]]` 형식입니다. 두 바인딩은 서로 다른 ID, 같은 개월 단위, 양수 하한≤상한이어야 합니다. CIP 범위를 Before/After·부터·연장·개선 문장으로 바꾸지 않습니다.

고정 그래프는 수치의 뜻을 보여줍니다. Ratio grid는 실제 입자 수나 표본 사진이 아닙니다. Recovery·Removal·처리수 상한을 같은 샘플의 질량수지로 역산하지 않습니다. 정성 효과에 미공개 금액·절감률을 넣지 않습니다. 지원 지표가 빠지면 V6 지원 범위를 확인하거나 자료 부족으로 남깁니다.
