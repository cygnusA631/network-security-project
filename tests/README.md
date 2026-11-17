# 테스트·증빙 — 정서윤 중심, 담당자별 확인

아래는 **구현 후 확인할 목표**이며 통과 기록이 아닙니다. 기본 틀에는 HTTP 포워딩과 관리자 로그인이 없습니다.

| 항목 | 완료 시 기대 결과 | 상태 |
| --- | --- | --- |
| 웹서버 자체 기동 | web 내부에서 HTML 응답 | 확인 필요 |
| HTTP 허용 | 두 클라이언트 모두 방화벽 경유 HTML 응답 | TODO |
| 다른 TCP·UDP 등 차단 | 차단 + 대응 규칙/정책 카운터 증가 | TODO |
| 관리자 정상 로그인 | client-admin에서 올바른 ID/PW 성공 | TODO |
| 비밀번호 오류 | client-admin에서 잘못된 ID/PW 실패 | TODO |
| 비인가 IP | client-guest에서 SSH 접속 차단 | TODO |
| 내부망 우회 방지 | client-guest의 웹서버 IP 직접 접속 실패 | TODO |
| 재생성 후 재현 | down 후 up --build로 위 결과 동일 | TODO |

## 명령 예시

루트에서 실행합니다. IP는 기본 `.env.example` 기준입니다.

```sh
# 웹서버 자체 기동 (방화벽 검증 아님)
docker compose exec web wget -qO- http://127.0.0.1/

# 방화벽 경유 HTTP (정책 구현 전에는 실패)
docker compose exec client-admin curl --connect-timeout 3 --max-time 5 http://172.30.10.254/
docker compose exec client-guest curl --connect-timeout 3 --max-time 5 http://172.30.10.254/

# SSH (관리 기능 구현 후; 비밀번호는 프롬프트에서 입력)
docker compose exec client-admin ssh -o ConnectTimeout=3 labadmin@172.30.10.254
docker compose exec client-guest ssh -o ConnectTimeout=3 labadmin@172.30.10.254

# 비허용 TCP 포트
docker compose exec client-guest nc -vz -w 3 172.30.10.254 443

# UDP 패킷 전송 후 방화벽 카운터 확인
docker compose exec client-guest sh -c 'printf "udp-test\n" | nc -u -w 1 172.30.10.254 9999'

# 내부망 직접 접근 시도
docker compose exec client-guest curl --connect-timeout 3 --max-time 5 http://172.30.20.10/

# 시도 전후 카운터 비교
docker compose exec firewall iptables -nvL
docker compose exec firewall iptables -t nat -nvL
```

## 판정할 때 주의

- 접속 실패만으로 차단을 증명할 수 없습니다. 서비스 미실행·라우팅 오류도 실패를 만듭니다.
- UDP는 `nc` 결과만으로 판정하지 않고 패킷 카운터나 로그를 함께 확인합니다.
- 방화벽 IP:443 실패는 INPUT 확인입니다. **웹서버로 전달되는 비허용 트래픽의 FORWARD 차단과 구분**하고, 해당 경로에 실제 패킷이 들어왔는지 별도로 확인합니다.
- 몇 개 포트 테스트와 전체 기본 DROP 규칙을 함께 제시합니다. 모든 포트를 개별 검사했다고 쓰지 않습니다.
- `docker compose exec firewall sh`는 운영자 디버깅이며 ID/PW 인증을 검증하는 SSH 접속을 대체하지 않습니다.

`evidence/`에 캡처·실제 결과·명령·촬영 날짜를 기록합니다. 비밀번호와 개인정보는 가리고 전달하세요.
