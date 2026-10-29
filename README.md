# Magic Survival Lab

매직 서바이벌에서 영감을 받은 모바일 생존 게임 프로젝트입니다. Godot4.7 + GDScript로 엔진을 확정하고 실제 네이티브 클라이언트를 구현했습니다. HTML/Canvas 버전은 전투 규칙을 비교하는 참조로 유지합니다.

- **[Godot 프로젝트와 실행·검증 안내](godot/README.md)**
- **[라이브 Godot 웹 체험판](https://choijunhuk.github.io/magic-survival-lab/)** — GitHub Pages 자동 배포 대상. 실제 배포 성공과 로딩 검증은 별도 기록합니다.

- **[전체 게임 기획서 PDF - 100쪽](output/pdf/magic-survival-full-design.pdf)** — 출시 설계와 장기 확장, 전투·콘텐츠·세계·성장·아트·앱 제작·검증
- **[전체 기획 원고](docs/gdd/FULL_DESIGN.md)** — 출시 제안 24마법·36조합·96유물·6지역, 장기 제안 48마법·72조합·180유물·9지역. 미래 목표이며 구현 수량이 아닙니다.
- [초기 확장 제안](docs/superpowers/specs/2026-10-29-expansion-design.md) — 초기 논의 기록. 최종 규모·공명·경제는 전체 기획서를 우선합니다.
- [현재 UI/동작 기준](DESIGN.md)
- [다운로드한 전체 에셋 출처](assets/catalog.json) / [현재 게임에 사용한 28개 에셋](assets/sources.json)

## 실행

`play.html`을 브라우저에서 열면 서버 없이 플레이할 수 있습니다. PC는 WASD/방향키, 모바일은 화면 드래그로 이동하며 공격은 자동입니다. P/Esc로 정지하고 1/2/3으로 강화 후보를 선택합니다.

개발용 서버와 검증에는 다음 명령을 사용합니다. 추가 npm 의존성은 없습니다. 개발 서버에는 Python 3, 빌드와 테스트에는 Node.js가 필요합니다.

```sh
npm start          # http://127.0.0.1:4173
npm test           # 전투·진행·입력 규칙
npm run check      # JavaScript 문법 검사
npm run build      # play.html 및 atlas.html 재생성
```

`atlas.html`은 콘텐츠 아이콘 261개를 탐색하는 도감입니다. 도감을 열 때는 `assets/` 폴더도 같은 위치에 있어야 합니다.

## 구현 상태

HTML 참조 버전에는 5분 생존과 최대 10분 원정, 8분 30초에 등장하는 보스와 예고 공격, 모드별 기록을 구현했습니다. 원정은 보스 처치로 승리하며 제한시간에 보스가 살아 있으면 패배합니다. 기존 기록을 보존하고 모드별 결과를 구별합니다.

전투 콘텐츠는 마법 8종·조합 4종·유물 12종이며 Godot 앱에도 같은 규칙을 옮겼습니다. 추가 맵·연구·시작 계열·공명과 전체 기획 수량은 아직 구현되지 않았습니다. 도감의 이미지 개수와 실제 전투 기능 수를 구별합니다.

2026-10-29 검증: 테스트 35/35, 문법 검사와 빌드 통과. 브라우저에서 원정 선택·시작·일시정지와 키보드 조작, 390×844/320×740 뷰포트를 확인했습니다. 보스 등장·처치 결과·시간 초과 화면은 시간을 제어한 별도 fixture로 검사했습니다. 실제 휴대폰 전체 런의 성능·조작감과 사람의 난이도 평가는 미검증입니다.

## 기획서 재생성

`docs/gdd/parts/*.json`이 구조화한 원본이고 `docs/gdd/build_pdf.py`가 Markdown과 PDF를 생성합니다. 문서 생성에 사용하는 Python의 reportlab은 게임 실행 의존성이 아닙니다. 현재 빌더의 한글 글꼴 기본 경로는 macOS AppleGothic입니다. 다른 운영체제에서는 빌더의 글꼴 경로를 설치된 한글 TrueType 글꼴로 맞춰야 합니다.

## 참고 자료와 에셋

[원작 Magic Survival / leme](https://play.google.com/store/apps/details?id=com.vkslrzm.Zombie)을 참고했습니다. [TomkoSK/magic-survival-builder](https://github.com/TomkoSK/magic-survival-builder)는 원작의 조합·연구·유물 **빌드 도구**이며 게임 엔진이 아닙니다. 이 프로젝트의 전투 코드는 별도로 작성했습니다.

`assets/catalog.json`은 위 저장소의 커밋 `d58d53117e6bead22ee08f0ecac7bff9658ae922`에서 확보한 이미지 265개와 폰트 1개의 출처·해시를 기록합니다. 확인한 업스트림에는 명시적 라이선스가 없으며, 이 저장소의 공개가 해당 자료의 자유 이용 허가를 뜻하지 않습니다. 배포용 신규 아트는 기획안의 제작 기준에 따라 독자적으로 만들고 출처·제작 이력을 남깁니다. 이 프로젝트에 포괄적인 오픈소스 라이선스는 아직 부여하지 않았습니다.
