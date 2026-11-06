# 흐름 단계에 근거 항목을 붙일 때만

현재 단계 leaf가 허용한 flow에 선택 evidence_links:[{step_index,panel_index,item_indices:[]}]를 씁니다. 모두 영부터 세는 정수입니다. step_index는 현재 steps, panel_index는 같은 페이지의 다른 패널, item_indices는 그 패널 table.rows 또는 bullets.lines 위치입니다. item_indices는 한~여섯 개입니다. 자기 자신·flow·asset·metrics는 참조하지 않습니다. 문자열·소수·bool·null·범위 밖은 거부합니다.

같은 step+panel 연결을 중복하지 않습니다. 한 flow에서 원본 항목은 정확히 한 번만 연결하며 참조한 peer의 모든 행·줄을 빠짐없이 연결합니다. peer source_ids는 flow source_ids에도 모두 포함합니다. 원래 leaf의 빈 source_ids 허용은 유지합니다. 이는 내용 사이의 연결 선택이고 좌표가 아닙니다. 도구는 의미나 인과관계를 확정하지 않습니다.
