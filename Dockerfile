FROM registry.ci.openshift.org/ocp/builder:rhel-9-golang-1.21-openshift-4.16 AS builder
WORKDIR /go/src/github.com/openshift/network-tools
COPY . .

# needed for ovnkube-trace
FROM registry.ci.openshift.org/ocp/4.16:ovn-kubernetes AS ovnkube-trace

# tools (openshift-tools) is based off cli
FROM registry.ci.openshift.org/ocp/4.16:tools
COPY --from=builder /go/src/github.com/openshift/network-tools/debug-scripts/ /opt/bin/
COPY --from=ovnkube-trace /usr/bin/ovnkube-trace /usr/bin/

# remove internal scripts from the image and create a symlink for network-tools and gather entrypoint for must-gather
RUN rm -rf /opt/bin/local-scripts && ln -s /opt/bin/network-tools /usr/bin/network-tools && ln -s /opt/bin/network-tools /usr/bin/gather


# Make sure to maintain alphabetical ordering when adding new packages.
RUN INSTALL_PKGS="\
    bcc \
    bcc-tools \
    conntrack-tools \
    iproute \
    nginx \
    numactl \
    perf \
    python3-bcc \
    traceroute \
    wireshark-cli \
    " && \
    yum -y install --setopt=tsflags=nodocs --setopt=skip_missing_names_on_install=False $INSTALL_PKGS && \
    yum clean all && rm -rf /var/cache/*
