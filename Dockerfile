# Build the manager binary
FROM --platform=$BUILDPLATFORM golang:1.15 as builder-src

ARG KUBE_STATE_METRICS_VERSION="v1.9.7"

WORKDIR /workspace
RUN git clone https://github.com/kubernetes/kube-state-metrics.git

WORKDIR /workspace/kube-state-metrics
RUN git checkout ${KUBE_STATE_METRICS_VERSION}

# cache deps before building and copying source so that we don't need to re-download as much
# and so that source changes don't invalidate our downloaded layer
RUN go mod download


FROM --platform=$BUILDPLATFORM builder-src as builder

ARG TARGETPLATFORM
ARG BUILDPLATFORM
RUN GOOS=$(echo $TARGETPLATFORM | cut -f1 -d/) && \
    GOARCH=$(echo $TARGETPLATFORM | cut -f2 -d/) && \
    GOARM=$(echo $TARGETPLATFORM | cut -f3 -d/ | sed "s/v//" ) && \
    GOARCH=${GOARCH} GOARM=${GOARM} go mod vendor && \
    CGO_ENABLED=0 GOOS=${GOOS} GOARCH=${GOARCH} GOARM=${GOARM} GO111MODULE=on go build -ldflags "-s -w" -o kube-state-metrics

# Use distroless as minimal base image to package the manager binary
# Refer to https://github.com/GoogleContainerTools/distroless for more details
FROM gcr.io/distroless/static:latest
WORKDIR /
COPY --from=builder /workspace/kube-state-metrics/kube-state-metrics .

ENTRYPOINT ["/kube-state-metrics", "--port=8080", "--telemetry-port=8081"]

EXPOSE 8080 8081
