# COM 편집 주의사항

## 접근과 DRM

정상 PowerPoint UI와 승인된 Windows 사용자 세션에서 먼저 열기/객체 읽기/복사본 생성/편집/저장/닫기/재열기를 확인합니다. 각 작업을 독립적으로 기록합니다. ZIP 접근 오류는 파일 손상 증거도 DRM 원인의 확정 증거도 아닙니다. 보호 정책이 확인된 파일에서는 같은 패키지 접근 경로를 반복하지 않습니다.

PowerPoint 객체 모델이 허용하는 작업만 합니다. DRM 해제, 비보호 파일 추출, 우회 프로세스 등록, 다른 경로로 자동 이미지/PDF export를 시도하지 않습니다. JSON 증거를 회사 허용 로컬 폴더에 기록하는 것 또한 허용 여부를 확인합니다. 원본 PPTX bytes를 Python으로 읽거나 hash하는 것을 필수로 요구하지 않습니다.

## 세션·복사본·저장

사용자 PC의 대화형 세션에서 순차 실행합니다. unattended server나 병렬 Office 인스턴스가 동일하게 안정적이라고 가정하지 않습니다. DRM/Office 대화상자나 시간 초과가 있으면 상태를 기록하고 멈춥니다. 사용자 권한을 바꾸거나 자동화 정책을 우회하지 않습니다.

원본 경로와 결과 경로를 먼저 분리합니다. 승인된 PowerPoint SaveCopyAs/별도 저장 동작으로 작업 복사본을 만들고, 복사본을 다시 열어 편집합니다. 원본의 열려 있는 상태를 임의로 저장/닫기/덮어쓰기하지 않습니다. 현재 사용자가 열어 둔 PowerPoint에 연결했다면 애플리케이션 전체 Quit을 호출하지 않습니다. 실패 시 다른 Office 프로세스를 일괄 종료하지 않습니다.

저장 성공과 재열기 성공은 다릅니다. 결과를 저장·닫기·재열고 shape 수/키/내용·알려진 속성을 다시 추출하십시오. 원본 unchanged 여부는 가능한 metadata/COM 기록으로 확인하되 파일 bytes를 검사하지 않았으면 그 한계를 보고합니다.

## 텍스트

대상 slide/shape/group 경로와 기존 문구를 확인하고 필요한 범위만 변경합니다. 전체 TextRange.Text 대입은 혼합 run·문단 서식 보존을 보장하지 않습니다. Find/Replace 또는 범위 편집을 사용하더라도 결과 font/size/bold/color/정렬/줄바꿈을 다시 읽으십시오. “Replace를 썼으니 서식이 보존됐다”는 결론은 금지합니다.

넘치는 문장은 요약·재구성부터 합니다. 공간 부족을 이유로 글자를 일괄 축소하거나 프레임을 늘리지 않습니다. groups의 로컬/절대 좌표·scale·rotation을 혼동하지 않습니다. 텍스트 bounds는 가림·복잡한 효과의 잘림·실제 가독성까지 증명하지 않습니다.

## 사진·그림·도해

기존 사진이 프레임으로 포함된 것인지 내용인지 구분합니다. reference 사진을 남겨둔 채 새 문구만 넣지 마십시오. 일반 사진 replacement API가 있다고 추정하거나 검증하지 않은 PictureFormat.Replace를 호출하지 마십시오. 실제 버전의 지원 API/승인된 UI 작업을 확인합니다.

새 picture 객체가 필요하면 기존 Left/Top/Width/Height/Rotation/Z-order/crop/선/그림자/애니메이션 연결을 기록하고, 의도된 차이를 계획에 넣습니다. 새 이미지 비율을 보존하며 frame fit/crop을 정합니다. PickUp/Apply는 서식 복사를 돕지만 모든 이미지 프레임·효과·연결 보존을 보장하지 않습니다. 교체 후 원래 picture가 뒤에 남아 있는지도 확인합니다.

SmartArt/차트/표/embedded object는 일반 도형과 다릅니다. 내부 데이터 변경 가능성을 시험하고, 지원하지 않으면 원본 내용이 남았는데도 새 주제에 맞게 바뀌었다고 보고하지 마십시오.

## 근거

- [Presentations.Open](https://learn.microsoft.com/en-us/office/vba/api/powerpoint.presentations.open)
- [SaveCopyAs](https://learn.microsoft.com/en-us/office/vba/api/powerpoint.presentation.savecopyas)
- [TextRange.Replace](https://learn.microsoft.com/en-us/office/vba/api/powerpoint.textrange.replace)
- [Shape.PickUp](https://learn.microsoft.com/en-us/office/vba/api/powerpoint.shape.pickup)
- [Office unattended automation considerations](https://learn.microsoft.com/en-us/office/client-developer/integration/considerations-unattended-automation-office-microsoft-365-for-unattended-rpa)

이는 Microsoft 객체 모델의 설명이며 회사 DRM의 특정 기능 허용을 보장하지 않습니다. com_native_manifest.ps1은 이 개발 환경에서 Office COM E2E를 실행하지 못했으며 대상 Windows의 합성/승인 파일로 확인해야 합니다.
