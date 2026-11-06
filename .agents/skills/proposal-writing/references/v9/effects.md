# 효과 파악 · 같은 기준의 수치 비교 V9

`layout_profile:"reference-v9"`와 [단일 배수 양식](../../assets/stage-inputs/v9/effects-relative.json) 또는 [시점별 수치 양식](../../assets/stage-inputs/v9/effects-series.json) 중 하나를 사용합니다. 순서는 핵심 지표, 세부 근거, 정성 운영 변화, 적용 범위입니다. 본문에서 서로 다른 정보 15개를 확보하고, 근거 부족은 질문하거나 미완료로 남깁니다.

- `visuals.kind:"relative_comparison"`은 기존과 비교한 하나의 보고 배수입니다. 확정된 양의 `배` 값과 직접 출처, 기존 또는 비교 기준을 적은 `detail`이 필요합니다. 기준 길이를 1로 맞추며 실제 수명이나 절대량을 만들지 않습니다.
- `visuals.kind:"series_comparison"`은 같은 기준·단위·기간의 확정 수치 2~3개를 비교합니다. 다른 날짜는 원장으로 연결합니다. 각 `metric_states`를 `actual` 또는 `forecast`로 지정하며, 전망은 수치의 직접 출처 및 화면의 지표명이나 설명에도 표시합니다. 실적과 전망의 합계는 만들지 않습니다.
- 수치마다 `value_text`에는 정확히 하나의 `[[ID]]`를 쓰고, 지표명은 원장과 일치시킵니다. 효과량의 기준 설명을 동일하게 적습니다. 내부 `resolved_metrics`나 위치·크기·색을 작성하지 않습니다.

회사에서는 이미 열린 지정 PowerPoint의 COM만 사용합니다. 화면 캡처나 자동 시각 QA가 필요하지 않습니다. 비교 근거가 맞지 않는 자료는 [V6 효과 틀](../v6/effects.md)의 지원 범위를 확인합니다.
