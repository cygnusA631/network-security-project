#!/bin/sh
set -eu

# 담당: 임수영
# 환경변수: FW_EXTERNAL_IP, FW_INTERNAL_IP, WEB_IP
# 체인: TEAM_FORWARD (filter), TEAM_PREROUTING / TEAM_POSTROUTING (nat)
# 방화벽 외부 IP의 HTTP만 웹서버로 전달하고 응답 경로를 확보합니다.
# 나머지는 공통 FORWARD 기본 DROP을 유지합니다.
# 전체 iptables 초기화·기본 정책 변경은 하지 않습니다.

iptables -t nat -A TEAM_PREROUTING -p tcp -d "$FW_EXTERNAL_IP" --dport 80 -j DNAT --to-destination "$WEB_IP:80"
iptables -A TEAM_FORWARD -p tcp -d "$WEB_IP" --dport 80 -m conntrack --ctstate NEW -j ACCEPT
iptables -t nat -A TEAM_POSTROUTING -p tcp -d "$WEB_IP" --dport 80 -j SNAT --to-source "$FW_INTERNAL_IP"
