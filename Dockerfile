FROM ubuntu:20.04
MAINTAINER GitLab Inc. <support@gitlab.com>

ARG VERSION=14.8.2
ARG EDITION=ee
ARG BASE_URL=https://packages.gitlab.com/gitlab/gitlab-${EDITION}/packages/ubuntu/focal/

SHELL ["/bin/sh", "-c"]

# Default to supporting utf-8
ENV LANG=C.UTF-8

# Install required packages
RUN apt-get update -q \
    && DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \
      busybox \
      ca-certificates \
      openssh-server \
      tzdata \
      wget \
    && rm -rf /var/lib/apt/lists/*

# Use BusyBox
ENV EDITOR /bin/vi
RUN busybox --install \
    && { \
        echo '#!/bin/sh'; \
        echo '/bin/vi "$@"'; \
    } > /usr/local/bin/busybox-editor \
    && chmod +x /usr/local/bin/busybox-editor \
    && update-alternatives --install /usr/bin/editor editor /usr/local/bin/busybox-editor 1

# Remove MOTD
RUN rm -rf /etc/update-motd.d /etc/motd /etc/motd.dynamic
RUN ln -fs /dev/null /run/motd.dynamic

RUN echo "RELEASE_PACKAGE=gitlab-${EDITION}" > /RELEASE && \
    echo "RELEASE_VERSION=${VERSION}-${EDITION}.0" >> /RELEASE && \
    echo "DOWNLOAD_URL=$BASE_URL/gitlab-${EDITION}_${VERSION}-${EDITION}.0_arm64.deb/download.deb" >> /RELEASE
# Copy assets
COPY assets/ /assets/

# as gitlab-ci checks out with mode 666 we need to set permissions of the files we copied into the
# container to a secure value. Issue #5956
RUN chmod -R og-w /assets RELEASE ; \
  /assets/setup

# Allow to access embedded tools
ENV PATH /opt/gitlab/embedded/bin:/opt/gitlab/bin:/assets:$PATH

# Resolve error: TERM environment variable not set.
ENV TERM xterm

# Expose web & ssh
EXPOSE 443 80 22

# Define data volumes
VOLUME ["/etc/gitlab", "/var/opt/gitlab", "/var/log/gitlab"]

# Wrapper to handle signal, trigger runit and reconfigure GitLab
CMD ["/assets/wrapper"]

HEALTHCHECK --interval=60s --timeout=30s --retries=5 \
CMD /opt/gitlab/bin/gitlab-healthcheck --fail --max-time 10
