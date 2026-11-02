# GLM-5.3 Agent Kit · v0.2

**회사 에이전트에게 이 README를 전달하면, 아래 절차에 따라 로컬 AGENTS.md와 Skill을 백업·갱신하고 기존 PPT를 다시 제작하도록 하는 진입점입니다.** 사용자가 여러 파일을 따로 붙여 넣을 필요는 없습니다. 실행 에이전트는 저장소의 필요한 파일을 직접 읽고 실행해야 합니다. README를 열기만 해도 프로그램이 실행되거나 권한이 생기는 것은 아닙니다.

## 이 README를 받은 실행 에이전트에게

사용자가 이 Kit 적용과 PPT 재제작을 요청했다면 아래 작업은 요청 범위 안에서 계속 수행하십시오. 계획만 설명하고 멈추거나 매 단계 다시 허락을 묻지 마십시오. 입력 파일·쓰기 권한 등 필수 정보가 실제로 없을 때만 부족한 항목을 묶어서 질문하십시오. 지침 변경은 아래 백업 절차를 거친 **회사 로컬 파일**에만 적용합니다. 개인 GitHub 인증이나 회사 자료의 외부 업로드를 요구하지 않습니다.

### 1. 현재 작업과 실행 환경을 실제로 확인하십시오

1. 이 저장소를 승인된 read-only 경로로 내려받고 commit을 기록하십시오. Kit checkout은 변경하지 않고 별도 프로젝트에 적용합니다.
2. 기존 대화와 현재 프로젝트에서 원본 레퍼런스 PPTX, 새 내용·사진, 직전 실패 결과를 찾으십시오. 파일을 먼저 읽고 원본/결과를 구분하십시오. 실패 결과를 원본 대신 사용하지 마십시오.
3. 프로젝트·상위·사용자 범위에서 **실제 자동 로딩되는** AGENTS.md/agent.md/SKILL.md 경로와 기존 규칙을 확인하십시오. 실제 실행기의 탐지 결과와 대조하십시오. `.agents/skills/`를 지원한다고 추정하지 마십시오.
4. 설치된 PPT Master의 실제 절대 경로와 버전을 확인하십시오. PPT Master는 실행 엔진으로 유지하고 전체 fork/복사하지 않습니다.
5. Windows용 PowerPoint 데스크톱, 승인된 PowerShell/COM 실행, Python 3.10+, Pillow 여부를 확인하십시오. 실행 정책을 우회하거나 외부 서비스·패키지를 임의 설치하지 마십시오.
6. 대상 실행기의 보고 한도는 **200,000토큰**입니다. 이는 적은 한도가 아니며, 이미지 도구의 별도 제한과 혼동하지 마십시오. 계측·단계적 로딩·파일 기반 증거 관리를 적용하십시오.

### 2. 기존 지침을 백업하고 자동으로 교체하십시오

**백업 → 중복 Skill 자동 로딩 해제 → 충돌 해결 → 새 AGENTS/Skill 적용 → 실제 로딩 확인 → 테스트** 순서입니다. 구 파일 삭제는 마지막 선택이며 필수가 아닙니다.

- 기존 지침을 읽고 사내 필수 규칙·명령을 회사 로컬 overlay 파일에 보존하십시오. 충돌하는 자유 재디자인·렌더=QA 지침은 그대로 이어 붙이지 말고 새 흐름과 맞게 정리하십시오.
- 중복 PPT Skill만 비활성화 대상으로 선정하십시오. **ppt-master는 유지**하십시오.
- 실제 스캔 범위 밖의 새 백업 폴더를 선택하십시오. 검색되는 폴더 안에 `.bak`로 이름만 바꾸는 방식은 쓰지 마십시오.
- 아래 형식의 `bootstrap-plan.json`을 회사 로컬에 작성하십시오. 예시 문자열은 실제 관측한 절대 경로·해시로 채우십시오. 값이나 파일을 이 공개 저장소에 저장하지 마십시오.

```json
{
  "schema": "kit.bootstrap-plan.v1",
  "project_root": "<observed absolute project path>",
  "backup_root": "<new absolute path outside all scanner roots>",
  "skill_destination": "<actual active skill path>/ppt-reference-fidelity",
  "local_overlay_file": "<reviewed company-local rules file>",
  "agents_files": [
    {
      "path": "<actual loaded AGENTS.md or agent.md path>",
      "expected_sha256": "<original file SHA256; omit only for a new file>",
      "review_note": "사내 필수 규칙을 overlay에 보존하고 충돌을 해결한 구체적 근거"
    }
  ],
  "disable_skill_dirs": ["<exact reviewed duplicate Skill directory; empty array if none>"],
  "conflicts_resolved": true,
  "loading_evidence": "실제 실행기의 지침 탐지 결과와 확인한 스캔 범위"
}
```

`review_note`는 실제 검토 내용을 한국어로 작성하십시오. overlay에 보존할 사내 규칙이 없다면 빈 파일을 명시적으로 만드십시오. 여러 AGENTS 파일은 각 범위의 필수 규칙이 상충하지 않는지 확인하십시오. 범위별 규칙은 해당 agents_files 항목의 선택 필드 overlay_file(실제 절대 경로)로 분리해 기존 적용 범위를 유지할 수 있습니다.

```text
python <KIT>/scripts/bootstrap.py check <RUN>/bootstrap-plan.json
python <KIT>/scripts/bootstrap.py apply <RUN>/bootstrap-plan.json
python <KIT>/scripts/bootstrap.py verify <BACKUP>/receipt.json
```

스크립트는 모든 원본을 먼저 해시 검증하며 백업하고, AGENTS를 Kit 공통 규칙+검토된 로컬 overlay로 교체하며, 중복 Skill은 백업 후 로딩 위치에서 제거하고 새 Skill 폴더 전체를 설치합니다. 기존 백업을 덮어쓰지 않습니다. 이미 적용된 경우에는 receipt 검증부터 하십시오. 재실행이 필요하면 변경된 현재 파일을 다시 읽고 새 계획·백업을 만드십시오.

그다음 실제 에이전트의 로딩 기록/탐지 결과로 새 파일이 활성화됐는지 확인하고 `instruction_loading.json`에 아래 계약대로 경로·해시·확인 근거를 기록하십시오. preflight gate가 이 파일과 설치 상태를 재검사합니다.

```json
{
  "schema": "kit.loading.v1",
  "status": "PASS",
  "active_files": [{"path": "<actual active instruction file>", "sha256": "<hash>"}],
  "evidence": {"path": "<actual runtime loading log or observation record>", "sha256": "<hash>"},
  "bootstrap_receipt": {"path": "<BACKUP>/receipt.json", "sha256": "<hash>"}
}
```

active_files에는 실제 로딩된 AGENTS 및 Skill 파일을 모두 적습니다. 근거가 단지 추정이거나 파일 복사만 확인된 경우 status를 PASS로 적지 마십시오. 파일 복사 성공만으로 실제 로딩 성공이라고 보고하지 마십시오. 구 지침이 현재 세션에 캐시되어 있다면 기존 지침의 실제 효력이 해제되는 재개 방법을 확인하고 checkpoint에서 이어가십시오.

문제 시 `python <KIT>/scripts/bootstrap.py rollback <BACKUP>/receipt.json`으로 복원합니다. 적용 후 수동 변경이 있으면 덮어쓰지 않고 멈추므로 해당 변경을 먼저 조정하십시오. [상세 마이그레이션](docs/migration-guide.md)

### 3. 설치된 Skill을 읽고 원본 구조로 PPT를 다시 제작하십시오

1. 설치한 `ppt-reference-fidelity/SKILL.md`를 읽고 필요한 참조 문서를 단계적으로 읽으십시오.
2. PPT Master의 `SKILL.md → attribution guard → routing.md → edit-native-pptx.md` 순서를 따르십시오. guard 실패는 우회하지 마십시오.
3. `Edit Native PPTX`를 선택하십시오. Generate 파이프라인이나 슬라이드 XML만 deepcopy하는 방식으로 바꾸지 마십시오.
4. 디자인의 권위는 원본 PPTX, 사실·수치의 권위는 새 자료로 분리하십시오. 그룹 내부까지 원본 manifest를 추출하십시오.
5. 원래 제목·카드·사진·하단 도해에 들어갈 콘텐츠, 허용 변경, 검사 영역과 픽셀 mask를 **편집 전** 고정하십시오. 이전 실패 매핑을 무심코 재사용하지 마십시오.
6. 이미 존재하는 도형·좌표·레이어·효과를 유지하고 필요한 텍스트·이미지만 교체하십시오. 넘치면 문장 압축/줄바꿈부터 해결하십시오.
7. candidate를 별도 생성하고 아래 검사를 실행하십시오. 전체 명령·증거 형식은 [workflow.md](.agents/skills/ppt-reference-fidelity/references/workflow.md)를 읽으십시오.

### 4. 이미지 도구보다 구조·실측·픽셀 검사를 먼저 수행하십시오

| 순서 | 검사 | 실행 도구 |
|---|---|---|
| 1 | 재귀 객체·문구·좌표·스타일 비교 | inspect_pptx.py, compare_manifests.py |
| 2 | ZIP/XML/관계/media 무결성 | validate_pptx.py |
| 3 | 실제 PowerPoint 측정과 동일 환경 렌더 | powerpoint_probe.ps1 |
| 4 | 텍스트 경계·여백·폰트/자동축소 확인 | layout_check.py |
| 5 | 사전 허용한 수정 영역 밖의 픽셀 비교 | pixel_diff.py |
| 6 | 내용 의미·가림·사진 적절성 등 잔여 검토 | look_at 또는 multimodal-looker/사람 |
| 7 | 현재 candidate에 모든 gate 재검사 | gate.py finalize |

PowerPoint 실행 예시: 실행 정책을 우회하는 옵션은 사용하지 않습니다. 실제 실행 가능한 PowerShell 명령과 절대 경로로 바꾸십시오.

```text
powershell -NoProfile -File <SKILL>/scripts/powerpoint_probe.ps1 -OutputDir <RUN>/capability
powershell -NoProfile -File <SKILL>/scripts/powerpoint_probe.ps1 -Pptx <REFERENCE> -OutputDir <RUN>/reference-render
powershell -NoProfile -File <SKILL>/scripts/powerpoint_probe.ps1 -Pptx <CANDIDATE> -OutputDir <RUN>/candidate-render
```

출력 `snapshot.json`을 각각 reference_powerpoint.json/candidate_powerpoint.json으로 보관하십시오. 원본과 결과는 같은 사용자·PowerPoint 버전·폰트·출력 크기로 측정하십시오. 기본 출력은 1600×900이며 서로 다른 슬라이드 종횡비에서는 왜곡되지 않도록 Width/Height를 같은 비율로 지정하십시오. 스크립트는 원본을 읽기 전용으로 열고 저장하지 않습니다.

**현재 실측 지원 경계:** 회전 없는 단독 가로 텍스트 중심입니다. 그룹 내부 변환·회전·표·테마 폰트 해소·자동 글자축소 등의 판정이 불확실하면 NOT REVIEWED로 남겨 strict final을 막습니다. 지원이 안 된다고 원본 그룹을 해제하거나 글꼴·크기를 바꿔 검사만 통과시키지 마십시오. PowerPoint가 없거나 COM이 차단된 경우에도 candidate 제작과 가능한 검사는 계속하되, `제작됨 / 미검증`으로 보고하십시오. LibreOffice 결과를 PowerPoint 실측으로 가장하지 마십시오.

렌더·픽셀 검사는 고해상도 전체 이미지를 **로컬 프로그램이** 처리하므로 GLM에게 두 장을 통째로 전달할 필요가 없습니다. pixel mask는 사전 잠금된 text/image 변경 영역만 허용하며, mask 안쪽의 결함까지 통과했다는 뜻은 아닙니다.

### 5. 비전 도구는 남은 질문에만 사용하십시오

보고된 기능: `look_at`, 또는 `call_omo_agent(subagent_type="multimodal-looker")`가 로컬 파일 경로/base64(image_data)를 받아 텍스트로 보고합니다. 별도의 사내 Vision MCP 서버는 없습니다. 회사 실행기에서 실제 노출된 도구 스키마를 확인하십시오. 이 Kit은 해당 도구를 외부에서 직접 실행하는 client가 아닙니다.

- 구조/실측/pixel 검사를 이미지 도구의 PASS 한 줄로 대체하지 마십시오.
- 전체 축소본은 배치·위계만, 상세 영역은 글자·crop·테두리·그림자 등 역할을 나누십시오.
- 전체 1920×1080 이미지 두 장을 기본 입력으로 고정하지 마십시오. 20만 토큰 전체 한도와 개별 도구 제한은 다릅니다. 실제 토큰 계측·오류를 기록하고 필요한 결함 영역만 조회하십시오.
- raw 보고서와 입력 이미지 해시는 로컬 증거 파일로 남기고, 대화에는 짧은 발견 요약만 가져오십시오. base64를 대화에 펼치지 마십시오.
- 불명확·판독 불가·컨텍스트 오류는 NOT REVIEWED입니다. 반복·병렬 호출을 늘려 정확도가 보장된다고 주장하지 마십시오.

[비전 보조 검토](.agents/skills/ppt-reference-fidelity/references/visual-qa.md) · [현재 도구 연결 계약](docs/vision-mcp-setup.md)

### 6. 보고하고 작업을 끝내십시오

기존 파일 백업 위치, 실제 활성 지침, 새 PPT 경로, 실행한 검사와 실패/미검토를 보고하십시오. `final_receipt.json`이 현재 후보 해시로 모든 gate PASS일 때만 **검증 통과 최종본**으로 전달합니다. 통과하지 못했어도 candidate와 차단 근거는 남겨 사용자가 검토할 수 있게 하십시오. 작업 증거와 회사 PPT를 이 저장소에 push하지 마십시오.

## 구현·테스트·경계

- 공통 지침: [AGENTS.md](AGENTS.md), 200줄 이하. 실행기 한도 20만 토큰의 예산·checkpoint 규칙 포함.
- 로컬 적용/복구: scripts/bootstrap.py. 사내 overlay는 공개 저장소 밖에만 보관.
- 상위 Skill: .agents/skills/ppt-reference-fidelity/. PPT Master는 별도 엔진으로 유지.
- 검사: preflight, manifest, 구조 diff, integrity, PowerPoint 측정, layout, pixel diff, 영역 crop, 보조 비전 보고 기록, 순차 gate.
- 테스트: `python -m unittest discover -s tests/ppt-reference-fidelity -v`. 표준 라이브러리만 검증하려면 `python -S -m unittest ...`를 사용합니다. 이미지 검사는 Pillow가 필요합니다.
- [이번 검증 결과](docs/validation-report.md)와 [수용 사례](tests/ppt-reference-fidelity/acceptance-cases.md)를 읽으십시오. Windows PowerPoint COM은 이 개발 환경에서 실행 검증하지 못했으며 회사 PC에서 capability/합성 smoke test가 필요합니다.
- v0.1 receipt와 v0.2 gate를 혼용하지 마십시오. 새 RUN으로 시작하십시오. 회사 read-only 적용은 [company-readonly-setup.md](docs/company-readonly-setup.md)를 참고하십시오.

공개 저장소에는 일반화된 코드·규칙·합성 테스트만 둡니다. 회사 문서·고객정보·인증정보·실제 시스템 주소는 저장하지 않습니다. 이 Kit은 악의적 증거 조작을 막는 서명 시스템이나 완전한 시각 품질 보증이 아닙니다.
