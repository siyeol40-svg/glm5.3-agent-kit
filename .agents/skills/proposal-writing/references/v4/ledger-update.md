# 근거를 추가하고 재개하기

허용된 JSON에 sources,numbers,identifiers의 신규 ID만 준비합니다. update-ledger -LedgerPath로 추가한 뒤 context의 현재 미완료 단계만 보완합니다. 기존 ID·값은 바꾸지 않으며 정정은 새 실행입니다. 완료 단계 내용이 바뀌면 중단합니다. ledger_updated는 추가 성공, ledger_unchanged는 동일 원장입니다. validate부터 다시 시작하고 과거 전체 로그·코드·미래 단계는 읽지 않습니다.
