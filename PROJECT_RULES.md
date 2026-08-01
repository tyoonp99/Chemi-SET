# 📘 CHEMI-SET PROJECT RULES & ARCHITECTURE

> 문서 버전: 2.0  
> 본 문서는 Godot 4 기반 모바일 퍼즐 게임 **Chemi-SET**의 코어 아키텍처 가이드라인입니다.  
> UI 디자인은 `UI_GUIDELINES.md`, 진행 상황과 임시 상태는 `TODO.md`를 참조합니다.

---

## 1. 프로젝트 목적 및 핵심 규칙

- **게임 목표:** 9개의 카드 중 3개를 선택해 **SET** 성립 여부를 판정한다.
- **SET 판정:** 카드의 각 속성(모양, 색상, 상태 / 값 0~2)의 합이 `% 3 == 0`이어야 한다.

---

## 2. 씬·스크립트 책임

| 대상 | 책임 | 해서는 안 되는 일 |
| :--- | :--- | :--- |
| `main.tscn` / `main.gd` | 모드 로드, 이벤트 중계 | 카드 규칙 계산, 보드 직접 조작 |
| `mode_*.tscn` / `mode_*.gd` | 보드, 규칙, 타이머 등 세션 상태 관리 | HUD·팝업 직접 조작, `UIManager` 직접 참조 |
| `game_ui.tscn` / `ui_manager.gd` | HUD 갱신 및 공통 팝업 표시 | 게임 규칙 판정, 점수 직접 계산 |
| `Global.gd` | 로컬 저장 데이터, 다음 모드 시작 설정 | 진행 중인 게임의 휘발성 상태 보관 |
| `set_rules.gd` / `card_catalog.gd` | 순수 공통 규칙·카드 데이터 처리 | 특정 씬 노드 직접 참조 |

---

## 3. 모드 인터페이스 계약

모든 모드 스크립트는 중앙 매니저 수정 없이 확장될 수 있도록 아래 규격을 구현한다. UI 직접 갱신은 금지한다.

```gdscript
func start(config: Dictionary) -> void

signal score_changed(score: int, combo: int)
signal time_changed(seconds_left: int, unlimited: bool)
signal game_over(result: Dictionary)
```

`game_over`의 `result`는 최소한 아래 키를 포함한다.

```gdscript
{
  "mode": StringName,
  "score": int,
  "combo": int
}
```

---

## 4. 파일 분리와 리소스 원칙

1. **`.tscn`**: 화면 레이아웃, 노드 계층, 신호 연결을 담당한다.
2. **`.tres`**: 색상, 폰트, `StyleBoxFlat` 등 시각 스타일 값을 저장·재사용한다. 스크립트에서 런타임 스타일을 생성하지 않는다.
3. **`.gd`**: 로직을 담당한다. UI 스크립트의 노드 참조는 `%UniqueName`을 사용한다.

---

## 5. 네이밍 및 데이터 저장 정책

- **파일/씬:** 소문자 스네이크 케이스 — `mode_speed.tscn`
- **클래스/노드:** 파스칼 케이스 — `ModeSpeed`
- **신호:** 상태형 또는 과거형 — `score_changed`
- **데이터 소유권:** 진행 중 게임의 점수·상태는 모드 씬이, 영구 저장 데이터와 다음 모드 설정은 `Global.gd`가 소유한다.
- **랭킹:** 모드별로 분리해 관리한다.
