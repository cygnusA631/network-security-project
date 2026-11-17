# 트래픽 정책 — 임수영

`apply.sh`의 TODO를 구현합니다. 공통 체인이 생성된 뒤 시작 시 한 번 호출됩니다.

1. `$FW_EXTERNAL_IP`의 TCP 80 요청을 `$WEB_IP:80`으로 DNAT합니다.
2. `TEAM_FORWARD`에서 해당 HTTP 전달을 허용합니다.
3. 웹서버 응답이 방화벽으로 돌아오도록 합니다. 기본 게이트웨이는 방화벽이 아니므로 필요한 범위의 SNAT 또는 반환 경로가 필요합니다.
4. 다른 새 전달 트래픽은 기본 DROP을 유지합니다. 허용된 연결의 응답은 공통 스크립트가 처리합니다.

체인: filter의 `TEAM_FORWARD`, nat의 `TEAM_PREROUTING`·`TEAM_POSTROUTING`.

관리자·일반 클라이언트 모두 HTTP 성공, 비허용 트래픽 차단, 응답 반환, 재생성 후 정책 재적용을 확인합니다. 실패 화면만으로 차단을 판정하지 말고 규칙·패킷 카운터도 확인합니다.

전체 규칙 초기화와 SSH 설정은 수정하지 않습니다. 규칙 재적용은 루트에서 `docker compose up -d --build --force-recreate firewall`로 확인할 수 있습니다.
