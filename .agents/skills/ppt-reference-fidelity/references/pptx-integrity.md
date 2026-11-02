# PPTX 무결성과 Manifest 비교

> PACKAGE_NATIVE_LEGACY 전용 문서입니다. 현재 DRM/사용자 캡처 작업에는 실행하지 말고 [com-workflow.md](com-workflow.md)를 따르십시오.

## 표준 라이브러리 검사

`validate_pptx.py`는 zipfile과 ElementTree로 읽기 전용 검사합니다. 압축을 디스크에 풀거나 문서를 수정하지 않습니다. lxml/python-pptx 없이 실행됩니다.

검사 항목: ZIP/CRC, 중복 entry, 비정상 내부 경로, XML 파싱 및 DTD 차단, 필수 루트 파트, content type 커버리지, 관계 소유자 존재, 중복/불완전 relationship, 내부 target 존재 및 패키지 이탈, XML의 relationship id 해소, slideId 범위/중복/관계 유형, 활성 slide roster, orphan slides/notes, blip 이미지 관계 유형.

외부 관계는 목록화하고 가져오지 않습니다. 외부 media의 존재나 온라인 접근성은 PASS의 의미에 포함되지 않습니다. 외부 이미지에 의존하는 결과물은 오프라인 검증 전 최종 처리하지 않습니다. 이 검사는 전체 OOXML XSD 검증·Office 복구 대화상자·폰트 존재·SmartArt 의미 검사·렌더 검사가 아닙니다. upstream delivery checker와 함께 사용합니다.

## 원본과 결과의 보존 비교

`inspect_pptx.py`는 presentation slide 순서대로 읽고 중첩 그룹을 재귀 순회합니다. 각 객체는 전체 key·종류·부모·z-order·텍스트 runs·이미지 target/hash·로컬 xfrm과 `style_xml`을 기록합니다. `style_xml`에는 명시된 font, size, weight, alignment, fill, line, shadow, alpha, crop 등의 XML이 들어갑니다. 텍스트 내용만 분리하므로 글꼴/효과 변화는 감춰지지 않습니다.

테마를 통한 최종 font/effect 계산은 구현하지 않았습니다. 대신 Master/Layout/Theme 등 backing part 전체 해시를 비교하여 상속 자산의 의도하지 않은 변경을 막습니다. 전역 slide size와 slide shell도 비교합니다. 이 보수적 방식은 도구의 무해한 XML 정규화에도 FAIL할 수 있습니다. 차이를 조사한 뒤 명시적 허용을 추가해야 합니다.

`compare_manifests.py`는 구조 차이를 JSON Pointer로 기록합니다. 허용은 exact path/before/after/reason 일치여야 합니다. 새로운 도형, 삭제, 위치, 크기, 스타일, 사진 crop, media와 그룹 내부 텍스트도 비교 대상입니다. `shape_count`는 그룹을 포함한 재귀 객체 수입니다.

원본 XML의 시각적 동일성이나 텍스트 가독성은 이 비교만으로 증명되지 않습니다. 구조 PASS → 무결성 PASS → 실제 PPTX 렌더 → 영역별 QA 순서를 유지합니다.
