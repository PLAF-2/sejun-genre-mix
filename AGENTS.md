# This is ME / Genre Mix Game 개발 안내

기준일: 2026-10-27. 현재 `godot-game/scenes/*.tscn`, `godot-game/scripts/*.gd`, `godot-game/default_bus_layout.tres`를 확인해 작성했다. 이 문서의 루트는 현재 작업 폴더이며, Godot의 `res://`는 하위 `godot-game/`에 해당한다.

## 1. 목적과 핵심 플레이

- 게임에 관심 있는 제작자를 표현하는 동아리 발표용 장르 체험 게임이다. 목표 플레이 시간은 약 5~10분이며, 실제 총 플레이 시간 검증은 별도 필요하다.
- 2D 복도에서 캐릭터를 움직여 각 방의 문 중앙에 접근하고 E로 입장한다. 앞방을 클리어하면 다음 방이 열린다.
- 순서: 카드 → 플랫포머 → 리듬 → 생존형 로그라이크 → 3D FPS → 다섯 장르를 연결한 최종 보스전.
- 기본 캐릭터는 사용자의 사진, 상대 및 최종 보스는 동아리장 사진을 참고한다. 추가 사진은 없으므로 기존 제공 사진만 사용한다. 미관 개선 시 사진과의 유사성을 유지하고 과한 애니메이션풍 변형은 피한다.

## 2. 현재 구현된 기능

### 공통 및 복도

- 가천대 참고 픽셀 배경, 픽셀 문, 플레이어 이동 애니메이션, 방 잠금·진행 표시.
- ESC 설정 메뉴와 일시정지, BGM/SFX 음량, 종료 버튼. 음량 설정은 `user://settings.cfg`에 저장한다.
- F11 전체화면 전환. 개발용 F2 방 스킵과 복도에서 숫자 1~6으로 방 바로 열기.
- 방 바로 열기는 `dev_room_override`를 사용하며 정상 순차 클리어와 처리 방식이 다르다.

### 1번 방: 카드 (`card_game.gd`)

- 플레이어 J/Q/K/A 각 1장, 상대는 같은 카드와 조커 1장으로 시작한다. 상대가 먼저 뽑는다.
- 상대 카드는 뒷면, 플레이어 카드는 앞면. 뽑기와 짝 이동 애니메이션, 유지되는 짝 카드 더미, 승패 결과 및 재도전.

### 2번 방: 플랫포머 (`platform_game.gd`)

- 좌우 이동·점프, 코인 3개, 순찰 적 3마리, 가시, 이동 발판.
- 날개 신발 획득 후 추가 점프. 코인 3개를 모아 오른쪽 깃발에 도달하면 클리어한다.
- 피격·무적 시간·실패 후 재시작을 처리한다.

### 3번 방: 리듬 (`rhythm_game.gd`)

- 두 공의 회전과 타일 이동을 이용한 한 버튼 리듬 체험. SPACE·좌클릭·터치 입력.
- 치이카와 외곽선을 따라가는 79개 타일, 완주 후 전체 모습 공개, 체크포인트 없이 재도전.
- `usagi_rap_video_section_45s.mp3` 재생, 고정 BPM 105, PERFECT/GOOD/MISS와 콤보·체력.
- 오디오 재생 위치와 출력 지연을 반영한 판정, 타격 이펙트·화면 흔들림·클리어 화면.

### 4번 방: 로그라이크 (`roguelike_game.gd`)

- 약 60초 생존 구성. 적 처치·경험치 보석 획득·빠른 레벨업·스킬 선택.
- 화염·번개·얼음 자동 공격. 각 스킬은 미습득 0, 습득 후 1~4단계이며 1→2는 공격력 강화, 2→3은 이펙트/공격 방식 강화다.
- 모든 스킬이 3단계 이상일 때만 3→4 궁극 강화가 열린다. 2→3은 잠그지 않는다.
- 레벨 3 미만 초반 난이도 완화, 적/엘리트/보스, 저확률 회복 아이템과 지속 회복.
- 일반 모드에서 48초 이후 보스 등장. 레벨업 선택창은 전투와 구분되는 상태 및 높은 표시 순서를 사용한다.
- 최종 보스전용 `start_boss_gauntlet()`도 제공한다. 스킬 단계 계승, 레벨업 없는 대량 부하전, 70마리 처치 목표와 전용 완료 신호.

### 5번 방: 3D FPS (`shooter_game.gd`)

- SubViewport 기반 3D 전장, WASD/방향키·마우스 시점·좌클릭 사격·R 재장전·SPACE 점프·Ctrl/C 웅크리기.
- 체력 100, 권총 6발 탄창, 잔탄 표시와 1.45초 재장전 바/동작. 이동·총격 AI 8명과 벽 충돌.
- 부위별 피해: 머리 60, 몸통 34, 다리 22. 기본 AI 구간 제한 시간은 50초다.
- 솔로 또는 LAN 호스트/참가 선택. ENet 포트 7005와 RPC로 상대 플레이어 동기화.
- AI 8명 처치 후 연결 상대가 있으면 체력 회복·양측 반대 위치 배치 후 1대1. 혼자면 통과한다. 실제 두 PC 검증은 별도 필요하다.

### 최종 방 (`final_boss_game.gd`)

- 함께 도박하다 상대가 패배하고 판돈을 주지 않은 채 도주하는 대화로 시작한다.
- `story → card → chase → rhythm → rogue → shooter → ending`을 대화 장면과 연결한다.
- 카드 단계는 첫 방 전체 규칙 재사용이 아니라 선택 시 플레이어가 이기는 짧은 연출이다.
- 마리오식 횡스크롤 추격, 도착 후 대화, 박자에 맞춘 공격 회피, 부하 섬멸, 3D 자동소총 결투.
- 부하전은 `roguelike_game.gd`의 별도 인스턴스를 재사용한다. 4번 방에서 계승하는 데이터는 `skill_levels`이며 체력·경험치·적 목록 전체 저장 상태를 전달하는 것은 아니다.
- 최종 보스 HP 2400, 화염·얼음·번개·돌진, 공격 범위 사전 표시, 플레이어 피격 피드백.
- 총구 섬광·탄두·탄도 잔상·명중 불꽃. 피해 판정은 레이캐스트 즉시 처리하며 탄두는 시각 연출이다.
- F3 또는 CHAPTER SKIP으로 챕터별 스킵.
- Blender/MPFB 제작 `assets/3d/club_leader_boss/club_leader_boss.glb`를 불러온다. 피부는 GLB 호환 PBR 재질이며 눈·눈썹·머리카락은 머리 골격에 연결한다. 머리·척추·양팔·팔꿈치·다리·무릎의 10개 골격을 코드로 조절하며 일부 기존 파츠 변수는 호환용 빈 피벗이다.

## 3. 주요 파일의 역할

| 경로 (`godot-game/` 기준) | 역할 |
| --- | --- |
| `scenes/main.tscn` | Main, 편집용 프리뷰, GameCanvas와 최종 보스 씬 인스턴스 |
| `scenes/final_boss_game.tscn` | 최종 방 루트 Control과 해당 스크립트 연결 |
| `scripts/main.gd` | 복도/플레이어/UI 생성, 방 인스턴스, 입장·해금·진행, 설정, 개발 단축키 |
| `scripts/editor_preview.gd` | `@tool`로 편집기 2D 화면에 복도·문 배치 표시. 런타임에는 숨김 |
| `scripts/card_game.gd` | 카드 규칙·UI·애니메이션·승패 |
| `scripts/platform_game.gd` | 2D 물리·발판·코인·아이템·적·골인 |
| `scripts/rhythm_game.gd` | 음원 시계·타일 경로·공 회전·입력 판정·완주 공개 |
| `scripts/roguelike_game.gd` | 생존전·성장·스킬·회복·보스·최종 방 부하전 공용 구현 |
| `scripts/shooter_game.gd` | 3D FPS·AI·부위 판정·재장전·LAN 연결/동기화 |
| `scripts/final_boss_game.gd` | 보스전 단계·대화·추격/회피·부하전 연결·3D 결투·VFX·엔딩 |
| `scripts/sfx.gd` | 공유 `Sfx.play()`/`play_unique()` 효과음 재생, 14개 오디오 플레이어 풀 |
| `default_bus_layout.tres` | Master/BGM/SFX 버스. BGM과 SFX는 Master로 전달 |

## 4. 씬과 스크립트 연결

```text
Main (Node2D, main.gd)
├─ EditorPreview (Node2D, editor_preview.gd)
│  └─ Hero (Sprite2D, 편집기용)
└─ GameCanvas (CanvasLayer)
   └─ FinalBossGame (final_boss_game.tscn → final_boss_game.gd)

main.gd.build_hud()에서 CanvasLayer에 동적으로 추가:
  card_game / platform_game / rhythm_game / roguelike_game / shooter_game
  각 *_GAME_SCRIPT.new() → start_game() → game_won → main.gd.clear_current_room()

최종 방:
  main.gd → set_inherited_skills(roguelike_game.skill_levels) → start_game()
  final_boss_game.gd → ROGUELIKE_GAME_SCRIPT.new()
    → start_boss_gauntlet() → boss_gauntlet_won → 다음 대화/3D 결투
  최종 완료 → game_won → main.gd.clear_current_room()
```

- `$EditorPreview`, `$GameCanvas/FinalBossGame` 경로를 유지한다.
- 개별 미니게임의 대부분은 별도 `.tscn` 없이 스크립트가 노드를 생성한다. 편집기의 프리뷰가 실행 중 전체 노드 구조와 같다고 가정하지 않는다.
- 3D 보스 골격 연결은 `head`, `spine03`, `upperarm01.L/R`, `lowerarm01.L/R`, `upperleg01.L/R`, `lowerleg01.L/R` 이름에 의존한다. 팔 방향은 부모 골격과 rest 축을 반영한다. GLB 교체 시 이름·방향·배율·의상 변형을 확인한다.
- `Sfx`는 전역으로 참조된다. 등록 설정을 바꿔야 하는 작업에서만 `project.godot`을 추가 확인한다. 이번 문서 작성에서는 해당 설정 파일을 읽지 않았다.

## 5. 아직 완료되지 않았거나 검증이 필요한 부분

- 사진 유사도와 현실적인 피부·눈·머리카락·의상 디테일은 계속 개선이 필요하다. 현재 모델을 리니지/검은사막 수준의 완성 모델로 취급하지 않는다.
- Mixamo 애니메이션 연결과 완성된 피격·돌진 애니메이션은 아직 없다. 현재는 이동량에 연동한 팔다리 동작과 상체·머리·시전 동작을 코드로 생성한다. 대기/시전 렌더링은 확인했으나 보행 품질과 얼굴 유사도는 추가 검토가 필요하다.
- 전체 5~10분 플레이 시간, 난이도, 음원 박자 일치, 실기기 소리/타격감, LAN 두 PC 대전 검증이 필요하다.
- 클리어 진행 저장/불러오기 기능은 확인되지 않았다. 현재 확인된 설정 저장은 음량이다.
- 공개 저장소는 `https://github.com/PLAF-2/sejun-genre-mix`, 웹 배포는 `https://plaf-2.github.io/sejun-genre-mix/`다. GitHub Actions의 첫 Web/Windows 빌드와 Pages 배포가 성공했다. 게임 변경을 main에 올리면 자동 재배포한다. 발표 자료는 요청 범위 밖이며 개발 버튼은 유지한다.
- Web은 솔로 전용으로 LAN 선택을 비활성화한다. 같은 와이파이 대전은 Windows 내보내기를 사용한다. 한글 표시는 포함된 NanumGothic 폰트를 기본 테마와 ThemeDB에 지정한다.

## 6. 알려진 오류 및 주의사항

- 이전 실행 기록에서 Godot의 `Safe save failed`가 보고됐다. 저장 위치/권한 관련 환경 문제 가능성이 있으며 현재 해결 여부는 미확인이다. 보안 프로그램 해제부터 권하지 않는다.
- 이전 전체 흐름 검사 종료 때 `ObjectDB instances were leaked` 및 `resources still in use at exit`가 간헐적으로 출력됐다. 정리 수명 관련 조사 대상이며, 현재 문서 작업에서는 재실행하지 않았다.
- `--full-flow-auto-test`는 방을 열고 `game_won` 신호를 직접 발생시켜 진행 수만 검사한다. 각 게임을 실제로 플레이하거나 최종 3D 전투·렌더링을 검증하는 테스트가 아니다.
- 보스 내부 검사에는 `--boss-preview --boss-auto-test`를 함께 사용해야 한다. `debug_test_all_phases()`는 모든 게임 종료를 보장하는 자동 종료 테스트가 아니다.
- 화면 없는 headless 모드에서는 실제 화면 이미지와 미관을 검증할 수 없다. 과거 자동 캡처 시 null 텍스처 오류가 있었고 해당 캡처 코드는 제거됐다.
- `work/boss_model_check.gd`는 프로젝트 밖의 보스 전용 검사 도구다. 실제 OpenGL 렌더러로 실행해 10개 골격 연결과 대기/시전 화면을 확인하고 종료한다. 결과 이미지는 `work/boss_model_idle.png`, `work/boss_model_cast.png`이며 게임 배포 코드에 포함하지 않는다.
- 최종 방에는 현재 사용하지 않는 이전 로그라이크 처리 함수도 남아 있다. 실제 `rogue` 단계는 `rogue_room_game`이 처리하므로 오래된 `update_rogue()`만 수정하지 않는다.
- `Sfx.play_unique()`는 공유 풀의 플레이어 참조를 보관한다. 풀 재사용 시 다른 음원을 중단할 가능성은 후속 사운드 문제 발생 시 조사할 항목이지 확정된 발생 원인은 아니다.
- 입력 처리와 일시정지는 방별 `_input`/`_unhandled_input` 및 상태 변수에 의존한다. 설정 중 공격·점프·마우스 캡처가 재개되지 않는지 확인한다.
- Blender 원본은 루트의 `blender_project/`, 제작 보조 코드는 `blender_tools/`에 있다. 게임은 내보낸 GLB를 사용한다. `.blend`를 무심코 `res://`로 옮기면 Blender 가져오기 설정 오류가 생길 수 있다.
- 원본 참고 사진은 모델 폴더의 `references/`에 있으며 공개 저장소와 내보내기에서 제외한다. 사진 기반 캐릭터·GLB·Blender 원본의 공개는 사용자가 승인했다.

## 7. 앞으로의 개발 규칙과 사용량 절약

1. 사용자 요청과 직접 관련된 파일부터 읽는다. 이 문서를 출발점으로 필요한 함수와 연결 부분만 확인한다.
2. 일반 Godot 수정은 관련 `.gd`, `.tscn`, `.tres`부터 확인한다. 설정·원본 모델·다른 형식은 작업에 실제로 필요할 때만 확장한다.
3. `.godot/`, 각종 캐시, `build/`, `dist/`, `node_modules/`, `.blender-user/`, `.godot-*-appdata/`, `.godot-appdata/`, `.godot-temp/` 및 임시 폴더를 기본 검색/분석에서 제외한다. 설치된 확장 코드나 생성 빌드를 재귀 분석하지 않는다.
4. 기존 씬 구조·노드 경로·신호·게임 상태 전이를 유지한다. 요청하지 않은 기능, 에셋 교체, 정리 목적의 대규모 리팩터링은 하지 않는다.
5. 스킬 4단계 잠금, 4번 방과 부하전의 공용 구현, FPS LAN 전환, 사진 기반 캐릭터 방향을 보존한다.
6. 동일 오류로 수정과 검사를 반복하면 원인을 다시 분석한다. 출력만 줄이거나 무조건 재시도하여 통과했다고 판단하지 않는다.
7. 변경 범위에 맞는 검사만 수행한다. 문서만 수정했으면 문서 내용/경로 검토로 충분하며 Godot 실행·캐시 생성·빌드 재생성은 하지 않는다.
8. 코드 변경 때에는 관련 파싱/실행 오류와 실제 수정된 동작을 확인한다. 전체 흐름 검사 통과와 개별 전투·비주얼 검증을 구분해 보고한다.
9. 미니게임 미리보기 인자: `--card-preview`, `--platform-preview`, `--rhythm-preview`, `--roguelike-preview`, `--shooter-preview`, `--boss-preview`. Godot 실행 예: `Godot --path godot-game -- --boss-preview`.
10. 문서·기능 작업 완료 후 변경한 파일과 내용을 한국어로 짧게 요약한다. 확인하지 않은 사항을 완료했다고 쓰지 않는다.
11. 모델 원본·사진·빌드 등 사용자 자료를 임의 삭제하거나 덮어쓰지 않는다. 요청 범위 밖 변경은 보존한다.

이 문서는 개발 시작 시 필요한 맥락을 줄이기 위한 안내다. 상세 작업에서는 해당 파일의 최신 코드를 우선하고, 구조나 동작을 변경한 경우 관련 항목만 갱신한다.
