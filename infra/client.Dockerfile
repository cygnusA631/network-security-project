FROM alpine:3.22

# 두 테스트 클라이언트는 같은 이미지, 다른 IP를 사용합니다.
RUN apk add --no-cache curl openssh-client iproute2 netcat-openbsd

CMD ["sleep", "infinity"]
