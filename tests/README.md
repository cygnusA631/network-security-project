# 테스트·증빙 — 정서윤 중심, 담당자별 확인

2026-11-21 macOS / Docker Linux ARM64 로컬 통합 검사에서 **38개 통과, 실패 0개**를 확인했습니다. 최초 19개 검사 후 컨테이너·네트워크를 `down` → `up --no-build`로 재생성하고 동일한 19개를 다시 통과했습니다. [실제 명령·결과·규칙 카운터](evidence/integration-2026-11-21.txt)를 증빙으로 저장했습니다.

## 자동 검사

루트 `.env`에 실습용 `ADMIN_PASSWORD`를 설정하고 Docker Desktop을 실행한 뒤 진행합니다.

```sh
# 빌드 후 전체 19개 검사
sh tests/run-integration.sh

# 컨테이너·네트워크를 재생성하고 동일 검사 반복 (총 38개)
sh tests/run-integration.sh --recreate > tests/integration-completion.log 2>&1
```

스크립트는 이미지를 먼저 빌드하고 `up --no-build`로 실행합니다. `--recreate`는 첫 검사 후 실제 `docker compose down` → `up -d --no-build --wait`를 수행하므로 이 프로젝트의 네 컨테이너가 잠시 종료됩니다. 검사 후에는 실행 상태로 둡니다. 실패 항목이 있거나 준비·정리가 실패하면 종료 코드가 0이 아닙니다.

검사 범위:

- 웹서버 자체 및 관리자·일반 클라이언트의 방화벽 경유 HTTP 응답
- INPUT·FORWARD 기본 DROP, 비인가 SSH/TCP 443 및 UDP 9999의 INPUT DROP 카운터 증가
- 관리자 SSH 포트, 실제 올바른 ID/PW 로그인과 원격 사용자 이름 일치
- 잘못된 비밀번호·존재하지 않는 ID의 `Permission denied`, root 로그인 금지 설정 및 실제 root 접속 시도의 거부 응답
- 기본 경로에서 웹서버 IP 직접 HTTP 접근 실패
- guest에 임시 `/32` 경로를 추가한 상태에서 정상 방화벽 HTTP 대조, 직접 웹 IP TCP 80·443와 UDP 9999의 FORWARD DROP 카운터 증가

임시 경로는 테스트 프로세스에서만 `docker compose exec --privileged`로 추가하며, 정상 종료·실패·종료 신호에서 제거합니다. 클라이언트의 기본 권한은 늘리지 않습니다. 기존에 같은 `/32` 경로가 있으면 덮어쓰지 않고 중단합니다.

SSH 검사는 클라이언트의 `sshpass`에 비밀번호를 stdin으로 전달합니다. 비밀번호를 명령 인자나 로그에 쓰지 않습니다. Docker 제어 경로로 읽은 방화벽의 실제 ed25519 공개키를 임시 known_hosts에 고정하고 `StrictHostKeyChecking=yes`로 검사합니다. 재생성 후에는 새 공개키를 읽고, 사용자 known_hosts는 수정하지 않습니다.

root 접속 시도에는 관리자 비밀번호를 사용합니다. root 비밀번호가 유효한지는 검사하지 않으므로, 이 결과를 “유효한 root 비밀번호까지 시험했다”고 해석하지 않습니다. `permitrootlogin no` 설정도 별도로 확인합니다.

## 명령 예시

루트에서 실행합니다. IP는 기본 `.env.example` 기준입니다.

```sh
# 웹서버 자체 기동 (방화벽 검증 아님)
docker compose exec web wget -qO- http://127.0.0.1/

# 방화벽 경유 HTTP
docker compose exec client-admin curl --connect-timeout 3 --max-time 5 http://172.30.10.254/
docker compose exec client-guest curl --connect-timeout 3 --max-time 5 http://172.30.10.254/

# SSH (비밀번호는 프롬프트에서 입력)
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

`evidence/`에 실제 결과·명령·날짜를 기록합니다. 전체 자동 검사 로그는 로컬 `integration-completion.log`에서 확인할 수 있으며 Git에서는 제외됩니다. 비밀번호와 개인정보는 가리고 전달하세요.
