#!/bin/sh
# 실행: 프로젝트 루트에서 sh tests/run-integration.sh
set -eu
cd "$(dirname "$0")/.."
docker info >/dev/null
docker compose config --quiet
# Compose v5가 Bake를 호출하며 로컬 폴더 읽기 권한을 요구하는 환경을 피합니다.
docker build -t network-security-project-firewall ./firewall
docker build -t network-security-project-web ./web
docker build -t network-security-project-client-admin -f infra/client.Dockerfile ./infra
docker build -t network-security-project-client-guest -f infra/client.Dockerfile ./infra
docker compose up -d --no-build --wait --wait-timeout 90

failed=0
pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1"; failed=$((failed + 1)); }

# 비밀번호 등 컨테이너 환경변수는 출력하지 않습니다.
if ! docker compose exec -T firewall sh -c 'test -n "$ADMIN_PASSWORD"'; then
    echo 'ADMIN_PASSWORD 또는 방화벽 기동 상태를 확인하세요.'
    exit 1
fi
if docker compose exec -T web wget -qO- http://127.0.0.1/ | grep -q '웹서버 접속 성공'; then
    pass '웹서버 자체 HTTP 응답'
else
    fail '웹서버 자체 HTTP 응답'
fi
for client in client-admin client-guest; do
    if docker compose exec -T "$client" sh -c 'curl -fsS --connect-timeout 3 --max-time 5 "http://$FW_EXTERNAL_IP/"' | grep -q '웹서버 접속 성공'; then
        pass "$client 방화벽 경유 HTTP"
    else
        fail "$client 방화벽 경유 HTTP"
    fi
done

input_drops() {
    docker compose exec -T firewall iptables -nvxL INPUT | awk '/^Chain INPUT / {print $5}'
}
for port in 22 443; do
    before=$(input_drops)
    if docker compose exec -T client-guest sh -c 'nc -vz -w 3 "$FW_EXTERNAL_IP" "$1"' sh "$port"; then
        fail "비인가 클라이언트 TCP $port 접속이 허용됨"
    else
        after=$(input_drops)
        if [ "$after" -gt "$before" ]; then
            pass "비인가 클라이언트 TCP $port 실패 + INPUT DROP 증가 ($before -> $after)"
        else
            fail "TCP $port 실패했지만 INPUT 차단 증거 없음"
        fi
    fi
done
before=$(input_drops)
docker compose exec -T client-guest sh -c 'printf "udp-test\n" | nc -u -w 1 "$FW_EXTERNAL_IP" 9999' || true
after=$(input_drops)
if [ "$after" -gt "$before" ]; then
    pass "UDP 9999 INPUT DROP 증가 ($before -> $after)"
else
    fail 'UDP INPUT 차단 카운터 증가 없음'
fi
if docker compose exec -T client-admin sh -c 'nc -vz -w 3 "$FW_EXTERNAL_IP" 22'; then
    pass '관리자 IP에서 SSH 포트 연결 (인증 검증은 별도)'
else
    fail '관리자 IP에서 SSH 포트 연결'
fi
if docker compose exec -T firewall sshd -T | grep -qx 'permitrootlogin no'; then
    pass 'root SSH 로그인 금지 설정 (실제 로그인 시도는 별도)'
else
    fail 'root SSH 로그인 금지 설정'
fi
docker compose ps
docker compose exec -T firewall iptables -nvxL
docker compose exec -T firewall iptables -t nat -nvxL
printf '\n자동 검사 실패: %s\n' "$failed"
echo '남은 검사: 올바른/잘못된 비밀번호 인증, 실제 root 로그인 거부, FORWARD 비허용 트래픽, 내부망 우회, 재생성 후 재검사.'
echo '이 스크립트는 컨테이너를 실행 상태로 둡니다. 확인 후 docker compose stop으로 종료하세요.'
[ "$failed" -eq 0 ]
