# syntax=docker/dockerfile:1.3-labs
# vim:syntax=dockerfile
#FROM ubuntu:noble-20240904.1
FROM ubuntu:noble-20250910

# Set this before `apt-get` so that it can be done non-interactively
ENV DEBIAN_FRONTEND noninteractive
ENV TZ America/New_York
ENV LC_ALL C.UTF-8
ENV LANG C.UTF-8

# Golang env
ENV GO_VERSION=1.24.4
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
ARG TARGETPLATFORM
RUN echo "***** Building for platform: $TARGETPLATFORM, architecture: $TARGETARCH *****"

# Architecture-specific variables
RUN /bin/bash <<EOF
set -euxo pipefail

# Define architecture-specific variables
case "$TARGETARCH" in
  amd64)
    export AWS_ARCH="x86_64"
    export GO_ARCH="amd64"
    export RUST_TARGET="x86_64-unknown-linux-musl"
    export LIBC_DEV_PACKAGE="libc6-dev-i386"
    export NODE_ARCH="x64"
    ;;
  arm64)
    export AWS_ARCH="aarch64"
    export GO_ARCH="arm64"
    export RUST_TARGET="aarch64-unknown-linux-musl"
    export LIBC_DEV_PACKAGE="libc6-dev-arm64-cross"
    export NODE_ARCH="arm64"
    ;;
  arm)
    export AWS_ARCH="arm"
    export GO_ARCH="arm"
    export RUST_TARGET="arm-unknown-linux-musleabihf"
    export LIBC_DEV_PACKAGE="libc6-dev-armel-cross"
    export NODE_ARCH="armv7l"
    ;;
  *)
    echo "Unsupported architecture: $TARGETARCH"
    echo "Supported architectures: amd64, arm64, arm"
    exit 1
    ;;
esac

# Store variables for later use
echo "export AWS_ARCH=\$AWS_ARCH" >> /tmp/arch_vars.sh
echo "export GO_ARCH=\$GO_ARCH" >> /tmp/arch_vars.sh
echo "export RUST_TARGET=\$RUST_TARGET" >> /tmp/arch_vars.sh
echo "export LIBC_DEV_PACKAGE=\$LIBC_DEV_PACKAGE" >> /tmp/arch_vars.sh
echo "export NODE_ARCH=\$NODE_ARCH" >> /tmp/arch_vars.sh

EOF

# KEEP PACKAGES SORTED ALPHABETICALLY
# Do everything in one RUN command
RUN /bin/bash <<EOF
set -euxo pipefail

# Load architecture variables
source /tmp/arch_vars.sh

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

# Install AWS CLI with better error handling
echo "Installing AWS CLI for \$AWS_ARCH..."
AWS_CLI_URL="https://awscli.amazonaws.com/awscli-exe-linux-\${AWS_ARCH}.zip"
if curl -f "\$AWS_CLI_URL" -o "awscliv2.zip"; then
  unzip awscliv2.zip
  ./aws/install
  rm -rf awscliv2.zip aws
else
  echo "Warning: AWS CLI not available for architecture \$AWS_ARCH, skipping..."
fi

# Use kitware's CMake repository for up-to-date version
curl -sSfL https://apt.kitware.com/keys/kitware-archive-latest.asc | gpg --dearmor -o /usr/share/keyrings/kitware-keyring.gpg
echo 'deb [signed-by=/usr/share/keyrings/kitware-keyring.gpg] https://apt.kitware.com/ubuntu/ jammy main' | tee /etc/apt/sources.list.d/kitware.list
apt-get update
apt-get install -y --no-install-recommends cmake

# Use NodeSource's NodeJS repository
curl -sSfL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y --no-install-recommends nodejs

# Install nvm binary
curl -sSfL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash

# Install other javascript package managers
npm install -g yarn pnpm

# Install Go with architecture detection
echo "Installing Go for \$GO_ARCH..."
GO_URL="https://dl.google.com/go/go\${GO_VERSION}.linux-\${GO_ARCH}.tar.gz"
if curl -sSfL "\$GO_URL" | tar -xz -C /opt; then
  echo "Go installed successfully"
else
  echo "Error: Failed to install Go for architecture \$GO_ARCH"
  exit 1
fi

# Install Rust prereqs
apt-get install -y --no-install-recommends musl-tools

# Install Rust and Rust tools
curl -sSfL https://sh.rustup.rs | sh -s -- -y
source \$RUST_HOME/env
curl -sSfL https://just.systems/install.sh | bash -s -- --to "\$RUST_HOME/bin"

# Install Rust tools
cargo install cargo-about
cargo install cargo-bundle-licenses
cargo install cargo-deny
cargo install cargo-license
cargo install cargo-lichking
cargo install cargo-deb
cargo install cargo-generate-rpm

# Add Rust target
echo "Adding Rust target: \$RUST_TARGET"
rustup target add "\$RUST_TARGET"

# Clean up Rust cache
rm -rf "\$RUST_HOME/registry" "\$RUST_HOME/git"
chmod 777 "\$RUST_HOME"

# Create go directory
mkdir -p "\$GO_HOME"
chmod 777 "\$GO_HOME"

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

# Install architecture-specific libc6-dev packages
echo "Installing \$LIBC_DEV_PACKAGE for cross-compilation..."
if apt-cache show "\$LIBC_DEV_PACKAGE" >/dev/null 2>&1; then
  apt-get install -y "\$LIBC_DEV_PACKAGE"
else
  echo "Warning: Package \$LIBC_DEV_PACKAGE not available, skipping..."
fi

# Create symlinks for arm64 if needed
if [ "\$TARGETARCH" = "arm64" ]; then
  ln -sf /lib/aarch64-linux-gnu/ /lib64 || true
  ln -sf /usr/lib/aarch64-linux-gnu/ /usr/lib64 || true
fi

# Clean up
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/arch_vars.sh

EOF

COPY patch /
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/bin/bash"]