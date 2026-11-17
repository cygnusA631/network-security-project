# 웹서버 — 길경은

공식 Nginx 이미지와 최소 페이지가 들어 있습니다. 확인용 HTML과 필요한 웹서버 설정을 담당합니다.

- `html/index.html`: 팀명·프로젝트 소개·접속 성공 메시지 등
- `default.conf`: Nginx 설정. 서비스 포트는 **80** 유지
- `Dockerfile`: 웹서버 이미지 구성

루트에서 `docker compose up -d --build web`로 변경을 반영하고 `docker compose exec web wget -qO- http://127.0.0.1/`로 확인합니다.

웹서버에 `ports:`를 추가하면 방화벽을 우회할 수 있으므로 공통 Compose는 임의로 수정하지 않습니다. DB·로그인 페이지·별도 프레임워크는 만들지 않습니다.
