# v0.1 검증 기록

실행일: 2026-11-03(사용자 시간대 Asia/Seoul). Python 3.12.14.

## 실제 실행과 결과

| 검사 | 결과 |
|---|---|
| `python3 -m unittest discover -s tests/ppt-reference-fidelity -v` | 30개 통과 |
| `python3 -S -m unittest discover -s tests/ppt-reference-fidelity -v` | 표준 라이브러리 27개 통과, Pillow 의존 3개 명시적 skip |
| `python3 -m compileall -q .../scripts tests` | 통과 |
| `git diff --cached --check` | 공백 오류 없음 |
| preflight CLI, 엔진 경로 미제공 | 의도대로 FAIL, 경로 추정 없이 inventory 출력 |
| 합성 gate 프로토콜 전체 흐름 | 순차 완료 시 PASS, 미검토/증거 변경/후보 변경 시 FAIL |
| 실제 python-pptx 생성 합성 PPTX: 중첩 그룹 텍스트·사진 포함 | validate/inspect CLI PASS |
| 합성 PPTX 문구 교체 후 무허용 구조 비교 | 해당 중첩 text path 차이 검출, FAIL |
| 합성 candidate를 soffice→PDF→pdftoppm으로 렌더 | 명령 성공, 전체 slide PNG 생성 |
| 렌더 PNG에 render_regions CLI 적용 | full/title crop 생성, QA는 NOT REVIEWED 유지 |
| Skill 절차의 독립 실행 검토 | 실제 엔진/원본 입력 부재를 확인하고 완료를 주장하지 않음 |

테스트 fixture와 임시 렌더는 회사 자료가 아닙니다. 실제 python-pptx 파일과 최소 OPC fixture 검사를 구분했습니다. 합성 gate 테스트의 엔진/렌더 로그는 프로토콜 검사 전용이며 실제 PPT Master 실행을 증명하지 않습니다.

## 아직 검증하지 않은 항목

- PPT Master 엔진은 이 환경에 실제 설치 경로가 확인되지 않아 import→수정→roundtrip export E2E를 실행하지 않았습니다. upstream 공식 코드/문서를 읽어 연결을 설계했으며 전체 엔진을 복사하지 않았습니다.
- 회사 GLM-5.3 실행기의 지침 로딩, 모델 옵션 전달, 권한, MCP 호출.
- 시각 모델을 통한 실제 PPT QA. 현재 회사에서 Z.ai 경로는 사용 불가이며 외부 제공자 도메인 통신이 제한됩니다. 별도 허용 API 경로는 미확인입니다.
- 최종 사용자 PowerPoint의 렌더/폰트 재현, 복잡한 SmartArt·차트·표 편집.
- GitHub Actions 원격 실행은 워크플로 파일 작성과 별개입니다. 원격 실행 결과를 확인하기 전 CI 통과로 보고하지 않습니다.

이 기록의 자동 테스트 통과는 Kit 검증 로직에 관한 것입니다. 실제 업무 PPT 완성이나 시각 QA 통과를 의미하지 않습니다.
