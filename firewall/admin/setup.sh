#!/bin/sh
set -eu

# 담당: 정서윤
# 환경변수: ADMIN_IP, ADMIN_USERNAME, ADMIN_PASSWORD
# 체인: TEAM_INPUT (filter)
# TODO: 관리자 계정 생성·비어 있지 않은 실습용 비밀번호 설정
# TODO: ID/PW 인증·root 로그인 제한 등 sshd 설정
# TODO: 런타임 ssh-keygen -A 및 /run/sshd 준비
# TODO: ADMIN_IP에서 방화벽 TCP 22로 오는 접속만 TEAM_INPUT에서 허용
# TODO: sshd 시작 후 이 스크립트는 반환
# 비밀번호를 로그에 출력하거나 소스에 하드코딩하지 않습니다.

echo "[TODO 04] Admin account, IP allowlist and SSH service are not implemented."
