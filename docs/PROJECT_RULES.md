# CHEMI-SET 프로젝트 규칙과 아키텍처

> 문서 버전: 2.1
> Chemi-SET은 Godot 4 기반 모바일 SET 퍼즐 게임이다. UI 기준은 `UI_GUIDELINES.md`, 진행 이력은 `RELEASE_MILESTONES.md`를 참조한다.

## 1. 핵심 규칙

- 9장의 카드에서 3장을 선택해 SET 성립 여부를 판정한다.
- 카드의 모양·색상·상태 값은 각각 0~2다.
- 세 카드의 각 속성 합이 `% 3 == 0`일 때 SET이다.
- 플레이어에게는 조건을 만족하는 세 카드의 조합과 판정 행동을 **합성**, 현재 보드의 모든 합성을 찾았다는 판정을 **완료**로 표현한다.

## 2. 책임 분리

| 대상 | 책임 | 금지 |
| --- | --- | --- |
| `main.tscn` / `main.gd` | 모드 로드, 신호 중계, 공통 UI 연결 | 카드 규칙 계산, 보드 조작 |
| `mode_*.tscn` / `mode_*.gd` | 보드, 타이머, 점수, 세션 상태 | `UIManager` 직접 참조, 공통 HUD·팝업 갱신 |
| `game_ui.tscn` / `ui_manager.gd` | HUD와 공통 팝업 표시 | 게임 규칙·점수 계산 |
| `Global.gd` | 영구 저장 데이터와 다음 모드 설정 | 진행 중인 보드·선택 상태 보관 |
| `set_rules.gd` / `card_catalog.gd` | 순수 규칙 연산과 카드 데이터 | 씬 노드 참조 |

모드 씬의 카드와 해당 모드 전용 행동 영역은 모드가 소유한다. 공통 HUD와 팝업은 반드시 `UIManager` 공개 메서드와 신호를 통해서만 갱신한다.

## 3. 모드 인터페이스

모든 모드는 아래 계약을 구현한다.

```gdscript
func start(config: Dictionary) -> void

signal score_changed(score: int, combo: int)
signal time_changed(seconds_left: int, unlimited: bool)
signal game_over(result: Dictionary)
```

`game_over` 결과에는 최소 `mode`, `score`, `combo`를 포함한다.

개발용 분석이 필요한 모드는 선택적으로 아래 신호를 추가할 수 있다. 중앙 매니저가 이를 `PlaytestLogger`로 중계하며, 게임 규칙과 UI를 직접 조작하지 않는다.

```gdscript
signal telemetry_event(event_name: StringName, data: Dictionary)
```

## 4. 파일과 리소스

- `.tscn`: 레이아웃, 노드 구조, 신호 연결만 담당한다.
- `.tres`: 공용 색상, 폰트, `StyleBoxFlat`, `LabelSettings`처럼 재사용할 시각 리소스를 소유한다.
- `.gd`: 게임 로직과 동작만 담당한다. 런타임 `StyleBoxFlat.new()` 및 스타일 덮어쓰기는 금지한다.
- UI 스크립트의 씬 노드 참조는 `%UniqueName`만 사용한다.

## 5. 네이밍과 저장 데이터

- 파일·씬: 소문자 스네이크 케이스 (`mode_speed.tscn`)
- 클래스·노드: 파스칼 케이스 (`ModeSpeed`)
- 신호: 상태형 또는 과거형 (`score_changed`)
- 세션 점수·선택 상태는 모드 씬이 소유하고, 영구 기록과 설정은 `Global.gd`가 소유한다.
- 랭킹은 모드별로 분리한다.
- 사용자에게 보이는 모드명은 **급속 실험**, **정밀 실험**, **자유 실험**이다.
- 내부 호환 식별자 `speed`, `gyulhap`, `practice`와 기존 저장 키는 세이브 호환성을 위해 유지한다. 새 UI 문구에서 과거 명칭을 사용하지 않는다.

## 6. 자유 실험의 힌트와 누적 기록

- `💡 힌트`는 한 라운드에서 여러 번 사용할 수 있지만, 활성 힌트는 하나뿐이다.
- 남은 합성이 있으면 아직 찾지 못한 합성 조합 하나의 카드 한 장을 강조한다. 해당 조합을 찾으면 다음 힌트를 사용할 수 있다.
- 힌트가 직접 가리킨 합성만 누적 합성에서 제외하고, 다른 직접 정답 합성은 누적한다.
- 남은 합성이 없을 때 힌트를 누르면 `모든 합성을 찾았습니다! 완료를 눌러주세요.`라고 안내한다.
- 라운드에서 힌트를 한 번이라도 사용하면, 완료에 성공해도 누적 완료는 증가하지 않는다.
- 자유 실험의 완료 실패에는 감점이나 기회 소진이 없다.
