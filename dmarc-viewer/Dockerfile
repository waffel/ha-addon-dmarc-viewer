# Builds the DMARC viewer from a pinned, reviewed commit instead of pulling a prebuilt image.
# The first build compiles ~250 crates and takes a while on a Raspberry Pi; later starts are instant.
FROM rust:1-alpine AS builder
# Package versions are not pinned: Alpine drops old package versions, which would break rebuilds.
# hadolint ignore=DL3018
RUN apk add --no-cache musl-dev make cmake g++ git
ARG COMMIT=5e53bf879dac6c5b9cb93d3f89484cca8ecb38dd
RUN git clone https://github.com/cry-inc/dmarc-report-viewer.git /src
WORKDIR /src
RUN git checkout "$COMMIT"
ENV CARGO_TARGET_DIR=/target
RUN cargo build --release --locked && strip /target/release/dmarc-report-viewer

FROM alpine:3.21
# hadolint ignore=DL3018
RUN apk add --no-cache jq
COPY --from=builder /target/release/dmarc-report-viewer /usr/local/bin/dmarc-report-viewer
COPY run.sh /run.sh
RUN chmod +x /run.sh
CMD ["/run.sh"]
