# The lab box: the LinuxServer OpenSSH server image plus the handful of
# command-line tools the lessons use (redis for its redis-cli, from stage-2).
FROM lscr.io/linuxserver/openssh-server:version-10.3_p1-r1@sha256:46f115de7c251558297e7e87566fc3fc08544b63e55502b5cf294454db5d29d1

RUN apk add --no-cache \
      openssl \
      git \
      postgresql17-client \
      procps \
      redis
