#!/bin/sh
set -eu

# 전용 방화벽 컨테이너에서만 실행합니다. 호스트에서 직접 실행하지 않습니다.
if [ ! -f /.dockerenv ]; then
    echo "ERROR: run only inside the firewall Docker container." >&2
    exit 1
fi

echo "[init] Preparing isolated firewall rules."

# 공통 초기화는 이 파일에서만 합니다. Docker의 DNS용 NAT 규칙은 보존합니다.
iptables -w -P INPUT DROP
iptables -w -P FORWARD DROP
iptables -w -P OUTPUT ACCEPT

# 재시작 시에도 프로젝트가 소유한 체인만 초기화합니다.
reset_chain() {
    iptables -w -t "$1" -N "$2" 2>/dev/null || iptables -w -t "$1" -F "$2"
}

# 공통 연결 규칙을 중복 추가하지 않습니다.
ensure_rule() {
    table="$1"
    chain="$2"
    shift 2
    iptables -w -t "$table" -C "$chain" "$@" 2>/dev/null || \
        iptables -w -t "$table" -A "$chain" "$@"
}

reset_chain filter TEAM_INPUT
reset_chain filter TEAM_FORWARD
reset_chain nat TEAM_PREROUTING
reset_chain nat TEAM_POSTROUTING

ensure_rule filter INPUT -i lo -j ACCEPT
ensure_rule filter INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
ensure_rule filter INPUT -j TEAM_INPUT
ensure_rule filter FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
ensure_rule filter FORWARD -j TEAM_FORWARD
ensure_rule nat PREROUTING -j TEAM_PREROUTING
ensure_rule nat POSTROUTING -j TEAM_POSTROUTING

/bin/sh /opt/firewall/policy/apply.sh
/bin/sh /opt/firewall/admin/setup.sh

echo "[ready] Firewall policy and admin setup completed."
exec sleep infinity
