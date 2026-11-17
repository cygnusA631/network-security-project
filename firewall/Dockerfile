FROM ubuntu:24.04

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       iptables iproute2 openssh-server ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /etc/ssh/ssh_host_*

WORKDIR /opt/firewall
COPY entrypoint.sh ./entrypoint.sh
COPY policy/ ./policy/
COPY admin/ ./admin/
RUN chmod +x ./entrypoint.sh ./policy/apply.sh ./admin/setup.sh

ENTRYPOINT ["/opt/firewall/entrypoint.sh"]
