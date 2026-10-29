# Magic Survival 원작 이미지 수집

2026-10-29. 제공된 GitHub 이미지265개에 신규 원작/공개 참조 이미지199개를 더해 총464개를 확보했다. `candidates.json`의201개 고유 URL을 모두 내려받아 검사했고, 동일 해시2건은 다시 저장하지 않았다. 다운로드 실패0건. 이는 확인한 공개 목록 기준이며 게임 전체의 내부 원본 파일을 확보했다는 뜻은 아니다.

## 구성

- 구역15종의 선택 화면과 비교 이미지1장: 배열지, 실험실, 하수도, 교외, 수목원, 아카데미, 발전소, 배양실, 저수지, 삼림, 도시, 가상 생태계, 심층, 테라, 테라 하드.
- 실험체24종의30×40 참조 이미지, 클래스24종의40×40 아이콘.
- 적4종·보스4종: 스웜, 엘리트, 서번트, 슈퍼 엘리트, 시타델, 네메시스, 아포슬, 아마데우스.
- 필드 아이템20장, 시너지35장, 추가 패시브25장·연구20장, 공식 스토어와 UI/선택 화면 등.
- 기존 GitHub의 마법58·유물153·패시브30·연구20·UI4개도 유지한다.

## 열기

저장소 루트의 `atlas.html`에서 분류·검색과 이미지/출처 열기를 지원한다. ZIP을 받았으면 압축을 풀고 같은 파일을 열면 된다. 외부 원문 링크만 인터넷이 필요하다. 파일명은 URL 해시로 보관하고 도감 이름은 출처 원어·영어·한국어 번역명을 분리한다. 번역명은 공식 한국어 표기 검수 완료를 뜻하지 않는다.

## 출처와 원본

- 최초 제공 자료: https://github.com/TomkoSK/magic-survival-builder/tree/d58d53117e6bead22ee08f0ecac7bff9658ae922
- 구역 자료: https://w.atwiki.jp/magicsurvival/list?pp=3
- 실험체: https://w.atwiki.jp/magicsurvival/pages/195.html
- 클래스: https://w.atwiki.jp/magicsurvival/pages/8.html
- 적·보스·필드/UI: https://w.atwiki.jp/magicsurvival/pages/53.html
- 패시브: https://w.atwiki.jp/magicsurvival/pages/15.html
- 연구: https://w.atwiki.jp/magicsurvival/pages/47.html
- 시너지: https://w.atwiki.jp/magicsurvival/pages/34.html
- 공식 스토어: https://play.google.com/store/apps/details?id=com.vkslrzm.Zombie

`catalog.json`은 실제 보관 경로, 원문 페이지, 직접 이미지 주소, SHA-256, 크기, 종류를 기록한다. 원본 이미지 바이트는 수정하지 않았다. 동일 해시의 다른 출처는 duplicates에 남긴다. 기존 제공 파일의 장부는 상위 `assets/catalog.json`이다. 필수 파이썬 이미지 검사는 이 호스트에 이미 있는 Pillow를 사용하며 게임의 런타임 의존성이 아니다.

구역 화면에는 실제 이용자의 UI·기록·자원이 포함돼 있다. 이 값은 이 프로젝트의 플레이 기록이나 플레이 가능한 새 맵으로 표시하지 않는다. 배경 타일, 캐릭터의 투명 애니메이션 시트, 보스 패턴 데이터는 별도로 만들어야 한다. 특히 적·보스 이미지는 배경/HP가 포함된 화면 일부다. 팬 위키는2025~2026년 자료를 포함하며 최신 패치와 차이가 있을 수 있다.

Fandom 일부 페이지는 접근 제한, 다른 사이트의 추가 이미지 CDN은503으로 파일을 얻지 못했다. 우회 없이 접근 가능한 다른 공개 출처를 사용했다. 확보 사실은 해당 게임 이미지의 저작권 양도나 상용 재배포 허가를 뜻하지 않으며 기존 출처 고지를 유지한다.

## 재수집

저장소 루트에서 `python3 scripts/collect-reference-assets.py` → `node build-atlas.mjs` → `python3 scripts/package-reference-assets.py` 순서로 실행한다. 수집기는 확인한 공개 CDN 두 곳만 사용하고 파일 형식·실제 이미지 전체 디코딩·크기·해시를 검사한다. 실패가 있으면 종료코드1과 별도 보고서를 남기고 이전 완성 카탈로그를 유지한다. 성공할 때만 카탈로그를 원자적으로 교체한다. 게임 앱에는 `godot/assets`의 실제 사용 자산만 포함되며 이 참조 모음 전체를 APK에 넣지 않는다.
