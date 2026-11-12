# The lab box: the LinuxServer OpenSSH server image plus the handful of
# command-line tools the lessons use (redis for its redis-cli, from stage-2).
FROM lscr.io/linuxserver/openssh-server:version-10.3_p1-r1@sha256:b07414bb329b86a00525c9256711a7855fc3a369e9f62c36f1de8d1923197580

RUN apk add --no-cache \
      openssl \
      git \
      postgresql17-client \
      procps \
      redis
