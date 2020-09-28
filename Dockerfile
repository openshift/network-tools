FROM registry.svc.ci.openshift.org/openshift/release:golang-1.12 AS builder
WORKDIR /go/src/github.com/openshift/debug-network
COPY . .
ENV GO_PACKAGE github.com/openshift/debug-network

FROM centos:8
COPY --from=builder /go/src/github.com/openshift/debug-network/debug-scripts/* /usr/bin/
RUN yum -y --setopt=tsflags=nodocs install jq tcpdump traceroute net-tools nmap-ncat pciutils strace numactl && yum clean all
