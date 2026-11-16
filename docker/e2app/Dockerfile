# Stage 1: Dependencies (cached separately)
FROM ubuntu:26.04 AS deps

ARG ARCH=x64
# Single source of truth for the Node version is /.nvmrc; keep this default in sync with it.
# buildspec.yml + devbuild.sh pass --build-arg NODE_VERSION="$(cat .nvmrc)" so the CodeBuild
# host toolchain and this image always match. Node 24 is Active LTS (Krypton) and ships a
# current npm (11.x) in-box -- no separate `npm install -g` step to float-break (#4488, was #4486).
ARG NODE_VERSION=24.18.0

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y git wget curl vim build-essential libcrypt-dev libssl-dev zlib1g-dev libbrotli-dev libzstd-dev libexpat1-dev libmysqlclient-dev pkg-config libxml2-dev dnsutils tzdata perl apache2 libapache2-mod-perl2 libapache2-mod-evasive mysql-client ruby ruby-dev xz-utils cpanminus perlmagick psmisc cmake unzip libarchive-tools && rm -rf /var/lib/apt/lists/*
# Route tar extraction through bsdtar (libarchive), not GNU tar. Canonical rebuilt the
# ubuntu:26.04 base on 2026-07-16; its GNU tar 1.35 + glibc 2.41 now set modes with
# fchmodat2() -- Linux syscall #452, added in kernel 6.6 (Oct 2023) -- for which the old
# fchmodat has no AT_SYMLINK_NOFOLLOW fallback. CodeBuild's ARM build-host kernel is < 6.6,
# so fchmodat2 returns ENOSYS and every extraction dies ("Cannot mkdir/open: Function not
# implemented"), breaking `cpanm --installdeps` and the Node unpack below. This is a host-
# kernel gap, NOT a Docker-version issue -- it reproduced identically on CodeBuild AL2 3.0,
# AL2023 3.0, and AL2023 4.0. strace confirms bsdtar never calls fchmodat2 (it sets modes at
# mkdir time / via fchmod on an fd -- all universal syscalls), so it extracts fine on the old
# kernel. /usr/local/bin wins on PATH, so cpanm's `tar` and the bare `tar xv` below both
# resolve to bsdtar; cpanm detects bsdtar via `tar --version` and adjusts flags. (#4544)
RUN ln -sf /usr/bin/bsdtar /usr/local/bin/tar
ENV TZ=Etc/UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
# Ruby
RUN gem install aws-sdk-s3 aws-sdk-ecs aws-sdk-elasticloadbalancingv2 aws-sdk-cloudwatchlogs

# AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o "/tmp/awscliv2.zip" && \
    unzip -q /tmp/awscliv2.zip -d /tmp && \
    /tmp/aws/install && \
    rm -rf /tmp/awscliv2.zip /tmp/aws

# Core Directories and Apache
RUN mkdir -p /var/libraries /etc/everything /var/mason /var/log/everything /etc/apache2/logs /var/everything /var/bootstrap/cache
RUN rm -rf /etc/apache2/sites-enabled /etc/apache2/sites-available /etc/apache2/ports.conf /etc/apache2/conf.d /etc/apache2/conf-enabled /etc/apache2/conf-available
# PSGI: Apache is a pure reverse proxy -- no mod_perl, so no `perl` module and
# mpm_event (the base-image default) instead of mpm_prefork. prefork was only
# mandated by mod_perl's lack of thread-safety; event handles proxy connections
# with threads at far lower per-connection cost. (#4234, full PSGI commit)
RUN for i in deflate brotli rewrite authz_core proxy proxy_http mpm_event status evasive remoteip headers; do ln -sf ../mods-available/$i.load /etc/apache2/mods-enabled/$i.load; done
RUN chown root:root /etc/everything
RUN chown www-data:www-data /var/mason /var/log/everything /etc/apache2/logs
RUN chmod 0755 /var/mason

# Perl dependencies (only changes when cpanfile or vendor/cache changes)
COPY ./vendor/cache/ /var/bootstrap/cache/
COPY ./cpanfile /var/bootstrap
RUN cpanm -L /var/libraries --from "/var/bootstrap/cache" --installdeps --notest --cpanfile=/var/bootstrap/cpanfile .

# NodeJS / React. Use the npm bundled with Node (v24.18.0 ships npm 11.16.0) -- no floating
# `npm install -g npm@latest`, which is what silently broke the build when npm 12 dropped Node 20 (#4486).
RUN curl -L "https://nodejs.org/download/release/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-$ARCH.tar.xz" | xz -cd | tar xv --strip-components=1 -C /usr

# Node dependencies (only changes when package.json/package-lock.json changes)
WORKDIR /var/everything
COPY package.json package-lock.json ./
# puppeteer's postinstall downloads Chrome (~600 MB) into /root/.cache/puppeteer. Only the
# developer tools in tools/ use it, and they run on the host, so keep it out of the image (#4601).
ENV PUPPETEER_SKIP_DOWNLOAD=true
RUN /usr/bin/npm install

# Commit id for /etc/everything/last_commit, written in a tiny separate stage so the final
# stage needs no RUN after copying the application in (see below). Local builds overwrite it
# from git in the dev stage.
FROM ubuntu:26.04 AS commit
ARG CODEBUILD_RESOLVED_SOURCE_VERSION
RUN printf '%s\n' "${CODEBUILD_RESOLVED_SOURCE_VERSION:-unknown}" > /last_commit

# Stage 2: Final image with application code. This is what CodeBuild ships (--target final).
FROM deps AS final

# mod_perl is enabled by default in the base image (libapache2-mod-perl2); under
# PSGI Apache runs no Perl handlers, so unload it -- no redundant interpreter and
# no thread-safety concern under mpm_event. (#4234)
RUN rm -f /etc/apache2/mods-enabled/perl.load /etc/apache2/mods-enabled/perl.conf

# Everything below is COPY --link and nothing runs after it. --link layers don't depend on
# the filesystem underneath, so a fresh BuildKit builder working from the registry cache can
# push them without downloading and unpacking the ~1 GB of cached deps layers (#4623).
# local/ is kept out by .dockerignore rather than deleted here for the same reason.
COPY --link ./etc/templates/* /var/bootstrap/etc/
COPY --link --chmod=755 docker/e2app/apache2_wrapper.rb /etc/everything/
COPY --link ./ /var/everything
COPY --link --from=commit /last_commit /etc/everything/last_commit

EXPOSE 80

CMD ["/etc/everything/apache2_wrapper.rb"]

# Stage 3: local development image -- the default target, so ./docker/devbuild.sh is
# unchanged. CodeBuild builds the production bundles on the host and serves them from S3,
# so only local builds run webpack here; a failure must fail the build (#4599).
FROM final AS dev
RUN /usr/bin/npx webpack --config etc/webpack.config.js --mode=development
RUN git -C /var/everything rev-parse HEAD > /etc/everything/last_commit
