# The lab box: the LinuxServer OpenSSH server image plus the handful of
# command-line tools the lessons use (redis for its redis-cli, from stage-2).
FROM lscr.io/linuxserver/openssh-server:version-10.3_p1-r1

RUN apk add --no-cache \
      openssl \
      git \
      postgresql17-client \
      procps \
      redis
