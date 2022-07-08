FROM registry.ci.openshift.org/ocp/builder:rhel-8-golang-1.18-openshift-4.12 AS builder
WORKDIR /go/src/github.com/openshift/network-tools
COPY . .

# needed for ovnkube-trace
FROM registry.ci.openshift.org/ocp/4.12:ovn-kubernetes AS ovnkube-trace

# tools (openshift-tools) is based off cli
FROM registry.ci.openshift.org/ocp/4.12:tools
COPY --from=builder /go/src/github.com/openshift/network-tools/debug-scripts/* /usr/bin/
COPY --from=ovnkube-trace /usr/bin/ovnkube-trace /usr/bin/

# Make sure to maintain alphabetical ordering when adding new packages.
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
