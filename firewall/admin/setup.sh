#!/bin/sh
set -eu

# 담당: 정서윤
# 환경변수: ADMIN_IP, ADMIN_USERNAME, ADMIN_PASSWORD
# 체인: TEAM_INPUT (filter)
# 관리자 계정과 비밀번호, SSH 서비스, IP 허용 규칙을 설정합니다.
# 비밀번호를 로그에 출력하거나 소스에 하드코딩하지 않습니다.

ADMIN_USERNAME="${ADMIN_USERNAME:-labadmin}"
if [ -z "${ADMIN_PASSWORD:-}" ]; then
    echo "ERROR: ADMIN_PASSWORD is empty." >&2
    exit 1
fi
if [ -z "${ADMIN_IP:-}" ]; then
    echo "ERROR: ADMIN_IP is empty." >&2
    exit 1
fi
if ! id "$ADMIN_USERNAME" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$ADMIN_USERNAME"
fi
echo "$ADMIN_USERNAME:$ADMIN_PASSWORD" | chpasswd
mkdir -p /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/99-admin.conf <<EOF
PasswordAuthentication yes
PermitRootLogin no
EOF
ssh-keygen -A
mkdir -p /run/sshd
iptables -C TEAM_INPUT -p tcp -s "$ADMIN_IP" --dport 22 -j ACCEPT 2>/dev/null || \
    iptables -I TEAM_INPUT 1 -p tcp -s "$ADMIN_IP" --dport 22 -j ACCEPT
/usr/sbin/sshd -t
/usr/sbin/sshd
echo "Admin account, IP allowlist and SSH service configured."
