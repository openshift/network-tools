FROM registry.svc.ci.openshift.org/openshift/release:golang-1.15 AS builder
WORKDIR /go/src/github.com/openshift/debug-network
COPY . .
ENV GO_PACKAGE github.com/openshift/debug-network

FROM centos:8
COPY --from=builder /go/src/github.com/openshift/debug-network/debug-scripts/* /usr/bin/
RUN yum -y --setopt=tsflags=nodocs install jq tcpdump traceroute net-tools nmap-ncat pciutils strace numactl && \
    yum clean all && \
    curl https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/4.6.0/openshift-client-linux-4.6.0.tar.gz > /tmp/oc.tar.gz && \
    tar xzvf /tmp/oc.tar.gz -C /usr/bin && \
    rm /tmp/oc.tar.gz
