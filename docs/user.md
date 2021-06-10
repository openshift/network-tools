# User Documentation 

As an end user of OpenShift, you can use network-tools to debug and manage cluster networking directly through the CLI.
# What is OpenShift network-tools?

OpenShift network-tools contains a set of:

- cluster network debugging scripts written in bash
- frequently used network CLI tools like ping, netcat, tcpdump, strace etc.

to debug the networking state of a cluster in real time. This tool is currently only supported (has been tested) from OCP4.8.

**NOTE :**  The official supported way of running all scripts and tools are only through the `oc adm must-gather` utility. In certain unprecedented situations like when the api-server is down or networking is not up in the cluster, we might have to directly access the nodes in the cluster to figure out the root cause. In other situations, we may have to access the network namespace of the pod to run specific commands. Some of the scripts in this repository are written with such debugging situations in mind. Although the image is restricted to administrators and priviledges users, care must be taken when running such scripts locally on the cluster. Scripts must be double checked to ensure they do exactly what they intend to do.

# How is this different from must-gather?

While OpenShift must-gather focuses on gathering logs from each container in the cluster, network-tools focuses on collecting relevant information obtained by running a specific command or script during a specific window of (real) time in the cluster.

In certain situations the container logs might be difficult to parse and sometimes they may not contain all the relevant information needed to debug certain tricky networking bugs and packet losses like ovs/ovn packet traces and packet dumps. In addition to faciliating information collection necessary for debugging networking, it also allows users to run sample connectivity tests between existing nodes/pods/services. In future we hope to add debugging scripts for features such as network policies, egress IPs and egress routers which can help explain the path taken by a packet from a source to destination.

# Example Scenarios

Undermentioned scenarios are a part of the motivation behind which network-tools was created. Note that some of them are still a work in progress.

- I want to do a quick connectivity check between podA and serviceB.
- I want to check the status of the nodeports on nodeA.
- I want to check which are the free service ports that I can use or how many free podIPs are left in the hostsubnet of nodeA.
- I want to check the status of all the backing pods of serviceA.
- I want to test if all the ports on podA are in listen state as they are expected to be.
- I want to capture packets on interface X of nodeA.
- I want to run commands like 'tcpdump -i bond0' or 'conntrack -L' or 'sysctl -A' and filter out the gathered data in a useful way on all the master nodes.
- I want to run an ovn/ovs-packet trace between podA and podB.
- I want to dump ovs/ovn flows and conntrack's state of connections on the SDN (OVN) pod running on nodeA.
- I want to check if packets over the overlay network are encrypted using IPSec.
- I want to pull network interface information when APIs are unresponsive (must-gather might not help since a new pod cannot be spawned) by running the scripts locally.
- I want to check if the egress firewall blocks traffic of typeY.

# Invoking Scripts

TODO: Will update this section once we have the oc client integration patch merged.
