# 플레이테스트 로그

개발용 분석 로그는 `user://playtest_log.jsonl`에만 저장된다. 외부 전송, 플레이어 이름, 계정 정보는 기록하지 않는다.

각 줄은 독립적인 JSON 이벤트다. 공통 필드는 `session_id`, `timestamp_ms`, `mode`, `event`, `data`다.

## 급속 실험 (`speed`)

- `board_started`: 카드 9장 구성, SET 수, 카드 겹침도, 보드 교체 이유
- `hap_attempt`: 선택 카드, 성공 여부, 판정, 남은 답 수, 기본점수·합성 유형·콤보 보너스·패널티
- 급속 실험 점수 규칙 v4는 남은 합성 1개(300점) / 2개(240점) / 3~4개(120점) / 5개 이상(80점)으로 기록한다. `set_pattern`은 분석용으로만 보관하고 점수에는 반영하지 않는다.
- `board_started.generation`: 직전 저답 보드 여부, 후보 재생성 횟수, 재생성 결과의 SET 수와 목표 달성 여부를 기록한다. `replacement_cards_form_set`은 교체된 세 카드만으로 SET이 되었는지 기록하며 항상 `false`여야 한다. 2개 이하 보드 뒤에는 3개 이상 SET를 목표로 최대 20개 후보를 비교한다. 시작 보드도 3개 이상 SET를 확보한다.
- `session_finished`: 최종 점수, 최고 콤보, 보드 교체 횟수

## 정밀 실험 (`gyulhap`)

- `board_started`: 카드 9장 구성, 실제 SET 수, 카드 겹침도
- `hap_attempt`: 합성 성공·중복·실패, 발견 순서, 경과 시간
- `gyul_attempt`: 완료 시점의 발견 합성 수와 실제 합성 수, 성공 여부
- `board_completed`: 완료 성공으로 보드가 끝났을 때의 요약
- `session_finished`: 시간 종료 시의 점수와 최고 콤보

## 자유 실험 (`practice`)

- 정밀 실험과 같은 보드·합성·완료 이벤트를 사용한다. 이벤트 키 `hap`, `gyul`은 로그 호환성을 위해 유지한다.
- `hint_used`: 카드 힌트 또는 완료 확인 힌트, 사용 시점의 남은 합성 수
- `hap_attempt.used_hint`: 밝힌 힌트 카드가 포함된 합성인지 여부
- 힌트가 걸린 합성만 누적 합성에서 제외되며, 라운드에서 힌트를 썼으면 완료 누적은 제외된다.

## 보드 난이도 데이터

`difficulty`에는 아래 값을 기록한다.

- `set_count`: 해당 9장 보드의 전체 SET 수
- `shared_card_count`: 두 개 이상의 SET에 포함되는 카드 수
- `max_card_overlap`: 한 카드가 포함되는 SET 수의 최댓값

이 세 값을 풀이 시간, 완료 실패율, 힌트 사용률과 함께 보면 난이도 프로필을 조정할 수 있다.
