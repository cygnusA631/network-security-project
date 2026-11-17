#!/bin/sh
set -eu

# 담당: 임수영
# 환경변수: FW_EXTERNAL_IP, FW_INTERNAL_IP, WEB_IP
# 체인: TEAM_FORWARD (filter), TEAM_PREROUTING / TEAM_POSTROUTING (nat)
# TODO: 방화벽 외부 IP의 TCP 80 요청을 WEB_IP:80으로 전달합니다.
# TODO: HTTP 전달을 허용하고 응답 경로(SNAT 또는 라우팅)를 구성합니다.
# 나머지는 공통 FORWARD 기본 DROP을 유지합니다.
# 전체 iptables 초기화·기본 정책 변경은 하지 않습니다.

echo "[TODO 03] HTTP forwarding and service policy are not implemented."
