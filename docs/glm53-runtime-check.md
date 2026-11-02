# GLM-5.3 실행기 확인

확인일: 2026-11-03. 회사에서 표시되는 모델 alias와 실제 provider/model ID는 다를 수 있습니다. 아래 공식 기능은 사내 중계 시스템의 지원을 보장하지 않습니다.

## 공식 문서와 프로젝트 지침 분리

[GLM-5.3 공식 문서](https://docs.z.ai/guides/llm/glm-5.3)는 장기 코딩/agent 작업, function calling, text-only 입력을 설명합니다. reasoning은 enabled이며 `low/high/max` 중 코딩에는 max를 권장합니다. 이는 API/실행기 설정입니다. AGENTS.md에 “max로 사고”라고 적어 API 옵션이 바뀌었다고 보고하지 않습니다.

[Function Calling](https://docs.z.ai/guides/capabilities/function-calling)은 도구 호출 후 실제 실행 결과를 `tool_call_id`와 연결하여 반환하는 구조입니다. 도구 요청 자체를 실행 성공으로 취급하지 않습니다.

[Coding Agent Best Practice](https://docs.z.ai/devpack/resources/best-practice)는 계획·지침·Skill·반복 흐름 관리의 참고입니다. 이 Kit의 hash gate와 PPT QA 설계는 프로젝트 설계이며 모델 제공자가 보장한 품질 기능이 아닙니다.

## 회사에서 확인할 목록

- UI 모델명, 가능하면 실제 provider/model ID, 실행기 버전.
- reasoning 옵션 노출 여부와 전달 방식. 확인할 수 없으면 미확인으로 남깁니다.
- Python 실행 가능 여부, 파일 읽기/쓰기 범위, shell tool, stdout/stderr와 종료 코드 보존.
- AGENTS.md와 Skill 로딩 경로·우선순위·중복.
- MCP 연결 목록, 실제 tool 목록, 이미지 분석 도구 유무와 반환 형식.
- 연결 수립과 실제 도구 호출 성공을 분리합니다. 합성 이미지의 결함을 찾아내는지 시험합니다.
- 컨텍스트가 축약되거나 세션이 바뀌면 계획·mapping·gate_state를 다시 읽습니다. 모델 기억만으로 재개하지 않습니다.

현재 보고된 look_at / multimodal-looker 활용은 [vision-mcp-setup.md](vision-mcp-setup.md)를 따릅니다. 회사에서 허용되지 않은 외부 endpoint나 개인 API Key로 임의 연결하지 않습니다.

실행기 보고 컨텍스트는 200,000토큰입니다. 1920×1080 두 장의 부담을 이 총량만으로 설명하지 않습니다. tool별 전처리·입력 제한·누적 기록과 실제 토큰 계측을 분리합니다. 읽은 근거는 로컬 파일로 보존하고 대화에는 필요한 객체/결과만 요약합니다. AGENTS의 70%/85% 체크포인트 기준은 계측이 있을 때의 권장 운영선이며 실제 API 옵션을 바꾸지 않습니다.

## 긴 thinking과 무응답 진단

[짧은 단계 실행·중단 복구·PowerShell 인코딩](../.agents/skills/ppt-reference-fidelity/references/short-step-execution.md)을 따릅니다. 52,359자 thinking은 관측값이며 출력 토큰 한도 초과의 확정 증거는 아닙니다. finish_reason·usage·소요 시간·스트림 종료·tool_calls를 수집하고 인코딩 실패는 별도 분리합니다. PPT 콘텐츠 기획 실패와 실행 중단은 서로 독립적으로 고칩니다.
