# syntax=docker/dockerfile:1.3-labs
# vim:syntax=dockerfile
FROM ubuntu:noble-20240904.1

# Set this before `apt-get` so that it can be done non-interactively
ENV DEBIAN_FRONTEND noninteractive
ENV TZ America/New_York
ENV LC_ALL C.UTF-8
ENV LANG C.UTF-8

# Golang env
ENV GO_HOME /opt/go
ENV GOCACHE $GO_HOME/go-cache
ENV GOPATH  $GO_HOME/work

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

ARG TARGETARCH
RUN echo "***** Building for architecture: $TARGETARCH *****"

# KEEP PACKAGES SORTED ALPHABETICALY
# Do everything in one RUN command
RUN /bin/bash <<EOF
set -euxo pipefail
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
if [ "$TARGETARCH" = "amd64" ]; then \
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
elif [ "$TARGETARCH" = "arm64" ]; then \
  curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
else
  echo "Unsupported architecture: $TARGETARCH"
  exit 1
fi
unzip awscliv2.zip
./aws/install
rm -rf awscliv2.zip aws
# Use kitware's CMake repository for up-to-date version
curl -sSf https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | apt-key add -
apt-add-repository 'deb https://apt.kitware.com/ubuntu/ jammy main'
apt-get install -y --no-install-recommends \
  cmake
# Use NodeSource's NodeJS repository
curl -sSf https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y --no-install-recommends \
  nodejs
# Install nvm binary
curl -sSf https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
# Install other javascript package managers
npm install -g yarn pnpm
# Install newer version of Go than is included with Ubuntu
if [ "$TARGETARCH" = "amd64" ]; then \
  curl -sSf https://dl.google.com/go/go1.24.4.linux-amd64.tar.gz | tar -xz -C /opt
elif [ "$TARGETARCH" = "arm64" ]; then \
  curl -sSf https://dl.google.com/go/go1.24.4.linux-arm64.tar.gz | tar -xz -C /opt
else
  echo "Unsupported architecture: $TARGETARCH"
  exit 1
fi
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
cargo install cargo-deb
cargo install cargo-generate-rpm
if [ "$TARGETARCH" = "amd64" ]; then \
rustup target add x86_64-unknown-linux-musl
elif [ "$TARGETARCH" = "arm64" ]; then \
rustup target add aarch64-unknown-linux-musl
else
  echo "Unsupported architecture: $TARGETARCH"
  exit 1
fi

rm -rf "$RUST_HOME/registry" "$RUST_HOME/git"
chmod 777 "$RUST_HOME"
# go directory
mkdir -p "$GO_HOME"
chmod 777 "$GO_HOME"
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
# Additional requirements for XDP
apt-get install -y \
  libbpf-dev \
  llvm \
  clang \
  efitools \
  git-lfs \
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
# Install libc6-dev for cross-compilation
if [ "$TARGETARCH" = "amd64" ]; then \
  apt-get install -y \
    libc6-dev-i386
elif [ "$TARGETARCH" = "arm64" ]; then \
  apt-get install -y \
    libc6-dev-arm64-cross
else
  echo "Unsupported architecture: $TARGETARCH"
  exit 1
fi
if [ "$TARGETARCH" = "arm64" ]; then \
  ln -s /lib/aarch64-linux-gnu/ /lib64
  ln -s /usr/lib/aarch64-linux-gnu/ /usr/lib64
fi
apt-get clean
rm -rf /var/lib/apt/lists/*
EOF

COPY patch /
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/bin/bash"]
