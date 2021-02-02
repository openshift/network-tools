FROM registry.ci.openshift.org/ocp/builder:rhel-8-golang-1.15-openshift-4.7 AS builder
WORKDIR /go/src/github.com/openshift/network-tools
COPY . .

# needed for ovnkube-trace
FROM registry.ci.openshift.org/ocp/4.7:ovn-kubernetes as ovnkube-trace

# tools (openshift-tools) is based off cli
FROM registry.ci.openshift.org/ocp/4.7:tools
COPY --from=builder /go/src/github.com/openshift/network-tools/debug-scripts/* /usr/bin/
COPY --from=ovnkube-trace /usr/bin/ovnkube-trace /usr/bin/

RUN INSTALL_PKGS="\
    nginx \
    numactl \
    traceroute \
    wireshark \
    conntrack-tools \
    perf \
    iproute \
    " && \
    yum -y install --setopt=tsflags=nodocs --setopt=skip_missing_names_on_install=False $INSTALL_PKGS && \
    yum clean all && rm -rf /var/cache/*
