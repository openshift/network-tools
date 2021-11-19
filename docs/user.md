# User Documentation 

As an end user of OpenShift, you can use network-tools to debug and manage cluster networking directly through the CLI.
# What is OpenShift network-tools?

OpenShift network-tools contains a set of:

- cluster network debugging scripts written in bash
- frequently used network CLI tools like ping, netcat, tcpdump, strace etc.

to debug the networking state of a cluster in real time. This tool is currently only supported (has been tested) 
from OCP4.8.

**NOTE :**  The official supported way of running all scripts and tools are only through the `oc adm must-gather` utility.
In certain unprecedented situations like when the api-server is down or networking is not up in the cluster, we might 
have to directly access the nodes in the cluster to figure out the root cause. In other situations, we may have to 
access the network namespace of the pod to run specific commands. Some of the scripts in this repository are written 
with such debugging situations in mind. Although the image is restricted to administrators and priviledges users, care
must be taken when running such scripts locally on the cluster. Scripts must be double checked to ensure they do exactly
what they intend to do.

# How is this different from must-gather?

While OpenShift must-gather focuses on gathering logs from each container in the cluster, network-tools focuses on 
collecting relevant information obtained by running a specific command or script during a specific window of (real) 
time in the cluster.

In certain situations the container logs might be difficult to parse and sometimes they may not contain all the 
relevant information needed to debug certain tricky networking bugs and packet losses like ovs/ovn packet traces and 
packet dumps. In addition to faciliating information collection necessary for debugging networking, it also allows 
users to run sample connectivity tests between existing nodes/pods/services. In future we hope to add debugging scripts 
for features such as network policies, egress IPs and egress routers which can help explain the path taken by a packet 
from a source to destination.

# Example Scenarios

Undermentioned scenarios are a part of the motivation behind which network-tools was created. Note that some of them 
are still a work in progress.

- I want to do a quick connectivity check between podA and serviceB.
- I want to check the status of the nodeports on nodeA.
- I want to check which are the free service ports that I can use or how many free podIPs are left in the hostsubnet of 
  nodeA.
- I want to check the status of all the backing pods of serviceA.
- I want to test if all the ports on podA are in listen state as they are expected to be.
- I want to capture packets on interface X of nodeA.
- I want to run commands like 'tcpdump -i bond0' or 'conntrack -L' or 'sysctl -A' and filter out the gathered data in a 
  useful way on all the master nodes.
- I want to run an ovn/ovs-packet trace between podA and podB.
- I want to dump ovs/ovn flows and conntrack's state of connections on the SDN (OVN) pod running on nodeA.
- I want to check if packets over the overlay network are encrypted using IPSec.
- I want to pull network interface information when APIs are unresponsive (must-gather might not help since a new pod 
  cannot be spawned) by running the scripts locally.
- I want to check if the egress firewall blocks traffic of typeY.

# Invoking Scripts

`oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest` will run default debug sequence based on 
Networking plugin.
Only OpenShiftSDN and OVNKubernetes plugins are supported for now. You can also run all scripts manually and provide 
some options.

Default scripts are:
* OVNKubernetes = `ovn_pod_to_pod_connectivity`, `ovn_pod_to_svc_connectivity`, `ovn_ipsec_connectivity`
* OpenshiftSDN = `sdn_pod_to_pod_connectivity`, `sdn_pod_to_svc_connectivity`, `sdn_cluster_and_node_info`

## OVNKubernetes scripts

* `ovn_pod_to_pod_connectivity`  
  This script checks pod2pod connectivity on an OVN cluster.
  By default this script spins up two pods (a client and a server) in the openshift-network-tools-* namespace. You can 
  optionally supply the script with a pair of source and destination names. These can either be the source and 
  destination node names on which the debug pods should be scheduled or they can be existing pod names 
  (format: <namespace/pod-name>) to run the connectivity
  test.
  
  **NOTE**: If existing pods are passed as arguments, make sure ping utility is installed on the <src-pod> pods.
  
  **Method**: We run a ping from the <src-pod> to <dst-pod>. If ping is not installed on the <src-pod> or if it fails, 
  we run a ping command from the
  network namespace of the <src-pod> to <dst-pod> to check connectivity.
  
  If the connectivity test fails, it will run an ovnkube trace between the source and destination pods.  
  ```
  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- ovn_pod_to_pod_connectivity <src-node-name> <dst-node-name>`
  
  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- ovn_pod_to_pod_connectivity <src-pod-namespace/src-pod-name> <dst-pod-namespace/dst-pod-name>`
  ```
  
* `ovn_pod_to_svc_connectivity`
  
  This script checks pod2svc connectivity on an OVN cluster.
  By default this script spins up a pod (a client) and a service (a backing-server pod and a `clusterIP:port` svc) in the
  openshift-network-tools-* namespace.
  You can optionally supply the script with a pair of source and destination names. These can either be the source and
  destination node names on which the debug pods should be scheduled or they can be existing pod (format: 
  <namespace/pod-name>) and service names (format: <namespace/svc-name>)
  to run the connectivity test.

  **NOTE**: If existing pod/svc are passed as arguments, make sure curl utility is installed on the pod and svc has 
  `.spec.clusterIP:80` exposed for testing.
  
  **Method**: We run a curl from the <src-pod> to <dst-svc-ip>. If curl is not installed on the pod or if it fails, 
  we run a netcat command from the network namespace of the <src-pod> to <dst-svc-ip> to check connectivity.
  
  If the connectivity test fails, it will run an ovnkube trace between the pod and service.   
  ```
  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- ovn_pod_to_pod_connectivity <namespace/pod-name> <namespace/svc-name>`
  
  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- ovn_pod_to_pod_connectivity <src-node-name> <dst-node-name>`
  ```
  
* `ovn_ipsec_connectivity`
  
  This script checks that node2node traffic is encrypted when the ipsec feature is enabled an Openshift OVN-kubernetes 
  cluster. By default this script spins up two pods (a client and a server) on two different nodes in the 
  openshift-network-tools-* namespace. It also spins up a host networked debug pod which runs a packet sniffer 
  on all traffic passing between the nodes.
  **Method**: We run a ping from the <src-pod> to <dst-pod>. The debug pod running tcpdump captures the packet as
  it traverses the Geneve tunnel across the nodes and ensures the pack is encrypted wth the ESP protocol. 
  It will also dump the .pcap capture for further analysis to the debug pod regardless of a passing or failing test.
  ```
  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- ovn_ipsec_connectivity`
  ```
  
* `ovn_nic_firmware`

  This script checks the firmware of OVN cluster nodes match.
  If there is a NIC firmware mismatch, it will show the firmware version mismatch. 
  ```
  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- ovn_nic_firmware`
  ```

## OpenshiftSDN scripts

* `sdn_pod_to_pod_connectivity`
  
  This script checks pod2pod connectivity on a SDN cluster.
  By default this script spins up two pods (a client and a server) in the openshift-network-tools-* 
  namespace. You can optionally supply the script with a pair of source and destination names. 
  These can either be the source and destination node names on which the debug pods should be 
  scheduled or they can be existing pod names (format: <namespace/pod-name>) to run the connectivity
  test.
  
  **Method**: We run a ping from the network namespace of the src-pod to the dst-pod to check connectivity.
  
  If the connectivity test fails the script will report failure through logs. 
  ```
  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- sdn_pod_to_pod_connectivity <src-node-name> <dst-node-name>`
  
  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- sdn_pod_to_pod_connectivity <src-pod-namespace/src-pod-name> <dst-pod-namespace/dst-pod-name>`
  ```

* `sdn_pod_to_svc_connectivity`
  This script checks pod2svc connectivity on a SDN cluster.
  By default this script spins up a pod (a client) and a service (a backing-server pod and a `clusterIP:port` svc)
  in the openshift-network-tools-* namespace. You can optionally supply the script with a pair of source and 
  destination names. These can either be the source and destination node names on which the debug pods should be 
  scheduled or they can be existing pod (format: <namespace/pod-name>) and service names (format: <namespace/svc-name>) 
  to run the connectivity test.

  **Method**: We run a netcat command from the network namespace of the src-pod to each of the endpoints and dst-svc-ip to check connectivity.
  
  If the connectivity test fails the script will report failure through logs.
  ```
  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- sdn_pod_to_svc_connectivity <namespace/pod-name> <namespace/svc-name>`
  
  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- sdn_pod_to_svc_connectivity <src-node-name> <dst-node-name>`
  ```
* `sdn_cluster_and_node_info`
  
  This script queries and displays some important cluster information: nodes, pods, services, endpoints, routers, 
  clusternetwork, hostsubnets, netnamespace on a SDN cluster.

  It also by default spins up a host-network pod on each node in the cluster and grabs the following info: interface 
  information, ip a, ip ro, iptables-save, ovs dump-flows, conntrack-dump, ct-stats, crictl ps -v

  **Note**: If you want the information only from a single node, you can provide that node's name as an argument.
  ```
  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- sdn_cluster_and_node_info`
  
  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- sdn_cluster_and_node_info <node_name>`
  ```
* `sdn_node_connectivity`
  
  This script checks the node connectivity on a SDN cluster. It pings hostsubnet addresses.
  ```
  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- sdn_node_connectivity`
  ```

# Running custom commands

`network-tools` image has some packets installed:
* nginx
* numactl
* traceroute
* wireshark
* conntrack-tools
* perf
* iproute

You can run custom command from `network-tools` container by
`oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- timeout <n> <cmd>`

**WARNING!** don't forget to set timeout for long-running commands otherwise must-gather container will only exit in 10 minutes.
You can also use must-gather `--timeout` option like 5s, 2m, or 3h, higher than zero. Defaults to 10 minutes.

```
oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- timeout 5 ping 8.8.8.8

output:
[must-gather      ] OUT pod for plug-in image quay.io/openshift/origin-network-tools:latest created
[must-gather-9j484] POD 2021-11-08T10:31:18.945125411Z PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
[must-gather-9j484] POD 2021-11-08T10:31:18.945125411Z 64 bytes from 8.8.8.8: icmp_seq=1 ttl=49 time=3.54 ms
[must-gather-9j484] POD 2021-11-08T10:31:19.945091109Z 64 bytes from 8.8.8.8: icmp_seq=2 ttl=49 time=1.76 ms
[must-gather-9j484] POD 2021-11-08T10:31:20.945646272Z 64 bytes from 8.8.8.8: icmp_seq=3 ttl=49 time=1.24 ms
[must-gather-9j484] POD 2021-11-08T10:31:21.946772582Z 64 bytes from 8.8.8.8: icmp_seq=4 ttl=49 time=1.22 ms
[must-gather-9j484] POD 2021-11-08T10:31:22.948057813Z 64 bytes from 8.8.8.8: icmp_seq=5 ttl=49 time=1.17 ms
```

If you want to forward output to the file and find it in must-gather archive, add `> must-gather/<filename>` to the end of your command

To run network-tools container using host-network add `--host-network`

To choose a node to run network-tools container use `--node-name=''`

To run network-tools containers on multiple nodes use `--node-selector 'kubernetes.io/os=linux,node-role.kubernetes.io/master'`

To copy a folder from network-tools container use `--source-dir '<container dir>'`

## Examples
* Run tcpdump on all master nodes
  ```
  oc adm must-gather --source-dir '/tmp/tcpdump/' --image quay.io/openshift/origin-network-tools:latest 
  --node-selector 'kubernetes.io/os=linux,node-role.kubernetes.io/master' --host-network -- 
  timeout 30 tcpdump -i any -w /tmp/tcpdump/\$POD_NAME-%Y-%m-%dT%H:%M:%S.pcap -W 1 -G 300
  ```

