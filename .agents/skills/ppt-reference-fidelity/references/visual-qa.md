# 전체 및 영역별 Visual QA

> PACKAGE_NATIVE_LEGACY 전용 문서입니다. 현재 DRM/사용자 캡처 작업에는 실행하지 말고 [com-workflow.md](com-workflow.md)를 따르십시오.

v0.2에서는 객체·패키지·native layout·pixel 검사를 먼저 실행합니다. 이미지 분석은 그 결과로 해결되지 않은 의미·가림·시각적 결함을 보조 확인합니다. 전체 고해상도 이미지 두 장을 비전 도구에 기본으로 넣지 않습니다.

## 렌더는 최종 PPTX에서

strict gate는 candidate PPTX 자체를 실제 PowerPoint로 측정·렌더한 snapshot을 사용합니다. LibreOffice는 candidate 미리보기의 대체 경로이며 native gate 통과를 대체하지 않습니다. 렌더러가 없으면 중단하고 `NOT REVIEWED`를 남깁니다. LibreOffice 사용 예시(실행 전 실제 설치 경로와 명령 옵션 확인):

```bash
soffice --headless --convert-to pdf --outdir "$RUN/render" "$CANDIDATE"
pdftoppm -png -r 150 "$RUN/render/<candidate-stem>.pdf" "$RUN/render/slide"
```

명령 성공 여부와 PDF/이미지 개수를 확인합니다. 다른 작업의 기존 이미지가 남아 있지 않은 새 폴더를 사용합니다. 폰트 대체, 렌더러 차이를 기록합니다. 최종 대상 PowerPoint에서의 모습까지 검증한 것으로 확대 해석하지 않습니다.

`render_evidence.json`: `artifact_sha256`, 실제 `renderer`, 실행한 `command`(문자열 또는 배열), `exit_code: 0`, `log: {path, sha256}`를 기록합니다. 후보 해시는 렌더 입력의 실제 파일에서 계산합니다.

`region_plan.json` 예:

```json
{
  "artifact_sha256": "<candidate hash>",
  "slides": [{
    "slide": 1,
    "image": "/local-run/render/slide-1.png",
    "image_sha256": "<full render hash>",
    "regions": [
      {"id": "s1-full", "full_slide": true, "box": [0, 0, 1600, 900]},
      {"id": "s1-title", "targets": ["shape-4"], "box": [80, 40, 1520, 150]}
    ]
  }]
}
```

각 slide의 regions는 편집 전 mapping에 잠근 `regions`의 해당 슬라이드 항목과 정확히 같아야 합니다(`slide` 필드만 바깥으로 이동). 모든 텍스트/이미지 슬롯은 **full 외 상세 region의 targets**로도 커버해야 합니다. 실제 작업에는 카드 각각과 하단 도해를 별도 상세 영역으로 추가합니다. 픽셀 box는 `[left, top, right, bottom]`이며 원본 렌더 해상도에 대응합니다. full만 존재하는 계획은 gate에서 FAIL합니다. 빈 여백만 crop해 놓고 콘텐츠를 검토했다고 선언하지 않습니다. targets/box의 시각적 적합성은 검토자가 원본 렌더와 확인해야 합니다.

```bash
python3 "$SCRIPTS/render_regions.py" "$RUN/region_plan.json" --output-dir "$RUN/qa" -o "$RUN/visual_qa.json"
```

Pillow는 이 crop와 pixel 비교 단계에만 필요합니다. 설치하지 못하면 다른 도구로 crop을 만들 수 있으나 현재 gate의 crop 재검증에는 Pillow가 필요합니다. 미설치 상태에서 완료로 우회하지 않습니다.

## 검토 기록

스크립트는 **성공적으로 crop해도 `NOT REVIEWED`**를 씁니다. 문서 schema는 kit.visual.v2입니다. full_slide=true인 전체 축소본은 alignment/hierarchy/reference_structure 3개만 검사합니다. 세부 글자 품질을 축소본에서 판정하지 않습니다. 각 상세 region은 실제 이미지를 열어 다음 10개 항목을 PASS/FAIL/NOT REVIEWED로 기록합니다:

`text_clipping`, `overflow`, `overlap`, `image_crop`, `alignment`, `spacing`, `shadow`, `border`, `hierarchy`, `reference_structure`.

각 행의 `reviewer`, 구체적인 `notes`, 행 `status`가 필요합니다. 해당 요소가 없는 경우에도 메모에 “그림자 없는 원본과 동일함”처럼 확인 근거를 적고 PASS로 기록합니다. 검토하지 않고 해당 없음으로 대체하지 않습니다. reference의 동일 영역과 나란히 비교하고 카드 제목 끝 글자·마지막 줄·프레임 모서리까지 확인합니다.

모든 행/항목이 PASS인 경우만 문서 최상위 status를 PASS로 바꿉니다. 하나라도 FAIL/NOT REVIEWED이면 전체 통과가 아닙니다. 수정 시 후보 파일 해시가 바뀌므로 edit 이후 검사와 렌더/QA를 다시 수행합니다. `gate.py`가 파일 해시·영역 목록·crop 실제 픽셀을 다시 검사합니다.

GLM-5.3의 공식 입력은 text-only입니다. look_at 또는 call_omo_agent의 multimodal-looker가 실제로 이미지를 분석했거나 사람이 검토한 경우만 reviewer로 기록합니다. 이미지 파일 생성·OCR·썸네일 한 장 확인은 완전한 시각 QA가 아닙니다. 자동 clipping/overlap 판정기는 v0.1에 없으며 crop 도구는 이미지 품질을 판정하지 않습니다.

## 선택적인 보조 도구 입력 준비/기록

visual_review.py는 이미지 분석 도구를 직접 호출하지 않습니다. 필요한 영역별 1장짜리 A/B 비교 이미지를 준비하고 **실제 도구 호출 후 받은 JSON 텍스트 보고서**를 기록하는 보조 CLI입니다. 필수 구조·layout·pixel 검사를 대체하지 않습니다. 기본 최대 변은 상세 1024, 전체 768 픽셀이며 이는 컨텍스트 안전 보장이 아닌 시작 설정입니다. 작아서 읽기 어렵다면 NOT REVIEWED로 남기고 더 작은 결함 영역을 추가 조회합니다.

reference-renders 인자는 reference_powerpoint.json을 사용할 수 있습니다. 입력 이미지 경로/해시와 원본 PPTX 해시가 연결되어야 합니다.

```text
python <SCRIPTS>/visual_review.py prepare --plan <RUN>/region_plan.json --reference-renders <RUN>/reference_powerpoint.json --qa <RUN>/visual_qa.json --mapping <RUN>/content_mapping.json --output-dir <RUN>/review-inputs -o <RUN>/review-queue.json
```

queue의 해당 request 파일을 읽고 실제 실행기의 tool schema에 맞춰 look_at 또는 multimodal-looker를 호출합니다. 주어진 instruction/checks/expected_text를 전달하고 응답을 회사 로컬에 저장합니다. 도구는 로컬 파일 경로 또는 지원되는 image_data만 받도록 하며, 대화에 base64를 출력하지 않습니다. 모든 상세 영역을 다시 모델로 확인해야 한다고 가정하지 말고 잔여 질문에 필요한 조회만 수행합니다. 실제 사람의 영역 검토도 허용됩니다.

```text
python <SCRIPTS>/visual_review.py record --qa <RUN>/visual_qa.json --mapping <RUN>/content_mapping.json --request <RUN>/review-inputs/<region>-request.json --report <RUN>/<actual-tool-report>.json --tool look_at --call-id <actual-invocation-id> -o <RUN>/visual_qa.json
```

서브에이전트 도구명은 `call_omo_agent:multimodal-looker`로 기록합니다. 보고서의 region_id/checks/unreadable/notes를 검증하며 unreadable=true이면 PASS 응답도 NOT REVIEWED로 남깁니다. 자연어만 반환되거나 JSON 파싱이 실패하면 자동 기록하지 않습니다. raw 응답을 보존하고 수동 검토/형식 재요청을 선택합니다. 단순한 “이상 없음”을 10개 항목 PASS로 복제하지 않습니다.

gate는 tool reviewer의 요청/보고 파일 해시, 후보/매핑 해시, 입력 이미지와 생성 비교 이미지의 실제 픽셀, 기록 상태의 일치를 재검사합니다. 이 로컬 기록은 서명된 도구 실행 인증이 아니므로 허위 호출 ID/보고서를 만들어 넣지 않습니다. 회사 도구 호출 E2E는 아직 검증하지 않았습니다.
