# Genre Mix Game — This is ME

PLAF 2기 중간 발표용 Godot 게임. 카드, 플랫포머, 리듬, 생존형 로그라이크, 3D FPS를 체험한 뒤 다섯 장르를 연결한 최종 보스전에 도전합니다. 개발 중인 버전입니다.

- 게임 실행: https://plaf-2.github.io/sejun-genre-mix/
- 공개 소스: https://github.com/PLAF-2/sejun-genre-mix

## 개발 환경과 실행

- Godot **4.7.2 Standard**를 사용합니다. `godot-game/project.godot`을 가져온 뒤 **F5**로 전체 게임을 실행하세요.
- 실제 게임 소스는 `godot-game/`입니다. 루트의 `src/`, `index.html`, `package.json`은 이전 Phaser 프로토타입으로 현재 Godot 게임을 빌드하지 않습니다.
- 개발 구조와 주의사항은 [AGENTS.md](AGENTS.md)에 정리되어 있습니다.
- 3D 원본은 `blender_project/`, 제작 보조 스크립트는 `blender_tools/`입니다. Godot은 내보낸 GLB를 사용합니다.

## 조작

| 구간 | 조작 |
| --- | --- |
| 복도 | A/D 또는 방향키 이동, 문 중앙에서 E 입장 |
| 공통 | ESC 설정·음량, F11 전체화면 |
| 카드 | 마우스로 카드 선택 |
| 플랫포머 | A/D 이동, SPACE 점프 |
| 리듬 | SPACE 또는 좌클릭 |
| 로그라이크 | WASD/방향키 이동, 레벨업 시 강화 선택 |
| FPS | WASD 이동, 마우스 시점, 좌클릭 사격, R 재장전, SPACE 점프, Ctrl/C 웅크리기 |
| 개발용 | 복도에서 숫자 1~6 방 바로 열기, F2 방 스킵, 최종 보스전 F3 챕터 스킵 |

## 웹 배포와 수정

`.github/workflows/deploy-game.yml`은 `main`에 게임 변경을 올릴 때 Godot 웹 버전과 Windows 버전을 자동으로 만듭니다. 웹 버전은 GitHub Pages에 배포하고 Windows 파일은 해당 Actions 실행의 `GenreMixGame-Windows` 다운로드로 제공합니다.

저장소의 **Settings → Pages → Source → GitHub Actions** 설정과 첫 배포를 완료했습니다. 이후 게임 변경을 `main`에 올리면 같은 실행 주소가 갱신됩니다.

수정 과정은 `Godot에서 저장 → Git 커밋 → main에 push → Actions 성공 → 같은 웹 주소 새로고침`입니다. 로컬 저장만으로 인터넷 배포가 바뀌지는 않습니다. 배포에는 빌드 시간이 필요하며 플레이 중인 화면이 자동으로 교체되지는 않습니다. 이전 화면이 남으면 Ctrl+Shift+R로 새로고침하세요.

### 로컬 내보내기

Godot 4.7.2의 공식 템플릿 설치 후 프로젝트 루트에서:

```sh
mkdir -p web-build build
godot --headless --path godot-game --editor --quit
godot --headless --path godot-game --export-release Web ../web-build/index.html
godot --headless --path godot-game --export-release "Windows Desktop" ../build/GenreMixGame.exe
```

웹 결과물은 HTTP 서버에서 제공해야 합니다. `index.html`을 파일 탐색기에서 직접 열면 실행되지 않을 수 있습니다. 생성된 HTML/JS/WASM/PCK는 이름을 따로 바꾸지 마세요. Windows 공유 시 EXE와 PCK를 같은 폴더에 넣어 함께 전달하세요.

## 웹 버전 제한

- PC Chrome/Edge와 키보드·마우스를 권장합니다. WebGL 2.0이 필요합니다.
- 웹은 솔로 플레이용입니다. ENet 기반 같은 와이파이 대전은 Windows 버전에서 이용하세요.
- 브라우저가 전체화면·마우스 잠금·오디오를 위해 클릭이나 키 입력을 요구할 수 있습니다.
- Windows와 브라우저의 리듬 판정 지연 및 3D 성능은 다를 수 있습니다. 발표 전 사용할 PC에서 확인하세요.

## 자료와 출처

- 한글 표시는 Google Fonts의 나눔고딕을 포함합니다. `godot-game/assets/fonts/OFL.txt`의 라이선스를 함께 보관합니다.
- 효과음 출처는 `godot-game/assets/audio/sfx/SFX_LICENSE.md`를 참고하세요.
- 음악·캐릭터 등 제3자 자료는 소스 공개만으로 별도 이용 허락이 부여되지 않습니다. 이 저장소 전체를 임의의 오픈소스 라이선스로 재허가하지 않습니다.
- 원본 인물 참고 사진, 캐시, 설치 파일과 로컬 빌드는 공개 소스 및 내보내기에서 제외합니다.
