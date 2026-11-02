# 실제 PowerPoint 측정과 렌더 비교

> PACKAGE_NATIVE_LEGACY 전용 문서입니다. 현재 DRM/사용자 캡처 작업에는 실행하지 말고 [com-workflow.md](com-workflow.md)를 따르십시오.

## 왜 추가하는가

PPTX 객체 속성 비교는 구조를 확인하지만 글자가 실제로 그려질 때 맞는지까지 보장하지 않습니다. 비전 모델의 텍스트 보고도 기하학적 증명이 아닙니다. v0.2는 Windows desktop PowerPoint에서 읽기 전용 측정/렌더를 한 뒤 Python으로 비교합니다. PPT Master 편집 엔진을 대체하거나 fork하지 않습니다.

## native snapshot

powerpoint_probe.ps1은 승인된 Windows 사용자 세션에서 COM 인스턴스를 생성합니다. Pptx 없이 실행하면 startup capability만 AVAILABLE로 기록하며 PPT 검증 PASS를 만들지 않습니다. Pptx를 지정하면 ReadOnly로 열어 저장 없이 닫습니다. 새 출력 폴더만 사용합니다. 실행 정책 우회, 외부 API 호출, 자동 Office 설치는 하지 않습니다.

snapshot은 kit.powerpoint-snapshot.v1: artifact_sha256, renderer, environment(OS/Office build/font inventory hash/export size), errors, slides(이미지 경로/해시), text_shapes를 기록합니다. shape key는 원본 manifest와 같은 재귀 shape-id 경로입니다.

text_shapes에는 slide/key/text/supported/reason/inner_box/text_bounds/auto_size/declared_fonts/font_available를 기록합니다. box는 [left, top, width, height] 포인트입니다. 그룹은 재귀 순회하여 누락하지 않지만 그룹 변환의 정확성을 검증하지 않은 상태에서는 supported=false입니다.

## 자동 판정 범위

layout_check.py는 후보 PPTX/manifest/snapshot 해시, 재귀 텍스트 shape 커버리지, 내용, 유한한 치수와 양수 크기, 경계 포함 관계를 검사합니다. 고정 허용 오차는 0.5pt입니다. 회전·그룹·표·세로 텍스트는 별도 지원 전 NOT REVIEWED, 자동 text shrinking이나 설치 폰트 확인 실패도 NOT REVIEWED입니다. 텍스트 경계가 내부 프레임을 넘으면 FAIL입니다.

설치 font family 이름 비교는 보수적이며 별칭/테마/언어별 family 이름 때문에 확인 불가가 나올 수 있습니다. 임의 PASS로 바꾸지 않습니다. TextRange2 bounds는 다른 객체의 가림, 복잡한 효과의 잘림, 의미 적합성을 증명하지 않습니다. 해당 부분은 잔여 시각 검토 대상입니다.

## 변경하지 않은 화면의 비교

pixel_diff.py는 두 snapshot의 renderer와 environment 일치, 슬라이드 목록·해상도·이미지 해시를 확인한 뒤 Pillow로 원본/결과 차이를 계산합니다. 전체 고해상도 이미지는 로컬 프로그램에서 처리하며 GLM 컨텍스트에 넣지 않습니다.

편집 전에 잠근 pixel_masks 내부는 비교에서 제외하고, 그 밖에 허용 오차를 넘는 픽셀이 하나라도 있으면 FAIL합니다. 결과는 예상치 않은 픽셀 수/bbox/검사한 픽셀 수/mask 비율을 기록합니다. 동일한 파일이라도 환경이나 renderer를 확인할 수 없으면 PASS하지 않습니다. 원본과 결과를 비교 중 다른 PowerPoint 버전으로 바꾸지 않습니다.

mask는 어디까지나 계획의 일부입니다. 잘못된 mask가 수정 영역 밖을 덮으면 검사가 약해질 수 있으므로 선언된 target·reason과 실제 위치를 계획 시 검토해야 합니다. mask 안쪽은 구조·내용·layout·시각 검토가 필요합니다.

## 근거와 현재 한계

- [TextRange2.BoundHeight](https://learn.microsoft.com/en-us/office/vba/api/powerpoint.textrange2.boundheight): 텍스트 경계와 텍스트 컨테이너는 다른 개념입니다.
- [Slide.Export](https://learn.microsoft.com/en-us/office/vba/api/powerpoint.slide.export): 출력 이미지 크기를 지정할 수 있습니다.
- [TextFrame2.AutoSize](https://learn.microsoft.com/en-us/office/vba/api/powerpoint.textframe2.autosize): 도형 확장과 글자 축소 옵션을 구분합니다.

Microsoft API를 이용한 제안 구현이며 이 개발 환경에는 Windows PowerPoint가 없어 COM E2E는 실행하지 못했습니다. Python 판정기는 합성 snapshot으로 테스트합니다. 회사 Windows에서 최소 합성 PPT로 정상 텍스트/넘치는 텍스트/중첩 그룹/회전/없는 폰트를 시험한 뒤 지원 범위를 확장하십시오. API 오류나 지원 부족을 알려야 하며 Office가 실행됐다는 사실만으로 layout PASS를 선언하지 않습니다.
