# 짧은 단계 실행과 중단 복구

## 기본 루프

현재 목표 한 줄 → 도구 한 번 → 종료 코드/필요한 산출물 확인 → 상태 1~3문장 → 다음 단계로 진행합니다. 성공한 매 단계마다 사용자 답변을 기다리지는 않습니다. 사용자에게 필요한 결정은 분석 후 한 번에 모아 묻습니다.

한 번의 도구 호출 안에 긴 프로그램 전체를 생성·실행·수정·재실행하는 루프를 숨기지 않습니다. 도구를 직렬 호출하더라도 한 호출의 작업이 너무 크면 중단 위험은 남습니다. API 요청 하나의 출력 한도·시간 제한과 전체 세션 컨텍스트 200,000토큰은 별개입니다.

- 읽기: 한 슬라이드/한 그룹의 필요한 속성을 조회하고 전체 manifest는 로컬 JSON에 둡니다.
- 작성: 한 함수/한 슬라이드 단위로 파일을 작성하고 구문 검사를 마친 뒤 실행합니다. 문법적으로 완전한 파일만 실행합니다.
- COM: 원본 분석, 복사본 생성, 한 페이지 편집, 저장, 재열기 확인을 구분합니다. Office 호출은 직렬로 실행합니다.
- 관찰: 긴 폰트 목록·base64·전체 객체 목록을 stdout에 뿌리지 말고 UTF-8 파일에 저장합니다. 대화에는 개수·오류·관련 항목만 가져옵니다.
- 체크포인트: RUN/checkpoint.json에 phase, last_success, artifacts, candidate_path, pending_questions, next_action을 남깁니다. 변경 작업 직전/직후를 기록합니다.

응답 예: “2페이지 자료 활용안을 기록했습니다. 현장 사진 1장이 부족하며 기존 사진 재사용은 미승인입니다. 제작 전 확인 항목에 넣었습니다.” 실행하지 않았으면 실행했다고 말하지 않습니다.

## thinking 이후 본문이 없을 때

thinking 52,359자와 화면 답변 길이만으로 원인을 확정하지 않습니다. 문자 수를 토큰 수로 환산해 추정 한도를 사실처럼 보고하지 않습니다. 숨은 추론 원문을 수집하거나 공개할 필요도 없습니다.

실행기에서 얻을 수 있는 메타데이터만 회사 로컬에 남깁니다: 요청 ID, 실제 model ID, 출력 한도, reasoning 옵션, 입력/출력 토큰 사용량, finish_reason, 소요 시간, 스트림 종료 신호, 도구 호출 유무/인자 완결 여부, 예외 종류. 인증 헤더·키·업무 원문은 기록하지 않습니다.

| 관찰 | 처리 |
|---|---|
| finish_reason=length | 출력 한도 종료. 작업 단위와 실제 전달된 제한을 확인합니다. |
| model_context_window_exceeded | 입력/누적 이력/출력 예약을 확인하고 체크포인트로 재개합니다. |
| network_error, timeout, 스트림 미종료 | 실행기·프록시·연결 종료를 확인합니다. 모델 판단 완료로 취급하지 않습니다. |
| tool_calls와 본문 없음 | 도구 요청 단계일 수 있습니다. 인자가 완전하면 실제 도구 실행 및 결과 연결 여부를 확인합니다. |
| 긴 thinking 뒤 본문 없음, 종료 기록 없음 | 원인 미확정. 같은 큰 요청을 재시도하지 말고 작업을 나누고 종료 기록을 확보합니다. |
| 한글 깨짐/디코딩 예외 | 아래 인코딩 경로를 별도 확인합니다. 추론 중단 원인으로 단정하지 않습니다. |

중단 후 PPT를 처음부터 다시 편집하지 않습니다. 체크포인트·실제 파일·COM 상태를 대조해 마지막 작업이 적용됐는지 먼저 확인합니다. 미완성 도구 인자/코드를 실행하거나, 누락된 구현·검사를 완료로 승격하지 않습니다.

짧은 회신은 숨은 추론 길이의 강제 제한이 아닙니다. 지원되는 실행기에서만 별도 통제 실험으로 reasoning_effort와 출력/시간 제한을 비교합니다. AGENTS가 API 옵션을 바꾸지는 않습니다. GLM-5.3의 thinking 비활성화나 이전 reasoning 블록 임의 절단을 해결책으로 지시하지 않습니다.

## Windows PowerShell 5.1 인코딩

스크립트 파일 해석, 데이터 파일 해석, stdout/subprocess 디코딩을 따로 확인합니다. 한국어 Windows라고 모든 경계가 반드시 cp949인 것은 아닙니다.

- 한글이 포함된 .ps1은 Windows PowerShell 5.1에서 UTF-8 BOM으로 저장하거나, 스크립트는 ASCII로 두고 문자열은 명시적 UTF-8 데이터 파일에서 읽습니다. 기존 Kit의 PS1은 ASCII입니다.
- JSON/폰트 목록은 명시적 UTF-8로 읽고 씁니다. Get-Content에는 -Encoding UTF8을 쓰고 Python에서는 encoding='utf-8-sig'로 BOM 유무를 처리합니다.
- stdout 인코딩과 호출 프로그램 디코더가 일치하는지 합성 “한글 테스트”로 확인합니다. 콘솔 설정만 바꿨다고 subprocess 경계까지 해결됐다고 하지 않습니다.
- 전역 로캘 변경·실행 정책 우회는 하지 않습니다. 깨진 폰트 이름을 실제 사용 가능한 폰트로 채택하지 않습니다.

근거: [GLM-5.3](https://docs.z.ai/guides/llm/glm-5.3), [Chat Completion 종료 신호와 사용량](https://docs.z.ai/api-reference/llm/chat-completion), [Thinking mode](https://docs.z.ai/guides/capabilities/thinking-mode), [Microsoft PowerShell 문자 인코딩](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_character_encoding?view=powershell-5.1). 사내 중계 시스템이 이 필드를 실제 전달하는지는 별도 확인 대상입니다.
