# 🐳 Network Security Project

Docker 외부망·내부망을 분리하고 방화벽을 거쳐 웹서버에 접근하는 네트워크 보안 수업 과제입니다.

> **팀원 배포용 기본 틀입니다.** 컨테이너·네트워크·기본 웹페이지를 준비했습니다. HTTP 포워딩과 관리자 인증은 TODO이며, 초기 상태에서 방화벽 경유 HTTP·SSH 접속은 차단됩니다. 이를 과제 완성이나 보안 검증 완료로 판단하지 마세요.

## 역할과 수정 위치

| 담당 | 작업 위치 | 내용 |
| --- | --- | --- |
| 🐳 문가원 | `docker-compose.yml`, `infra/`, `firewall/Dockerfile`, `firewall/entrypoint.sh` | 네트워크·공통 실행 틀·전체 통합·GitHub 업로드 |
| 🦫 길경은 | `web/` | Nginx TCP 80·확인용 HTML |
| 🦊 임수영 | `firewall/policy/` | HTTP 포워딩·응답 경로·트래픽 차단 |
| 🐢 정서윤 | `firewall/admin/`, `tests/` | 관리자 IP 제한·SSH ID/PW 인증·테스트·증빙 |
| 🦜 이지민 | PPT·영상은 별도 전달 | 구성도·조건별 설명·시연·LMS 제출 |

3번과 4번은 **하나의 방화벽 컨테이너**에서 동작합니다. 공통 파일 변경이 필요하면 가원에게 알려 주세요.

## 처음 실행하기 — GitHub를 몰라도 됩니다

1. Docker Desktop을 설치하고 실행합니다. Windows에서는 **Linux 컨테이너**를 사용합니다.
2. [저장소](https://github.com/cygnusA631/network-security-project)의 **Code → Download ZIP** 또는 가원이 공유한 ZIP을 압축 해제합니다.
3. VS Code에서 **`docker-compose.yml`이 있는 폴더**를 열고 터미널을 엽니다.
4. 최초 한 번 설정 예시를 복사하고 실행합니다. 아래 명령은 macOS 터미널과 Windows PowerShell 모두에서 사용할 수 있습니다.

```sh
cp .env.example .env
docker compose config --quiet
docker compose up -d --build
docker compose ps
```

첫 실행은 이미지 다운로드로 인터넷이 필요합니다. `.env`는 로컬 설정이며 GitHub에 올리지 않습니다. 관리자 기능 구현 후 각자의 `.env`에 실습 전용 비밀번호를 설정합니다. 기본 틀에는 비밀번호가 없습니다.

### 기본 틀 확인

```sh
# 웹서버 자체 확인: HTML 응답이 나와야 합니다. 방화벽 통과 검증은 아닙니다.
docker compose exec web wget -qO- http://127.0.0.1/

# 서로 다른 클라이언트 IP 확인
docker compose exec client-admin ip -4 addr
docker compose exec client-guest ip -4 addr

# 방화벽 초기화·TODO·기본 차단 확인
docker compose logs firewall
docker compose exec firewall iptables -nvL
```

네 컨테이너가 실행되고 web이 healthy가 되는 것이 초기 목표입니다. **SSH 서버는 아직 시작되지 않습니다.**

### 수정 반영 / 종료

```sh
# 코드·설정·.env 변경 후 실행합니다. restart만으로는 변경이 반영되지 않습니다.
docker compose up -d --build

# 이 프로젝트의 컨테이너·네트워크 종료 및 제거
docker compose down
```

코드는 이미지에 복사됩니다. 컨테이너 안에서만 수정하지 말고 **담당 폴더의 파일**을 수정한 뒤 재빌드해 주세요.

## 공통 네트워크 약속

| 대상 | 외부 실습망 `172.30.10.0/24` | 내부 실습망 `172.30.20.0/24` |
| --- | --- | --- |
| firewall | `172.30.10.254` | `172.30.20.254` |
| web | 연결 안 함 | `172.30.20.10` |
| client-admin | `172.30.10.10` | 연결 안 함 |
| client-guest | `172.30.10.20` | 연결 안 함 |

- 외부망은 **Docker 내부의 모의 외부망**입니다. 팀원 PC끼리 연결하거나 인터넷에 공개하지 않습니다.
- 호스트에 공개하는 포트는 없습니다. 클라이언트는 방화벽 외부 IP:80에 접속합니다. 웹서버에 `ports:`를 추가하면 우회 경로가 생기므로 임의로 추가하지 않습니다.
- 각 Docker 브리지 게이트웨이는 `.1`, 방화벽은 `.254`입니다. 네트워크에 연결하는 것만으로 방화벽이 자동 경유지가 되지 않습니다.
- 3번은 DNAT·포워딩뿐 아니라 응답 경로도 구현합니다. 필요한 HTTP 트래픽만 방화벽 내부 IP로 SNAT하는 방법이 한 가지 선택입니다.
- 실습망은 IPv4입니다. 실제 외부 PC나 IPv6까지 요구하는 과제라면 별도 설계가 필요합니다.
- 방화벽은 자체 네트워크 공간에서 `NET_ADMIN` 권한과 IPv4 포워딩을 사용합니다. 호스트 네트워크를 공유하지 않습니다.
- 관리자 접속은 **방화벽 자체 TCP 22**, 웹 트래픽은 **웹서버로 전달되는 TCP 80**으로 분리하는 제안입니다. 과제 원문의 ‘80 외 모두 차단’이 관리 접속도 포함하는지 확인하세요.
- IP는 `.env.example` 초기값 기준입니다. 변경 시 가원과 협의해 대역·게이트웨이·컨테이너 IP를 함께 조정합니다.

## 방화벽 코드 연결

시작 순서: `entrypoint.sh` 공통 초기화 → `policy/apply.sh` 정책 → `admin/setup.sh` 관리자 설정.

| 담당 | 수정할 체인 |
| --- | --- |
| 수영 | filter의 `TEAM_FORWARD`, nat의 `TEAM_PREROUTING`·`TEAM_POSTROUTING` |
| 서윤 | filter의 `TEAM_INPUT` |

전체 초기화는 공통 스크립트 한 곳에서만 합니다. 각 담당 스크립트에서 전체 `iptables -F`, `iptables -X`, 기본 정책 변경을 하지 않습니다. 기본 틀은 loopback·이미 성립된 연결의 응답을 허용하고, 나머지 INPUT/FORWARD를 차단합니다. OUTPUT은 초기 틀에서 허용하며 최종 차단 범위는 통합 시 확인합니다.

기능별 안내: [웹서버](web/README.md) · [트래픽 정책](firewall/policy/README.md) · [관리자 접근통제](firewall/admin/README.md) · [테스트](tests/README.md).

## 코드 제출 — 브랜치·PR 사용 불필요

1. 받은 기본 틀에서 담당 폴더를 수정하고 재빌드해 확인합니다.
2. **담당 폴더 ZIP + 아래 메모 + 확인 캡처**를 가원에게 전달합니다.
3. 가원이 통합·커밋·GitHub 업로드 후 새 기본본을 공유합니다. 다음 작업은 최신 기본본에서 이어갑니다.

```text
담당자:
사용한 기본본 버전 또는 받은 날짜:
수정한 파일:
실행·확인 명령:
정상 동작한 부분:
아직 안 되는 부분:
공통 파일 변경이 필요한 부분:
```

`.env`, 실제 비밀번호, SSH 개인키는 보내거나 업로드하지 않습니다. 필요한 설정은 비밀번호를 지운 예시로 전달합니다. 중간 제출 한 번과 최종 제출 한 번을 권장합니다.

## 실행 문제

- **Docker daemon 연결 실패:** Docker Desktop을 실행하고 엔진 준비가 끝난 뒤 다시 시도합니다.
- **설정 변수 누락:** 루트에서 `.env.example`을 `.env`로 복사했는지 확인합니다.
- **네트워크 대역 충돌:** 다른 Docker 네트워크·VPN 대역을 확인하고 가원과 협의해 주소를 조정합니다.
- **줄바꿈·실행 권한 오류:** 스크립트는 LF를 사용합니다. 실행 권한은 Dockerfile에서 설정합니다.
- **방화벽 경유 HTTP·SSH 실패:** 현재 TODO 상태에서는 정상입니다. 구현 후 테스트 안내로 검증합니다.

## 초기 버전 검증 상태

- Compose 구성 파싱, IP 대역·중복, 웹서버 네트워크 분리, 셸 문법 검사를 통과했습니다.
- 실제 이미지 빌드·컨테이너 기동은 아직 검증하지 않았습니다. 작성 환경에서 Docker 소켓 접근 권한이 제한되어 있으므로, 첫 실행 시 위 기본 틀 확인 절차를 수행하세요.
- HTTP 정책과 관리자 인증은 담당자의 TODO이며, 기능 테스트와 캡처도 구현 후 진행합니다.

공식 참고: [Docker 브리지](https://docs.docker.com/engine/network/drivers/bridge/) · [Docker Desktop 네트워크](https://docs.docker.com/desktop/features/networking/networking-how-tos/).
