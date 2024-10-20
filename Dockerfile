FROM --platform=$BUILDPLATFORM alpine:3.20 AS builder

RUN apk --no-cache add \
    curl \
    bash \
    cargo \
    clang \
    g++ \
    gcc \
    git \
    go \
    lld \
    make \
    py3-pip \
    py3-setuptools \
    py3-wheel \
    python3 \
    python3-dev \
    rustup

ARG TARGETARCH
ARG TARGETOS
RUN case "$TARGETARCH" in \
    "amd64") ARCH="x86_64" ;; \
    "arm64") ARCH="aarch64" ;; \
    "arm") ARCH="armv7l" ;; \
    *) echo "Unsupported architecture: $TARGETARCH" && exit 1 ;; \
  esac \
  && rustup-init -y --default-toolchain stable --default-host $ARCH-unknown-linux-musl

WORKDIR /src

ARG KCL_VERSION=main
RUN git clone --depth=1 --branch $KCL_VERSION https://github.com/kcl-lang/kcl .

RUN --mount=type=cache,target=/usr/local/cargo/registry make build

FROM --platform=$TARGETPLATFORM alpine:3.20 AS target

RUN apk --no-cache add \
  libgcc

COPY --from=builder /src/_build/dist/alpine/kclvm/bin/* /usr/lib/
COPY --from=builder /src/kclvm/target/release/deps/*.so /usr/lib/
COPY --from=builder /src/_build/dist/alpine/kclvm/include/* /usr/include/

RUN ln -s /usr/bin/kclvm_cli /usr/bin/kcl
