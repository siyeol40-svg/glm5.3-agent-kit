# PPT Master 연결 계약

검토 기준: 2026-11-03, upstream Skill metadata `6.8.0`. 회사 설치본의 경로·파일 해시·버전을 preflight에 별도 기록합니다. 최신 main을 무조건 재설치하지 않습니다.

직접 확인한 문서와 Git blob SHA:

| 문서 | SHA |
|---|---|
| [SKILL.md](https://github.com/hugohe3/ppt-master/blob/main/skills/ppt-master/SKILL.md) | `39e6c8a6ab8e1c1e18dfcbfee879d0ae31dbe4ee` |
| [routing.md](https://github.com/hugohe3/ppt-master/blob/main/skills/ppt-master/workflows/routing.md) | `24e74d14658fb6021957d2346792898bdf320fbe` |
| [edit-native-pptx.md](https://github.com/hugohe3/ppt-master/blob/main/skills/ppt-master/workflows/edit-native-pptx.md) | `1f9ed86429e94ac03ff43088c46f7606a1c02f7a` |
| [shared-standards-core.md](https://github.com/hugohe3/ppt-master/blob/main/skills/ppt-master/references/shared-standards-core.md) | `12ced6c9c2811350f049c405db4a54199b4e8a31` |
| [pptx_delivery_check.py](https://github.com/hugohe3/ppt-master/blob/main/skills/ppt-master/scripts/pptx_delivery_check.py) | `76e0dd50b90b06b567367ada0b9e0adf44db5177` |
| [native-data-interface.md](https://github.com/hugohe3/ppt-master/blob/main/skills/ppt-master/references/native-data-interface.md) | `a8f79cfab6f812441a66cafd2181ab59dcafa26f` |

## 적용과 차이

원본 보존은 엔진의 roundtrip 경로와 일치합니다. 이 Kit은 새 exporter를 만들거나 PPT Master 소스를 복사하지 않습니다. 설치된 엔진의 안내와 `--help`를 실행 시 확인합니다.

- 엔진의 Reference 용어는 Generate에서 자유로운 참고를 뜻하기도 합니다. 이 Kit의 Reference는 **binding design authority**로 명시합니다.
- 엔진은 슬라이드 선택·순서 변경·반복·신규 객체도 지원하지만 v0.1은 **원본 슬라이드 수·순서와 객체 식별자 유지**만 지원합니다. 필요하면 Kit을 통과시키려 하지 말고 별도 계획/향후 roster 지원으로 전환합니다.
- 엔진의 계획 확인 단계가 존재합니다. 사용자에게 이미 구체적인 슬롯/계획 승인을 받았다면 그 근거를 매핑에 기록합니다. 이 Kit 자체는 매 단계마다 새 사용자 확인을 요구하지 않습니다.
- SVG의 수정 객체는 재구축될 수 있습니다. 이를 전체 객체의 바이트 보존으로 오해하지 않습니다. 변환으로 생기는 서식 차이도 diff에 드러나면 검토·사전 허용 없이는 FAIL입니다.
- native proxy, inherited Master/Layout 객체 편집 등 엔진이 지원하지 않는 변경을 우회하지 않습니다.
- native chart/table 데이터 변경은 관련 interface를 읽고 `--native-charts-and-tables`가 필요합니다. v0.1의 자동 콘텐츠 검사는 일반 텍스트/이미지 슬롯 중심입니다. 복잡한 차트/표 내용 진위는 별도 검사 없이는 최종 처리하지 않습니다.
- 엔진의 exports 파일은 이 Kit에서 candidate입니다. 추가 무결성·렌더·영역별 QA를 통과하기 전 최종본이 아닙니다.

## 명령 연결

`PPT_MASTER_DIR`는 실제 설치된 Skill 디렉터리입니다. 모든 명령은 설치본 경로를 사용합니다.

```bash
python3 "$PPT_MASTER_DIR/scripts/attribution_guard.py"
python3 "$PPT_MASTER_DIR/scripts/pptx_to_svg.py" "$SOURCE" -o "$ROUNDTRIP" --inheritance-mode both --roundtrip
# authoring_summary.json 읽기 → 매핑 고정 → 선택된 SVG만 수정
python3 "$PPT_MASTER_DIR/scripts/svg_authoring_view.py" "$ROUNDTRIP/authoring-svg-flat" --refresh-summary
python3 "$PPT_MASTER_DIR/scripts/svg_quality_checker.py" "$ROUNDTRIP" --roundtrip --json
python3 "$PPT_MASTER_DIR/scripts/svg_to_pptx.py" "$ROUNDTRIP" --roundtrip
# exporter가 실제로 출력한 정확한 PPTX 경로를 CANDIDATE로 사용
python3 "$PPT_MASTER_DIR/scripts/pptx_delivery_check.py" "$CANDIDATE"
python3 "$PPT_MASTER_DIR/scripts/source_to_md/ppt_to_md.py" "$CANDIDATE" -o "$RUN/readback.md"
```

각 실행의 실제 종료 코드와 stdout/stderr를 기록합니다. upstream 오류를 Kit의 PASS로 덮지 않습니다. Windows에서 python3가 실제로 시작되지 않는 경우만 동일 명령을 python으로 실행합니다.
