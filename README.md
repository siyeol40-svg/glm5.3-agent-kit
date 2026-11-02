# GLM-5.3 Agent Kit · v0.3

**이 README를 회사 에이전트에게 전달하면 로컬 지침을 백업·갱신하고, 원본 디자인 문법을 살리면서 새 내용·사진·도해를 기획하여 PPT를 재제작하는 진입점입니다.** README 열람만으로 프로그램이 실행되지는 않으며, 에이전트가 아래 지침과 필요한 저장소 파일을 읽고 실행합니다.

현재 기본 프로필은 **COM_USER_CAPTURE**입니다. DRM 문서의 ZIP/XML 직접 접근을 요구하지 않으며, 모든 시각 QA 입력은 **사용자가 제공한 캡처**입니다. 도구가 캡처를 보고도 결함을 못 찾는 상황을 반영해, 모델의 “이상 없음”을 최종 품질 통과로 쓰지 않습니다.

## 이 README를 받은 에이전트가 수행할 작업

사용자가 이 Kit 적용과 PPT 재제작을 요청했다면 계획 설명에 그치지 말고 아래 작업을 계속 수행하십시오. 백업·로컬 지침 갱신·허용된 COM 작업은 요청 범위입니다. 매 단계 권한을 다시 묻지 않습니다. 실제 입력·작업 권한이 없을 때만 필요한 항목을 묶어 질문합니다. 시각 QA 시점에 필요한 사용자 캡처를 구체적으로 요청하는 것은 입력 수집입니다.

### 1. 실제 파일과 접근 방식 확인

1. 저장소를 회사가 허용한 읽기 경로로 내려받고 commit을 기록합니다. 개인 GitHub 인증을 회사에 넣지 않습니다.
2. 원본 레퍼런스 PPTX, 새 업무 자료·사진, 직전 실패 후보와 사용자 피드백을 찾고 실제로 읽습니다. 실패 후보를 원본 대신 쓰지 않습니다. 보호 PPTX의 실제 읽기는 승인된 PowerPoint 객체 접근을 뜻하며 ZIP 파서를 먼저 시도하라는 지시가 아닙니다.
3. DRM 보호 파일이 ZIP으로 안 열린다고 손상됐다고 단정하지 않습니다. 같은 패키지 접근을 반복하지 않습니다. PowerPoint UI/COM에서 열기·객체 읽기·복사본 생성·수정·저장·재열기 권한을 각각 확인합니다.
4. 지금은 사용자 캡처만 허용된 시각 QA입니다. 자동 PNG/PDF export, 자동 screenshot, 다른 프로그램을 통한 이미지 추출을 시도하지 않습니다. DRM 해제·비보호 문서 추출로 해결하지 않습니다.
5. 별도 파일·명령·도구가 있다고 추정하지 않습니다. 회사 허용 로컬 증거 폴더를 확인합니다. 컨텍스트 보고 한도 200,000토큰과 이미지 도구 한도를 구분합니다.

### 2. 기존 AGENTS.md / Skill을 백업하고 새 버전 적용

**백업 → 중복 자동 로딩 해제 → 충돌 해결 → 새 지침 적용 → 실제 로딩 확인 → 테스트** 순서입니다.

실제 로딩되는 프로젝트/상위/사용자 범위 AGENTS.md·agent.md·Skill 위치를 확인합니다. 사내 필수 명령·규칙을 로컬 overlay 파일에 보존하고, 자유 재디자인 또는 “도형 수 무조건 고정”처럼 현재 계획과 충돌하는 규칙은 정리합니다. 새로운 시각 콘텐츠를 만드는 데 필요한 객체 변경을 무조건 금지하지 않습니다.

아래 bootstrap-plan.json을 회사 로컬에 실제 경로·원본 해시·검토 근거로 작성합니다. `<...>` 예시는 그대로 실행하지 않습니다.

```json
{
  "schema": "kit.bootstrap-plan.v1",
  "project_root": "<actual project root>",
  "backup_root": "<new backup directory outside all active scanner trees>",
  "skill_destination": "<actual active Skill directory>/ppt-reference-fidelity",
  "local_overlay_file": "<reviewed company-local rules file>",
  "agents_files": [{
    "path": "<actual loaded AGENTS.md or agent.md>",
    "expected_sha256": "<original instruction file SHA256; omit only for a new file>",
    "review_note": "보존한 사내 규칙과 해결한 충돌의 실제 근거"
  }],
  "disable_skill_dirs": [],
  "conflicts_resolved": true,
  "loading_evidence": "실제 실행기의 지침 탐지 결과와 확인한 스캔 범위"
}
```

역할이 중복되는 커스텀 PPT Skill만 disable_skill_dirs에 정확한 경로로 넣습니다. ppt-master 설치 파일은 보존하지만 **이 프로필에서는 실행 엔진으로 호출하지 않습니다.** 자동 로딩 충돌은 실행기의 지원 방식으로 작업 대상에서 제외하고 확인합니다. 파일을 검색 폴더 안에서 `.bak`로만 바꾸는 방식은 쓰지 않습니다.

```text
python <KIT>/scripts/bootstrap.py check <RUN>/bootstrap-plan.json
python <KIT>/scripts/bootstrap.py apply <RUN>/bootstrap-plan.json
python <KIT>/scripts/bootstrap.py verify <BACKUP>/receipt.json
```

모든 원본을 먼저 백업·해시 검증한 뒤 AGENTS를 공통 규칙+로컬 overlay로 교체하고 Skill 폴더 전체를 적용합니다. 기존 백업을 덮어쓰지 않습니다. 범위별 규칙은 agents_files의 선택 필드 overlay_file로 보존합니다. 문제 시 rollback을 사용하며, 적용 후 별도 수정이 있으면 덮어쓰지 않고 조정합니다. [마이그레이션 상세](docs/migration-guide.md)

실제 활성 지침을 확인하고 instruction_loading.json에 status=PASS, active_files[{path,sha256}], evidence{path,sha256}, bootstrap_receipt{path,sha256}를 기록합니다. 파일 복사만 성공했거나 세션에 구 지침이 남아 있으면 로딩 PASS가 아닙니다. 실제 실행기가 지원하는 재개 방법을 확인하고 checkpoint로 이어갑니다.

### 3. “문장만 옮긴 복사본”을 막는 콘텐츠 기획

설치된 SKILL.md → references/com-workflow.md → com-precautions.md → content-adaptation.md 순으로 현재 단계의 문서만 읽습니다. ZIP/자동 렌더 기반 legacy 문서는 이 프로필에 로딩하지 않습니다.

각 페이지의 핵심 메시지·독자 이해 목표·사실 출처·시각 표현을 먼저 기획합니다. 구체적인 시각 표현 2안을 짧게 비교한 뒤 자료와 원본 문법에 맞는 안을 스스로 선택하고 이유를 남깁니다. 형식적인 색상 변형이나 사용자 선택 대기를 기본값으로 하지 않습니다. COM의 재귀 객체 목록을 기준으로 원본의 **모든 사진·그림·차트**에 교체/재구성/추가/장식 유지/사용자 승인 유지/삭제 결정을 적습니다.

- 디자인 앵커: 컬러, 폰트 위계, 제목 위치, 프레임, 여백, 선·그림자·정렬 문법.
- 새로 구성할 콘텐츠: 메시지, 설명 순서, 새 사진의 대상, 관계/과정/대비 도해, 데이터 표현.
- 기존 사업 사진·기술 그림을 “스타일 유지”라는 이유로 그대로 쓰지 않습니다. 내용이 있는 사진/그림을 장식으로 재분류해 남기지 않습니다.
- 새 사진이 없으면 기존 사진으로 메우지 않습니다. 실제 사진이 필수면 자료를 요청하고 미완성으로 남깁니다. 개념 설명이면 새 자료의 관계를 native 도형으로 시각화할 수 있습니다.
- 사진 슬롯과 하단 기술 도해 역할을 지킵니다. 필요한 역할 변경/새 객체는 기획에 명시하고 원본 디자인 문법 안에서 구성합니다.
- “새롭게/창의적으로” 같은 추상적 지시로 끝내지 않고 각 시각 자료의 새 컨셉·구현 방법·확인 기준을 적습니다. 생성 이미지·가상 수치를 실제 현장이나 실적으로 제시하지 않습니다.

content_blueprint.json을 작성하고 검사·잠금합니다. [전체 계약](.agents/skills/ppt-reference-fidelity/references/com-workflow.md) · [축약 예제](.agents/skills/ppt-reference-fidelity/examples/content_blueprint.example.json)

```text
python <SKILL>/scripts/com_workflow.py blueprint --work <RUN>
python <SKILL>/scripts/com_workflow.py lock --work <RUN>
```

기획 완전성 검사는 창의성 점수가 아닙니다. 실제 시각 표현이 새로운 내용에 맞는지는 이후 사용자 캡처에서 확인해야 합니다.

### 4. COM으로 기존 디자인을 살려 편집

com_native_manifest.ps1로 원본의 COM-readable 객체·그룹·텍스트·서식을 읽습니다. 원본 bytes를 ZIP으로 읽거나 hash하지 않습니다. 결과 revision은 path/size/mtime metadata로 연결하며 내용 해시보다 약하다는 한계를 남깁니다.

```text
powershell -NoProfile -File <SKILL>/scripts/com_native_manifest.ps1 -Pptx <REFERENCE> -Output <RUN>/reference_native.json
```

이미 열린 문서 연결이 필요한 환경에서만 -UseOpenPresentation을 확인하여 사용합니다. PowerShell 실행 정책을 우회하지 않습니다. 이 도구는 읽기 전용 manifest 수집기이며 **범용 COM 편집 엔진은 아닙니다.** 에이전트가 실제 지원 API·객체·계획에 맞는 로컬 편집 코드를 작성하고 실행 흔적을 남겨야 합니다.

승인된 PowerPoint 동작으로 별도 복사본을 만들고 그 복사본만 수정합니다. 그룹을 해체하거나 모든 도형을 처음부터 재생성하지 않습니다. 혼합 텍스트 서식·문단·사진 종횡비/crop·레이어·효과·연결을 확인합니다. 사진 교체가 필요하면 실제로 새 자산을 넣고 옛 picture가 뒤에 남지 않는지 확인합니다.

저장 → 닫기 → 재열기 뒤 result_native.json을 수집합니다. visual_implementation.json에 계획한 시각 자료별 실제 구현 대상·새 asset·실행 로그를 연결합니다. 새 asset 파일과 로그가 있다고 삽입 의미까지 자동 증명된 것은 아닙니다.

현재 프로필에서는 inspect_pptx.py / validate_pptx.py / legacy gate.py / PPT Master ZIP roundtrip / 자동 render/pixel diff를 실행하지 않습니다. 미수행 검사는 NOT_CHECKED_DRM_PROFILE 등으로 보고합니다.

### 5. 사용자 캡처 → 구체적인 검토 → 수정 → 사용자 수용

완성된 후보의 revision·슬라이드·필요한 상세 영역을 명시해 캡처를 요청합니다. 캡처가 없으면 시각 QA는 AWAITING_USER_CAPTURE입니다. 원본 대비 판단에는 사용자가 제공한 대응 레퍼런스 캡처도 사용합니다. 전체 축소본에서 작은 글자를 판정하지 않습니다.

look_at / call_omo_agent(subagent_type="multimodal-looker")가 실제 입력을 처리했는지 입력 해시·호출 ID·raw 보고를 남깁니다. 도구가 명백한 결함을 놓치면 신뢰할 수 있는 최종 판정기로 쓰지 않습니다. JSON, checklist, 서브에이전트라는 이름만으로 정확성이 보장되지 않습니다.

관찰은 객체/영역 → 보이는 사실 → 기대 기준 → 차이 → 수정 제안으로 작성합니다. 도구의 “이상 없음”과 사용자 수용은 다릅니다. 캡처 업로드·사용자 침묵을 승인으로 취급하지 않습니다.

사용자 지적은 known_issues.json에 OPEN으로 기록합니다. 기존 사진 잔존, 문장만 치환, 캡처 결함 인지 실패 같은 피드백을 “의도된 디자인/취향”으로 반박해 닫지 않습니다. 구체적인 수정과 실제 사용자 확인으로만 해결 처리합니다. 도구 오탐은 사용자가 근거를 들어 수정할 수 있지만, 객관적인 내용/허용 범위 FAIL을 덮을 수는 없습니다.

```text
python <SKILL>/scripts/com_workflow.py audit --work <RUN>
```

결과 com_receipt.json은 캡처 대기/사용자 수용 대기/수정 필요/FAIL을 구분합니다. 실제 사용자가 현재 후보와 캡처 세트를 수용한 경우만 USER_ACCEPTED_WITH_LIMITATIONS입니다. ZIP 내부/media bytes/알 수 없는 COM 속성까지 검증 통과했다고 주장하지 않습니다. [캡처 QA 계약](.agents/skills/ppt-reference-fidelity/references/user-capture-qa.md)

## 테스트와 한계

`python -m unittest discover -s tests/ppt-reference-fidelity -v`로 합성 회귀를 실행합니다. `python -S -m unittest ...`는 외부 패키지를 제외한 경로를 검증합니다. 새 COM_USER_CAPTURE의 Python 증거 검사기는 표준 라이브러리만 사용합니다. [검증 기록](docs/validation-report.md)

Windows PowerPoint/DRM/회사 look_at·looker는 이 개발 환경에서 실제 실행하지 못했습니다. 코드를 배포했다는 사실은 회사 COM 동작·이미지 이해·최종 디자인 품질의 보증이 아닙니다. 이전 v0.1/v0.2 RUN과 새 프로필을 혼용하지 않습니다.

일반 비보호 문서에서 패키지 처리가 실제 허용된 경우에만 PACKAGE_NATIVE_LEGACY 경로를 별도로 선택할 수 있습니다. 이 경로의 파일은 삭제하지 않았지만 현재 회사 작업의 기본값이 아닙니다. [프로필 구분](docs/company-readonly-setup.md)

공개 GitHub에는 일반화한 코드·규칙·합성 테스트만 저장합니다. 회사 문서·사진·캡처·주소·인증정보·원문 검토 로그는 회사 허용 로컬 폴더에만 둡니다. 실행기는 200,000토큰 예산에서 필요한 문서만 읽고 대용량 자료는 파일로 처리합니다.
