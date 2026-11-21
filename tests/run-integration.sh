#!/bin/sh
# 실행: 프로젝트 루트에서 sh tests/run-integration.sh [--recreate]
set -eu
cd "$(dirname "$0")/.."

recreate=0
case "${1:-}" in
    '') ;;
    --recreate) recreate=1; shift ;;
    --help|-h)
        echo '사용법: sh tests/run-integration.sh [--recreate]'
        echo '--recreate: 첫 검사 후 down/up으로 컨테이너·네트워크를 재생성하고 전체 재검사'
        exit 0
        ;;
    *) echo '사용법: sh tests/run-integration.sh [--recreate]' >&2; exit 2 ;;
esac
[ "$#" -eq 0 ] || { echo '지원하지 않는 추가 인자가 있습니다.' >&2; exit 2; }

passed=0
failed=0
route_added=0
ssh_tmp=''
web_ip=''
fw_external_ip=''
pass() { printf 'PASS: %s\n' "$1"; passed=$((passed + 1)); }
fail() { printf 'FAIL: %s\n' "$1"; failed=$((failed + 1)); }
die() { printf 'ERROR: %s\n' "$1" >&2; exit 1; }

# 원래 있던 경로는 덮어쓰지 않으며, 이 실행이 추가한 경로만 제거합니다.
cleanup_phase() {
    cleanup_failed=0
    if [ "$route_added" -eq 1 ]; then
        if docker compose exec -T --privileged client-guest \
            ip -4 route del "$web_ip/32" via "$fw_external_ip" >/dev/null 2>&1; then
            route_added=0
        else
            echo 'ERROR: 테스트용 guest 경로 정리에 실패했습니다.' >&2
            cleanup_failed=1
        fi
    fi
    if [ -n "$ssh_tmp" ]; then
        if docker compose exec -T client-admin rm -rf "$ssh_tmp" >/dev/null 2>&1; then
            ssh_tmp=''
        else
            echo 'ERROR: 테스트용 SSH 호스트키 파일 정리에 실패했습니다.' >&2
            cleanup_failed=1
        fi
    fi
    return "$cleanup_failed"
}
cleanup() {
    final_status=$?
    trap - 0 1 2 15
    if ! cleanup_phase; then final_status=1; fi
    exit "$final_status"
}
trap cleanup 0
trap 'exit 129' 1
trap 'exit 130' 2
trap 'exit 143' 15

docker info >/dev/null
docker compose config --quiet
TZ=Asia/Seoul date '+실행 시각 (KST): %Y-%m-%d %H:%M:%S'
# Compose v5가 Bake를 호출하며 로컬 폴더 읽기 권한을 요구하는 환경을 피합니다.
docker build -t network-security-project-firewall ./firewall
docker build -t network-security-project-web ./web
docker build -t network-security-project-client-admin -f infra/client.Dockerfile ./infra
docker tag network-security-project-client-admin network-security-project-client-guest
docker compose up -d --no-build --wait --wait-timeout 90

chain_drops() {
    drop_count=$(docker compose exec -T firewall iptables -nvxL "$1" | \
        awk -v chain="$1" '$1 == "Chain" && $2 == chain && $3 == "(policy" && $4 == "DROP" {print $5}')
    case "$drop_count" in
        ''|*[!0-9]*) die "$1 기본 DROP 카운터를 읽을 수 없습니다." ;;
    esac
    printf '%s\n' "$drop_count"
}

check_tcp_drop() {
    check_chain=$1
    check_target=$2
    check_port=$3
    check_label=$4
    before=$(chain_drops "$check_chain")
    if docker compose exec -T client-guest nc -vz -w 3 "$check_target" "$check_port" >/dev/null 2>&1; then
        fail "$check_label 접속이 허용됨"
    else
        after=$(chain_drops "$check_chain")
        if [ "$after" -gt "$before" ]; then
            pass "$check_label 실패 + $check_chain DROP 증가 ($before -> $after)"
        else
            fail "$check_label 실패했지만 $check_chain 차단 증거 없음"
        fi
    fi
}

check_udp_drop() {
    check_chain=$1
    check_target=$2
    before=$(chain_drops "$check_chain")
    # UDP nc의 성공 여부는 판정에 사용하지 않습니다.
    docker compose exec -T client-guest sh -c \
        'printf "udp-test\n" | nc -u -w 1 "$1" 9999' sh "$check_target" >/dev/null 2>&1 || true
    after=$(chain_drops "$check_chain")
    if [ "$after" -gt "$before" ]; then
        pass "UDP 9999 $check_chain DROP 증가 ($before -> $after)"
    else
        fail "UDP 9999 $check_chain 차단 카운터 증가 없음"
    fi
}

prepare_ssh() {
    ssh_tmp=$(docker compose exec -T client-admin mktemp -d /tmp/network-project-tests.XXXXXX)
    case "$ssh_tmp" in
        /tmp/network-project-tests.*) ;;
        *) die '테스트용 SSH 임시 폴더 생성에 실패했습니다.' ;;
    esac
    # 신뢰할 수 있는 Docker 제어 경로로 실제 공개키를 읽어 고정합니다.
    # 호스트키 검증은 유지하며 재생성 시 새 공개키로 테스트 파일만 갱신합니다.
    if ! docker compose exec -T firewall sh -c '
        set -eu
        read -r key_type key_data ignored < /etc/ssh/ssh_host_ed25519_key.pub
        test "$key_type" = ssh-ed25519
        test -n "$key_data"
        printf "%s %s %s\n" "$FW_EXTERNAL_IP" "$key_type" "$key_data"
    ' | docker compose exec -T client-admin sh -c '
        set -eu
        umask 077
        cat > "$1/known_hosts"
        test -s "$1/known_hosts"
    ' sh "$ssh_tmp"; then
        die '실제 SSH 공개키 고정에 실패했습니다.'
    fi
    invalid_username="network-missing-$$"
    if docker compose exec -T firewall id "$invalid_username" >/dev/null 2>&1; then
        die '오류 ID 검사에 사용할 계정이 이미 존재합니다.'
    fi
}

ssh_auth() {
    # 비밀번호를 호스트 변수·인자·파일·로그에 넣지 않고 stdin 파이프로 전달합니다.
    docker compose exec -T firewall sh -c '
        case "$1" in
            valid) printf "%s\n" "$ADMIN_PASSWORD" ;;
            wrong) printf "invalid-%s\n" "$ADMIN_PASSWORD" ;;
            *) exit 2 ;;
        esac
    ' sh "$1" | docker compose exec -T client-admin sh -c '
        export LC_ALL=C
        exec sshpass -d 0 ssh -T -F /dev/null \
            -o StrictHostKeyChecking=yes \
            -o UserKnownHostsFile="$2/known_hosts" \
            -o GlobalKnownHostsFile=/dev/null \
            -o HostKeyAlgorithms=ssh-ed25519 \
            -o PreferredAuthentications=password \
            -o PubkeyAuthentication=no \
            -o KbdInteractiveAuthentication=no \
            -o NumberOfPasswordPrompts=1 \
            -o ConnectionAttempts=1 -o ConnectTimeout=3 -o LogLevel=ERROR \
            -l "$1" "$FW_EXTERNAL_IP" id -un
    ' sh "$2" "$ssh_tmp" 2>&1
}

check_auth_denied() {
    if auth_output=$(ssh_auth "$1" "$2" 2>&1); then
        fail "$3 인증이 허용됨"
    elif printf '%s\n' "$auth_output" | grep -q 'Permission denied'; then
        pass "$3: SSH Permission denied 확인"
    else
        fail "$3: 인증 거부 응답을 확인하지 못함"
    fi
}

run_suite() {
    printf '\n=== %s ===\n' "$1"
    # firewall은 healthcheck가 없으므로 계정·키 초기화 완료를 짧게 기다립니다.
    ready_attempt=0
    until docker compose exec -T firewall sh -c \
        'test -n "$ADMIN_PASSWORD" && test -s /etc/ssh/ssh_host_ed25519_key.pub && /usr/sbin/sshd -t' >/dev/null 2>&1; do
        ready_attempt=$((ready_attempt + 1))
        [ "$ready_attempt" -lt 15 ] || die 'ADMIN_PASSWORD 또는 방화벽 초기화 상태를 확인하세요.'
        sleep 1
    done
    fw_external_ip=$(docker compose exec -T firewall sh -c 'printf "%s" "$FW_EXTERNAL_IP"')
    web_ip=$(docker compose exec -T firewall sh -c 'printf "%s" "$WEB_IP"')
    admin_username=$(docker compose exec -T firewall sh -c 'printf "%s" "$ADMIN_USERNAME"')

    if docker compose exec -T web wget -qO- http://127.0.0.1/ | grep -q '웹서버 접속 성공'; then
        pass '웹서버 자체 HTTP 응답'
    else
        fail '웹서버 자체 HTTP 응답'
    fi
    for client in client-admin client-guest; do
        if docker compose exec -T "$client" sh -c \
            'curl --noproxy "*" -fsS --connect-timeout 3 --max-time 5 "http://$FW_EXTERNAL_IP/"' | grep -q '웹서버 접속 성공'; then
            pass "$client 방화벽 경유 HTTP"
        else
            fail "$client 방화벽 경유 HTTP"
        fi
    done
    for chain in INPUT FORWARD; do
        if docker compose exec -T firewall iptables -S "$chain" | grep -qx -- "-P $chain DROP"; then
            pass "$chain 기본 DROP 정책"
        else
            fail "$chain 기본 DROP 정책"
        fi
    done
    for port in 22 443; do
        check_tcp_drop INPUT "$fw_external_ip" "$port" "비인가 클라이언트 TCP $port"
    done
    check_udp_drop INPUT "$fw_external_ip"
    if docker compose exec -T client-admin nc -vz -w 3 "$fw_external_ip" 22 >/dev/null 2>&1; then
        pass '관리자 IP에서 SSH 포트 연결 (인증은 아래 별도 검사)'
    else
        fail '관리자 IP에서 SSH 포트 연결'
    fi
    if docker compose exec -T firewall sshd -T | grep -qx 'permitrootlogin no'; then
        pass 'root SSH 로그인 금지 설정'
    else
        fail 'root SSH 로그인 금지 설정'
    fi
    prepare_ssh
    if auth_output=$(ssh_auth valid "$admin_username" 2>&1) && [ "$auth_output" = "$admin_username" ]; then
        pass '관리자 올바른 ID/PW SSH 로그인 + 원격 id 일치'
    else
        fail '관리자 올바른 ID/PW SSH 로그인 + 원격 id 일치'
    fi
    check_auth_denied wrong "$admin_username" '관리자 잘못된 비밀번호'
    check_auth_denied valid "$invalid_username" '존재하지 않는 사용자'
    check_auth_denied valid root 'root 로그인 시도 (관리자 비밀번호 사용; root 비밀번호 유효성 미검증)'

    if docker compose exec -T client-guest curl --noproxy '*' -fsS --connect-timeout 3 --max-time 5 \
        "http://$web_ip/" >/dev/null 2>&1; then
        fail '기본 클라이언트에서 내부 웹 IP 직접 HTTP 접근이 허용됨'
    else
        pass '기본 클라이언트에서 내부 웹 IP 직접 HTTP 접근 실패'
    fi

    existing_route=$(docker compose exec -T client-guest ip -4 route show exact "$web_ip/32")
    [ -z "$existing_route" ] || die '기존 guest 웹서버 경로가 있어 덮어쓰지 않고 중단합니다.'
    docker compose exec -T --privileged client-guest ip -4 route add "$web_ip/32" via "$fw_external_ip"
    route_added=1
    if docker compose exec -T client-guest sh -c \
        'curl --noproxy "*" -fsS --connect-timeout 3 --max-time 5 "http://$FW_EXTERNAL_IP/"' | grep -q '웹서버 접속 성공'; then
        pass '테스트 경로 추가 후 방화벽 외부 IP HTTP 대조 성공'
    else
        fail '테스트 경로 추가 후 방화벽 외부 IP HTTP 대조 실패'
    fi
    # /32 경로로 패킷이 방화벽 FORWARD에 도착하도록 하여 우회·타 포트 차단을 입증합니다.
    check_tcp_drop FORWARD "$web_ip" 80 '내부 웹 IP 직접 TCP 80 우회'
    check_tcp_drop FORWARD "$web_ip" 443 '내부 웹 IP TCP 443'
    check_udp_drop FORWARD "$web_ip"
    cleanup_phase || die '테스트용 임시 경로·파일을 정리하지 못했습니다.'
    docker compose ps
    docker compose exec -T firewall iptables -nvxL
    docker compose exec -T firewall iptables -t nat -nvxL
}

run_suite '최초 실행 검사'
if [ "$recreate" -eq 1 ]; then
    printf '\n컨테이너·네트워크를 down/up으로 재생성합니다.\n'
    docker compose down
    docker compose up -d --no-build --wait --wait-timeout 90
    run_suite '재생성 후 동일 검사'
fi
printf '\n자동 검사 통과: %s\n자동 검사 실패: %s\n' "$passed" "$failed"
if [ "$recreate" -eq 0 ]; then
    echo '재생성 검사는 --recreate 옵션으로 실행하세요.'
fi
echo '이 스크립트는 컨테이너를 실행 상태로 둡니다. 확인 후 docker compose stop으로 종료하세요.'
[ "$failed" -eq 0 ]
