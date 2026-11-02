# 순차 실행과 증거 계약

> PACKAGE_NATIVE_LEGACY 전용 문서입니다. 현재 DRM/사용자 캡처 작업에는 실행하지 말고 [com-workflow.md](com-workflow.md)를 따르십시오.

## 경로와 초기화

예시 변수는 실행 환경에서 확인한 실제 경로로 지정합니다. 자료·로그는 Git checkout 밖의 회사 허용 로컬 폴더에 둡니다. `SOURCE`, `CANDIDATE`, `RUN`, `ROUNDTRIP`, `PPT_MASTER_DIR`, `FIDELITY_DIR`가 필요합니다. PowerShell에서는 해당 셸 문법으로 변수를 지정합니다. Python CLI는 동일합니다. Python 3.10+를 사용합니다.

```bash
SCRIPTS="$FIDELITY_DIR/scripts"
python3 "$SCRIPTS/gate.py" init --work "$RUN" --source "$SOURCE" --candidate "$CANDIDATE"
python3 "$SCRIPTS/preflight.py" --ppt-master "$PPT_MASTER_DIR" --visual-reviewer "실제로 사용 가능한 검토자" -o "$RUN/preflight.json"
python3 "$SCRIPTS/gate.py" advance --work "$RUN" --source "$SOURCE" --candidate "$CANDIDATE" --stage preflight
```

`PASS`는 단계마다 의미가 다릅니다. preflight PASS는 엔진 파일과 문서를 찾았다는 뜻이며 실행 성공이 아닙니다. 모듈 import는 별도 subprocess로 검사합니다. 실패 원인을 기록하고 엔진 실행 경로가 실제로 작동하기 전 편집 완료를 선언하지 않습니다.

## 단계별 파일

아래 표의 순서대로 파일을 생성한 뒤 같은 `gate.py advance ... --stage <이름>` 명령을 실행합니다. 실패 종료 코드는 1, 성공은 0입니다. 초기화·무효화는 검증 통과를 뜻하지 않습니다.

| 단계 | 증거 파일 | 핵심 검사 |
|---|---|---|
| preflight | preflight.json, instruction_loading.json | 엔진 위치·필수 파일, Python imports, 실행 파일·검토 수단 목록 |
| route | route.json | `route: "Edit Native PPTX"`, 비어 있지 않은 `reason` |
| authority | authority_contract.json | `design_sha256`, `facts: [{path, sha256}]`와 실제 파일 일치 |
| reference | reference_manifest.json | 원본 재검사 결과와 전체 일치 |
| mapping | content_mapping.json | 잠금, 모든 콘텐츠 슬롯의 출처, 슬롯 의미, 상세 QA 커버리지 |
| edit | edit_evidence.json | 엔진 실행 로그·종료 코드, readback, 후보 해시, 교체 결과 |
| structural | result_manifest.json, structural_diff.json | 실제 후보를 재검사, 허용 목록 외 차이 FAIL |
| integrity | package_integrity.json | 실제 후보를 표준 라이브러리로 재검사 |
| layout | candidate_powerpoint.json, layout_check.json | 실제 PowerPoint 텍스트 측정; 미지원은 NOT REVIEWED |
| render | render_evidence.json, region_plan.json | 최종 후보 해시·렌더 실행·모든 슬라이드 이미지 해시 |
| pixels | reference_powerpoint.json, pixel_diff.json | 같은 환경 렌더의 사전 mask 밖 변경 검출 |
| visual | visual_qa.json | 전체는 overview 체크, 상세는 세부 체크 모두 PASS, 검토자·메모, crop 실제 픽셀·해시 일치 |
| final delivery | final_receipt.json | 모든 단계를 현재 파일로 다시 검사 |

원본이 손상된 경우 reference 단계에서 차단합니다. 파손 원본을 자동 수리하며 원본 보존이라고 주장하지 않습니다.

## manifest / diff / package 실행

```bash
python3 "$SCRIPTS/inspect_pptx.py" "$SOURCE" -o "$RUN/reference_manifest.json"
# authority, route, mapping의 실제 JSON을 먼저 작성하고 해당 gate까지 순차 통과
# PPT Master roundtrip 편집 및 export 수행
python3 "$SCRIPTS/inspect_pptx.py" "$CANDIDATE" -o "$RUN/result_manifest.json"
python3 "$SCRIPTS/compare_manifests.py" "$RUN/reference_manifest.json" "$RUN/result_manifest.json" --mapping "$RUN/content_mapping.json" -o "$RUN/structural_diff.json"
python3 "$SCRIPTS/validate_pptx.py" "$CANDIDATE" -o "$RUN/package_integrity.json"
```

초기 import에서 생긴 `authoring_summary.json`은 계획의 입력입니다. immutable `native-payloads/`, `analysis/`를 직접 편집하지 않습니다. Kit manifest는 엔진 backing 대신 사용자가 제공한 원본 PPTX에서 직접 추출합니다.

## edit_evidence.json

```json
{
  "artifact_sha256": "<candidate hash>",
  "engine": "ppt-master",
  "mode": "roundtrip",
  "quality_gate": "PASS",
  "delivery_gate": "PASS",
  "advisory_review": "경고별 실제 검토 결과; 경고 없으면 생략 가능",
  "guard_log": {"path": "/local-run/guard.log", "sha256": "<hash>", "exit_code": 0},
  "quality_log": {"path": "/local-run/quality.json", "sha256": "<hash>", "exit_code": 0},
  "export_log": {"path": "/local-run/export.log", "sha256": "<hash>", "exit_code": 0},
  "delivery_log": {"path": "/local-run/delivery.json", "sha256": "<hash>", "exit_code": 0},
  "readback": {"path": "/local-run/readback.md", "sha256": "<hash>", "exit_code": 0}
}
```

실제로 실행된 명령의 stdout/stderr와 종료 코드만 기록합니다. `delivery_log`는 upstream 원본 JSON이며 errors가 없어야 합니다. export log에는 실제 roundtrip summary가 있어야 합니다. quality JSON은 설치본 형식을 확인하여 오류 없음/경고 처리 여부를 읽고 `quality_gate`를 기록합니다. v0.2는 모든 upstream quality schema를 자동 해석하지 않으므로 실행자의 검토가 남아 있습니다. 단순한 `quality_gate: PASS`를 검토 없이 작성하지 않습니다.

## 해시 확인

모든 sha256은 파일 bytes를 대상으로 합니다. `content_mapping` 비교 연결은 canonical JSON digest입니다. Python에서는 `hashlib.sha256(Path(path).read_bytes()).hexdigest()`를 사용합니다. 소스나 로그 내용을 외부 서비스로 보내지 않습니다.

## 재시도와 최종 배포

```bash
python3 "$SCRIPTS/gate.py" invalidate --work "$RUN" --source "$SOURCE" --candidate "$CANDIDATE" --stage mapping --reason "자료 수정에 따른 슬롯 갱신"
# mapping부터 모든 후속 단계 재실행
python3 "$SCRIPTS/gate.py" finalize --work "$RUN" --source "$SOURCE" --candidate "$CANDIDATE"
```

허용 목록·자료가 바뀌면 mapping부터, 후보 파일이 바뀌면 edit부터, 렌더가 바뀌면 render부터 무효화합니다. 원본이 바뀌면 새 RUN을 시작합니다. 변경된 증거를 이전 gate 기록에 덮어씌우지 않습니다.

finalize 실패 시 PASS였던 영수증을 FAIL로 교체합니다. 성공 영수증의 candidate 해시와 배포 파일 해시가 같아야 합니다. v0.2는 파일 복사·게시를 자동 수행하지 않습니다. 배포 이후 파일을 수정하면 새 영수증이 필요합니다.

로컬 JSON은 악의적으로 조작 가능한 파일입니다. 이 Kit은 서명된 독립 인증 시스템이 아닙니다. 자동 재계산과 해시 결속은 누락·오래된 증거·우발적인 완료 오판을 방지합니다.

## v0.2 native 검사 명령

PowerPoint desktop이 실제로 있는 Windows 사용자 세션에서 scripts/powerpoint_probe.ps1을 승인된 실행 정책으로 실행합니다. README의 명령 예시를 사용하십시오. reference/candidate 각각 새 폴더의 snapshot.json을 해당 이름으로 보관하고, 원본 snapshot의 artifact_sha256을 원본 PPTX와 대조합니다.

```text
python <SCRIPTS>/layout_check.py <RUN>/candidate_powerpoint.json --manifest <RUN>/result_manifest.json --candidate <CANDIDATE> -o <RUN>/layout_check.json
python <SCRIPTS>/pixel_diff.py <RUN>/reference_powerpoint.json <RUN>/candidate_powerpoint.json --mapping <RUN>/content_mapping.json -o <RUN>/pixel_diff.json
```

layout/pixels 단계도 gate.py advance로 기록합니다. render 단계의 region_plan.json은 candidate_powerpoint.json의 slide/image/image_sha256 목록과 같아야 합니다. render_evidence.json에는 실제 PowerShell 명령·종료 코드·로그를 기록합니다. 이미지를 다른 렌더러로 교체하지 마십시오.

`layout_check`가 NOT REVIEWED이면 strict 완료를 중단합니다. 회전/그룹/표 등 지원이 부족한 경우 candidate와 진단을 보존하고 미검증 범위를 보고합니다. 측정 불가를 비전 도구의 PASS 한 줄로 대체하지 않습니다. 네이티브 API 자체 실행은 현재 개발 환경에서 검증하지 못했으므로 대상 Windows에서 capability와 합성 PPT smoke test를 먼저 수행합니다.

v0.2는 gate가 추가되었으므로 v0.1 gate_state와 영수증을 재사용하지 않고 새 RUN을 시작합니다. visual 문서는 kit.visual.v2이며 현재 render_regions.py로 다시 생성합니다.
