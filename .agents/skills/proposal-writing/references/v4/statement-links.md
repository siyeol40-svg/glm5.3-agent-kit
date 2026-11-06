# 근거표 행과 해석 문장을 연결할 때만

현재 단계 leaf가 허용한 causal bullets에 선택 statement_links:[{line_index,row_indices:[]}]를 씁니다. peer는 첫 evidence 패널의 table입니다. line_index는 causal.lines, row_indices는 table.rows에서 영부터 세는 정수입니다. 같은 줄의 연결은 하나, row_indices는 비우지 않습니다. 문자열·소수·bool·null·범위 밖·한 연결 안의 중복 행을 거부합니다. 같은 행을 다른 해석 줄에서 다시 쓰는 것은 허용합니다.

필요한 행만 고르고 미선택 행도 원본 표에 남깁니다. evidence source_ids를 causal source_ids에 모두 포함합니다. 연결이 가설·추가확인을 입증으로 바꾸거나 인과관계를 확정하지 않습니다. 사용하지 않으면 생략합니다.

연결하는 해석이 한 개이면 직각 연결선을 사용합니다. 여러 개이면 선 겹침을 피하도록 각 해석 옆에 연결한 원본 행 이름을 표시합니다. 여러 해석 연결은 두 패널 원인 페이지에서만 지원합니다. 별도 boundary 패널이 필요하면 지원되는 구성을 고르거나 경계 내용을 causal의 boundary 문장으로 보존하며, 중요한 제한을 삭제하지 않습니다.
