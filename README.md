# Magic Survival Lab

매직 서바이벌에서 영감을 받은 HTML/Canvas 생존 게임 실험 프로젝트입니다. 이동·자동 공격·레벨업·마법 조합·유물을 연결한 5분 시제품이 있으며, 다음 버전의 기획은 별도 문서로 관리합니다.

- **[확장 기획안: 균열 원정](docs/superpowers/specs/2026-10-29-expansion-design.md)** — 원작 조사, 현재 구현, 보스·맵 변이·조합 공명, 단계별 제작과 이미지 생성 계획
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

현재는 5분 생존, 마법 8종, 조합 4종, 유물 12종, 일반·고속·정예 적, 최고 기록 저장을 구현했습니다. 보스, 선택 가능한 맵, 연구·클래스, 10~15분 원정, 공명은 **기획 단계**입니다. 도감에 이미지가 있다고 해당 전투 기능이 구현된 것은 아닙니다.

2026-10-29 검증: 테스트 25/25, 문법 검사와 빌드 통과. 실제 휴대폰 전체 런의 성능·조작감과 사람의 난이도 평가는 별도 검증 대상입니다.

## 참고 자료와 에셋

[원작 Magic Survival / leme](https://play.google.com/store/apps/details?id=com.vkslrzm.Zombie)을 참고했습니다. [TomkoSK/magic-survival-builder](https://github.com/TomkoSK/magic-survival-builder)는 원작의 조합·연구·유물 **빌드 도구**이며 게임 엔진이 아닙니다. 이 프로젝트의 전투 코드는 별도로 작성했습니다.

`assets/catalog.json`은 위 저장소의 커밋 `d58d53117e6bead22ee08f0ecac7bff9658ae922`에서 확보한 이미지 265개와 폰트 1개의 출처·해시를 기록합니다. 확인한 업스트림에는 명시적 라이선스가 없으며, 이 저장소의 공개가 해당 자료의 자유 이용 허가를 뜻하지 않습니다. 배포용 신규 아트는 기획안의 제작 기준에 따라 독자적으로 만들고 출처·제작 이력을 남깁니다. 이 프로젝트에 포괄적인 오픈소스 라이선스는 아직 부여하지 않았습니다.
