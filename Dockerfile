FROM registry.svc.ci.openshift.org/openshift/release:golang-1.12 AS builder
WORKDIR /go/src/github.com/openshift/debug-network
COPY . .
ENV GO_PACKAGE github.com/openshift/debug-network

FROM registry.svc.ci.openshift.org/openshift/origin-v4.0:cli
COPY --from=builder /go/src/github.com/openshift/debug-network/debug-scripts/* /usr/bin/

