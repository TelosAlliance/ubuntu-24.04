# syntax=docker/dockerfile:1.3-labs
# vim:syntax=dockerfile
FROM ubuntu:noble-20240904.1

# Set this before `apt-get` so that it can be done non-interactively
ENV DEBIAN_FRONTEND noninteractive
ENV TZ America/New_York
ENV LC_ALL C.UTF-8
ENV LANG C.UTF-8

# Golang env
ENV GOROOT /opt/go
ENV GOPATH $HOME/work/

# Rust env
ENV RUST_HOME /opt/rust
ENV CARGO_HOME $RUST_HOME
ENV RUSTUP_HOME $RUST_HOME/.rustup

# NodeJS env
ENV NODE_VERSION v20.18.0
ENV NODE_BUILD node-$NODE_VERSION-linux-x64
ENV NODE_BIN /opt/node-$NODE_VERSION-linux-x64/bin

# Set PATH to include custom bin directories
ENV PATH $GOPATH/bin:$GOROOT/bin:$RUST_HOME/bin:$NODE_BIN:$PATH

# KEEP PACKAGES SORTED ALPHABETICALY
# Do everything in one RUN command
RUN /bin/bash <<EOF
set -euxo pipefail
# Enable support for adding 32-bit packages
dpkg --add-architecture i386
apt-get update
# Install packages needed to set up third-party repositories
apt-get install -y --no-install-recommends \
  apt-transport-https \
  build-essential \
  ca-certificates \
  curl \
  gnupg \
  python3 \
  python3-pip \
  software-properties-common \
  unzip \
  wget
# Install AWS cli
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf awscliv2.zip aws
# Use kitware's CMake repository for up-to-date version
curl -sSf https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | apt-key add -
apt-add-repository 'deb https://apt.kitware.com/ubuntu/ jammy main'
apt-get install -y --no-install-recommends \
  cmake
# Use NodeSource's NodeJS 18.x repository
curl -sSf https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y --no-install-recommends \
  nodejs
# Install nvm binary
curl -sSf https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
# Install other javascript package managers
npm install -g yarn pnpm
# Install newer version of Go than is included with Ubuntu
curl -sSf https://dl.google.com/go/go1.19.linux-amd64.tar.gz | tar -xz -C /opt
# Install Rust prereqs
apt-get install -y --no-install-recommends \
  musl-tools
# Install Rust and Rust tools
curl -sSf https://sh.rustup.rs | sh -s -- -y
curl -sSf https://just.systems/install.sh | bash -s -- --to "$RUST_HOME/bin"
cargo install cargo-about
cargo install cargo-bundle-licenses
cargo install cargo-deny
cargo install cargo-license
cargo install cargo-lichking
# cargo-script is commented out because it doesn't compile with the latest Rust
#cargo install cargo-script
cargo install cargo-deb
cargo install cargo-generate-rpm
rustup target add x86_64-unknown-linux-musl
rustup target add armv7-unknown-linux-gnueabihf
rm -rf "$RUST_HOME/registry" "$RUST_HOME/git"
chmod 777 "$RUST_HOME"
# Install gstreamer
apt-get install -y --no-install-recommends \
  gstreamer1.0-nice \
  gstreamer1.0-plugins-bad \
  gstreamer1.0-plugins-good \
  gstreamer1.0-plugins-ugly \
  gstreamer1.0-tools \
  libgstreamer1.0-dev \
  libglib2.0-dev \
  libgstreamer-plugins-bad1.0-dev \
  libjson-glib-dev \
  libsoup2.4-dev
# Install everything else
apt-get install -y --no-install-recommends \
  autoconf \
  automake \
  bc \
  bison \
  cpio \
  cppcheck \
  device-tree-compiler \
  elfutils \
  file \
  flex \
  gawk \
  gcovr \
  gdb \
  gettext \
  git \
  git-lfs \
  gosu \
  jq \
  kmod \
  libasound2-dev \
  libavahi-compat-libdnssd-dev \
  libbison-dev \
  libboost-all-dev \
  libcurl4-openssl-dev \
  libgnutls28-dev \
  libsndfile1-dev \
  libssl-dev \
  libtool \
  libwebsocketpp-dev \
  libwebsockets-dev \
  locales-all \
  lzop \
  ncurses-dev \
  openssh-client \
  pandoc \
  rsync \
  shellcheck \
  swig \
  time \
  uuid-dev \
  valgrind \
  vim \
  zip \
  zlib1g-dev
# for 32-bit support
apt-get install -y --no-install-recommends \
  libc6:i386 libstdc++6:i386 lib32z1 \
  gcc-multilib g++-multilib \
  libgtest-dev:i386 \
  libc6-dev:i386 \
  libz-dev:i386 \
  libglib2.0-dev:i386 \
  libssl-dev:i386
# Additional requirements for XDP
apt-get install -y \
  libbpf-dev \
  llvm \
  clang \
  efitools \
  git-lfs \
  libc6-dev-i386 \
  libelf-dev \
  libelf1 \
  libnuma-dev \
  libpcap-dev \
  libxdp-dev \
  meson \
  ninja-build \
  opus-tools \
  python3-pyelftools \
  sbsigntool \
  uuid-runtime
apt-get clean
rm -rf /var/lib/apt/lists/*
EOF

COPY patch /
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/bin/bash"]
