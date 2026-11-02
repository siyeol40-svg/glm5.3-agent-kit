# Content Mapping Lock

> PACKAGE_NATIVE_LEGACY 전용 문서입니다. 현재 DRM/사용자 캡처 작업에는 실행하지 말고 [com-workflow.md](com-workflow.md)를 따르십시오.

`content_mapping.json`은 편집 전에 확정합니다. 그룹 객체의 key는 `shape-2/shape-3/shape-4`처럼 전체 계층입니다. top-level id 하나로 축약하지 않습니다. 슬라이드 번호는 1부터입니다.

```json
{
  "schema": "kit.mapping.v1",
  "locked": true,
  "reference_sha256": "<source hash>",
  "approval_basis": "사용자의 구체적인 슬롯 지시 또는 확인된 계획",
  "slots": [
    {
      "slide": 1,
      "target": "shape-2/shape-3/shape-4",
      "role": "text",
      "content_kind": "text",
      "source_file": "/allowed-local-run/new-content.txt",
      "source_sha256": "<content hash>",
      "source_quote": "새 자료의 실제 원문",
      "expected_text": ["교체될 run 1", "교체될 run 2"]
    },
    {
      "slide": 1,
      "target": "shape-5",
      "role": "photo",
      "content_kind": "photo",
      "source_file": "/allowed-local-run/new-content.txt",
      "source_sha256": "<content hash>",
      "source_quote": "사진 A의 설명",
      "expected_image_sha256": ["<new image bytes hash>"]
    }
  ],
  "allowed_changes": [
    {
      "path": "/slides/0/shapes/2/text/0",
      "before": "레퍼런스 문구",
      "after": "교체될 run 1",
      "reason": "새 자료의 문구로 교체"
    }
  ],
  "regions": [
    {"slide": 1, "id": "s1-full", "full_slide": true, "box": [0, 0, 1600, 900]},
    {"slide": 1, "id": "s1-title", "targets": ["shape-2/shape-3/shape-4"], "box": [80, 40, 1520, 150]}
  ]
}
```

이는 축약 예입니다. 실제로는 모든 텍스트/이미지 슬롯과 제목·각 카드·하단 도해 영역을 포함합니다. 내용이 없는 장식 객체는 provenance 슬롯이 없어도 구조 비교의 대상입니다. 유지할 문구에도 새 자료의 근거를 부여합니다. 기존 숫자나 기관명을 무심코 남길 수 없게 하기 위함입니다.

`role`과 `content_kind`는 text/photo/diagram 중 동일해야 합니다. photo→diagram 교체는 새로운 근거·사용자 요구 없이는 금지합니다. 도구가 사진과 도해를 시각적으로 분류하지는 않으므로 사람이 이 선언을 검토해야 합니다. 이미지 manifest는 관계 target과 실제 bytes 해시를 기록합니다.

허용 목록은 JSON Pointer, 정확한 before/after, 이유로 구성합니다. wildcard는 없습니다. 이미지 교체는 `images/.../sha256`, 대응 `backing_parts/...` 해시 등 실제로 변하는 필드를 미리 허용해야 합니다. XML 정규화가 추가 차이를 만들면 단순 해시 무시로 해결하지 않습니다. 원인을 분석하고 의도된 표현 변화만 구체적으로 기록합니다.

편집 중 변경이 필요하면 작업 중지 → 이유 기록 → `gate.py invalidate --stage mapping --reason ...` → Mapping Lock 갱신 → 재잠금 → 편집 및 후속 검사 재실행입니다. 예상 after를 만들기 위해 최종 후보의 모든 diff를 일괄 승인하지 않습니다.

v0.1은 동일 슬라이드 수·순서만 지원합니다. 슬롯의 `expected_text`는 manifest의 run별 배열과 정확히 일치해야 합니다. 정밀 비교가 어렵다는 이유로 그룹 전체 삭제/재생성을 허용하지 않습니다.

## v0.2 픽셀 검사 잠금

편집 전에 `pixel_policy`와 `pixel_masks`를 같은 content_mapping.json에 추가합니다. 예:

```json
{
  "pixel_policy": {"channel_tolerance": 0, "max_mask_fraction": 0.65},
  "pixel_masks": [
    {"slide": 1, "box": [80, 40, 1520, 150], "targets": ["shape-4"], "reason": "승인된 제목 문구 교체 영역"}
  ]
}
```

box는 동일 렌더 해상도의 반개구간 정수 픽셀 좌표입니다. 실제 수정하는 텍스트/사진 영역에 한정하고 모든 mask는 해당 슬라이드의 확정 slot target과 연결합니다. 전체 카드 배경·그림자까지 불필요하게 가리지 마십시오. 기본 허용 색상 오차는 0이며 0~5 범위의 사전 정책만 받습니다. mask 합집합의 기본 최대 비율은 0.65이며 어떤 정책도 0.8을 넘길 수 없습니다. 이는 품질 보증 수치가 아니라 전체 화면을 가려 검사 회피하는 실수를 막는 보수적인 제한입니다. 정상 작업이 이 범위를 넘으면 FAIL을 무시하지 말고 검증 범위를 재설계하십시오.

pixel PASS는 mask 밖에서만 예상치 않은 변화가 없다는 뜻입니다. mask 안쪽의 내용·텍스트 fit·가림·사진 의미는 다른 검사로 검토합니다. 비교 결과를 본 뒤 실패 영역을 전부 mask로 덮는 행위는 금지합니다. 계획 변경은 이유 기록과 mapping 이후 무효화를 거칩니다.
