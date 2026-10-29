# Magic Survival Lab - Godot native client

Godot4.7stable + GDScript. 실제 앱 클라이언트이며 HTML을 감싼 WebView가 아닙니다. 기존 HTML은 비교용 참조 버전으로 남깁니다.

## 실행과 테스트

```sh
godot --path godot --editor
godot --path godot
godot --headless --path godot --script res://tests/test_simulation.gd
godot --headless --path godot --script res://tests/test_records.gd
godot --headless --path godot --script res://tests/test_ui.gd --quit-after 5
```

명령은 저장소 루트에서 실행합니다. Editor에서 열 때는 이 폴더의 `project.godot`을 선택하세요. 입력은 WASD/방향키 또는 화면 드래그, P/Esc/Android 뒤로 가기는 일시정지, 1/2/3은 강화·유물 선택입니다. 앱이 배경으로 가면 정지하고 자동 재개하지 않습니다.

## 현재 구현

- 퀵300초, 원정600초와510초에 등장하는 보스.
- 마법8종·조합4종·유물12종, 경험치·강화·상자·효과·결과.
- 앱 전용 `user://records.json`의 실제 모드별 기록. 브라우저 기록을 임의로 가져왔다고 처리하지 않습니다.
- 위험 구역의 예고/활성 표시, 보스 방향/체력, 긴 모바일 화면 대응과 한글 글꼴.
- 원작 기준의 먹선 캐릭터·적·보스와 올리브 전장, 검정 숲 메뉴, 거친 마법 선택 카드.
- UI가 소비하지 않은 전투 영역 어디서나 드래그 이동.

Godot 전투52항목·기록34항목·UI22항목(터치/보스 방향/필수 이미지 포함)을 통과했습니다. Android36/16KB페이지 에뮬레이터에서 새 APK 설치·기동·원정 시작·뒤로 가기 정지·중복 뒤로 가기·배경 전환 후 정지 유지까지 확인했습니다. 실제 휴대폰과 사람이 전체 원정을 완주한 밸런스 평가는 별도입니다.

## Android 내보내기

Godot4.7과 일치하는 export templates, Android SDK/JDK가 필요합니다. 이 호스트에서는 SDK/JDK가 이미 설정되어 있어 다른 프로젝트의 전역 설정을 바꾸지 않았습니다.

```sh
mkdir -p output/android
godot --headless --path godot --export-debug Android ../output/android/magic-survival-godot-debug.apk
```

현재 디버그 패키지는 `com.choijunhuk.magiclab`, arm64-v8a, 최소API24이며 출력 APK를 별도 전달합니다. 디버그 서명은 스토어 출시 서명이 아닙니다. 키 저장소·암호·생성된 빌드·`.godot` 캐시는 Git에 포함하지 않습니다.

## 웹 체험판

같은 프로젝트를 Compatibility/single-thread WebAssembly로 내보냅니다. WebGL2가 필요하고 브라우저의 저장 차단/비공개 모드에서는 기록 보존에 제한이 있을 수 있습니다.

```sh
mkdir -p output/web
godot --headless --path godot --export-release Web ../output/web/index.html
```

`.github/workflows/pages.yml`은 main의 Godot/PDF 변경에서 공식 SDK 체크섬 확인, 테스트, Web 빌드, GitHub Pages 배포를 수행합니다. 배포 상태와 실제 주소는 저장소 메인 README에서 확인하세요.

## 파일 책임과 자료

- `scripts/simulation.gd`: 화면 없이 검증하는 전투 규칙.
- `scripts/game.gd`: 실제 장면, 입력, 전장 그리기와 앱 생명주기.
- `scripts/hud.gd`: 네이티브 메뉴·HUD·선택·정지·결과.
- `scripts/records.gd`: 검증된 실제 기록과 저장 실패 처리.
- `data/content.json`: 현재 구현 카탈로그이며 장기 기획의 전체 콘텐츠가 아닙니다.
- `assets/sources.json`, `assets/fonts/OFL.txt`, `THIRD_PARTY_NOTICES.md`: 출처와 라이선스 정보.

100쪽 전체 기획서의 출시/장기 수량은 후속 목표입니다. 현재 APK가 그 전체 수량을 구현했다고 표시하지 않습니다.
