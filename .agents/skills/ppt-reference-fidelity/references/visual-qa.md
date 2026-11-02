# 전체 및 영역별 Visual QA

## 렌더는 최종 PPTX에서

SVG 미리보기가 아니라 candidate PPTX 자체를 회사가 허용한 PowerPoint 또는 LibreOffice로 렌더합니다. 렌더러가 없으면 중단하고 `NOT REVIEWED`를 남깁니다. LibreOffice 사용 예시(실행 전 실제 설치 경로와 명령 옵션 확인):

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

스크립트는 **성공적으로 crop해도 `NOT REVIEWED`**를 씁니다. 각 region에 대해 실제 이미지를 열어 검사한 뒤 다음 10개 항목을 PASS/FAIL/NOT REVIEWED로 기록합니다:

`text_clipping`, `overflow`, `overlap`, `image_crop`, `alignment`, `spacing`, `shadow`, `border`, `hierarchy`, `reference_structure`.

각 행의 `reviewer`, 구체적인 `notes`, 행 `status`가 필요합니다. 해당 요소가 없는 경우에도 메모에 “그림자 없는 원본과 동일함”처럼 확인 근거를 적고 PASS로 기록합니다. 검토하지 않고 해당 없음으로 대체하지 않습니다. reference의 동일 영역과 나란히 비교하고 카드 제목 끝 글자·마지막 줄·프레임 모서리까지 확인합니다.

모든 행/항목이 PASS인 경우만 문서 최상위 status를 PASS로 바꿉니다. 하나라도 FAIL/NOT REVIEWED이면 전체 통과가 아닙니다. 수정 시 후보 파일 해시가 바뀌므로 edit 이후 검사와 렌더/QA를 다시 수행합니다. `gate.py`가 파일 해시·영역 목록·crop 실제 픽셀을 다시 검사합니다.

GLM-5.3의 공식 입력은 text-only입니다. 회사의 별도 이미지 도구가 실제로 이미지 bytes를 분석했거나 사람이 검토한 경우만 reviewer로 기록합니다. 이미지 파일 생성·OCR·썸네일 한 장 확인은 완전한 시각 QA가 아닙니다. 자동 clipping/overlap 판정기는 v0.1에 없으며 crop 도구는 이미지 품질을 판정하지 않습니다.
