# User Documentation 

As an end user of OpenShift, you can use network-tools to debug and manage cluster networking directly through the CLI.
As a support/software engineer you can run the same tools locally.

# What is OpenShift network-tools?

OpenShift network-tools contains a set of:

- cluster network debugging scripts written in bash
- frequently used network CLI tools like ping, netcat, tcpdump, strace etc.

to debug the networking state of a cluster in real time. This tool is currently only supported (has been tested) 
from OCP4.8.

**NOTE :** 
In certain unprecedented situations like when the api-server is down or networking is not up in the cluster, we might 
have to directly access the nodes in the cluster to figure out the root cause. In other situations, we may have to 
access the network namespace of the pod to run specific commands. Some of the scripts in this repository are written 
with such debugging situations in mind. Although the image is restricted to administrators and priviledges users, care
must be taken when running such scripts locally on the cluster. Scripts must be double checked to ensure they do exactly
what they intend to do.

# Invoking Scripts
`network-tools` can be run locally or on a cluster, some commands are only available locally, you can get the list of
enabled commands by `network-tools -h` locally or with `must-gather` and the output can be different.

### Locally
To use network-tools locally use can just clone this repo and run
`./debug-scripts/network-tools -h` - that will list all available commands.

You can also create a symlink for your convenience to just use `network-tools`
`ln -s <repo-path>/debug-scripts/network-tools /usr/bin/network-tools`
`network-tools -h`

### On the cluster

You can use almost all the same scripts on the cluster via network-tools image, to run one command you can use
`oc adm must-gather --image quay.io/openshift/origin-network-tools:latest -- network-tools -h`

WARNING! `must-gather` doesn't allow interactive input, don't use interactive options with must-gather.

Running `network-tools` on a cluster is different from local run:
1. Interactive options (e.g. `-it`) can not be used, because `must-gather` doesn't accept input
2. Everything from the `/must-gather` folder will be copied at the end of command execution, therefore
   1. to forward command output to a file use

      `oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- "network-tools <command> > /must-gather/<filename>"`
   2. for commands that accept output folder as parameter, use `/must-gather`
   
`oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- network-tools -h` will show all available 
commands on the cluster.

To run script that are not included in the `network-tools -h` call them directly via
`debug-scripts/<script path>` locally or `/opt/bin/<script path>` in the image.

# Running custom commands

`network-tools` image has some packages installed that can be useful for debugging:
* nginx
* numactl
* traceroute
* wireshark
* conntrack-tools
* perf
* iproute
* ovnkube-trace

The image is based on oc https://github.com/openshift/oc/blob/master/images/tools/Dockerfile
and also includes all the tools from this Dockerfile.

You can run custom command from `network-tools` container by
`oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- <cmd>`

**WARNING!** `must-gather` has a timeout of 10 minutes, and shouldn't be interrupted with Ctrl+C in order for
`must-gather` to properly clean up its resources. 
Make sure the command you run will be completed. If it requires more than 10 minutes to complete use 
must-gather `--timeout` option like 5s, 2m, or 3h.
To make sure commands like tcpdump stop in N seconds you can use `timeout N <command>` that will stop this command in 
N seconds.

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

If you want to forward output to the file and find it in must-gather archive, add `> /must-gather/<filename>` to the end of your command.

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

* Run `ovnkube-trace` for troubleshooting traffic flows:

  Let's say you have two pods `multitool-756669cf4f-bhx64` and `multitool-756669cf4f-6bftt` in default namespace.
  ```
    $ oc get pods
    NAME                         READY   STATUS    RESTARTS   AGE
    multitool-756669cf4f-6bftt   1/1     Running   0          5m27s
    multitool-756669cf4f-bhx64   1/1     Running   0          5m27s
  ```
  To run a trace between them:
   ```
    oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- ovnkube-trace -dst-namespace default -dst multitool-756669cf4f-bhx64 -src-namespace default -src multitool-756669cf4f-6bftt -tcp -loglevel 5
    [must-gather      ] OUT Using must-gather plugin-in image: quay.io/openshift/origin-network-tools:latest
    [must-gather      ] OUT namespace/openshift-must-gather-zm2mj created
    [must-gather      ] OUT clusterrolebinding.rbac.authorization.k8s.io/must-gather-4gcvh created
    [must-gather      ] OUT pod for plug-in image quay.io/openshift/origin-network-tools:latest created
    [must-gather-gq2ln] POD I0217 13:39:39.939788       8 ovs.go:95] Maximum command line arguments set to: 191102
    [must-gather-gq2ln] POD I0217 13:39:39.940114       8 ovnkube-trace.go:517] Log level set to: 5
    <snipped>.....
   ```
  Checkout https://github.com/ovn-org/ovn-kubernetes/blob/master/docs/ovnkube-trace.md for more details regarding ovnkube-trace utility.

# Available `network-tools` commands

The following part of this file is auto-generated based on commands help.
* `network-tools ovn-db-run-command`

```
This script will find a leader pod (sbdb leader if "sb" substring is found in the command, otherwise nbdb leader),
and then run command inside ovnkube-master container for the found pod.

WARNING! All arguments and flags should be passed in the exact order as they listed below.

Usage: network-tools ovn-db-run-command [-p <pod_name>] [-it] [command]

Options:
  -it:
      to get interactive shell from the leader container use -it flag and empty command.
      WARNING! Don't use -it flag when running network-tools with must-gather.

  -p pod_name:
      use given pod name to run command. Finding a leader can take up to 2*(number of master pods) seconds,
      if you don't want to wait this additional time, add "-p <db_leader_pod_name>" parameter.
      DB leader pod name will be printed for every call without "-p" option, you can use it for the next calls.

Examples:
  network-tools ovn-db-run-command ovn-nbctl show
  network-tools ovn-db-run-command -p ovnkube-master-s7gdz ovn-nbctl show
  network-tools ovn-db-run-command ovn-sbctl dump-flows
  network-tools ovn-db-run-command -it
  network-tools ovn-db-run-command -p ovnkube-master-s7gdz -it

  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- network-tools ovn-db-run-command ovn-nbctl show
  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- network-tools ovn-db-run-command -p ovnkube-master-s7gdz ovn-nbctl show
  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- network-tools ovn-db-run-command ovn-sbctl dump-flows

```
* `network-tools ovn-get`

```
This script can get different ovn-related information.

Usage: network-tools ovn-get [object] [object options]

Supported object:
  leaders - prints ovnk master leader pod, nbdb and sbdb leader pods
  dbs [output directory] - downloads nbdb and sbdb for every master pod. [output directory] is optional

Examples:
  network-tools ovn-get leaders
  network-tools ovn-get dbs ./dbs

  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- network-tools ovn-get leaders
  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- network-tools ovn-get dbs /must-gather

```
* `network-tools ovn-metrics-list`

```
This script collects OVN networking metrics: master, node, and ovn.
If output folder is not specified, local path will be used.

Usage: network-tools ovn-metrics-list [output_folder]

Examples:
  network-tools ovn-metrics-list
  network-tools ovn-metrics-list /some/path/metrics

  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- network-tools ovn-metrics-list /must-gather

```
* `network-tools network-test`

```
Run default debug sequence based on Networking plugin.
Only OpenShiftSDN and OVNKubernetes plugins are supported for now. You can also run all scripts manually and provide
some options.

  Default scripts are:
  * OVNKubernetes = ovn_pod_to_pod_connectivity, ovn_pod_to_svc_connectivity, ovn_ipsec_connectivity
  * OpenshiftSDN = sdn_pod_to_pod_connectivity, sdn_pod_to_svc_connectivity, sdn_cluster_and_node_info

Usage: network-tools network-test

Examples:
  network-tools network-test

  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- network-tools network-test

```
* `network-tools ovn-ipsec-connectivity`

```

This script checks that node2node traffic is encrypted when the ipsec feature
is enabled an Openshift OVN cluster.
By default this script spins up two pods (a client and a server) on two different nodes
in the debug namespace.
It also spins up a host networked debug pod which runs a packet sniffer on all traffic passing between the nodes.

Method: We run a ping from the <src-pod> to <dst-pod>. The debug pod running tcpdump captures the packet
as it transverses the Geneve tunnel across the nodes and ensures the pack is encrypted wth the ESP protocol.
It will also dump the .pcap capture for further analysis to the debug pod regardless of a passing or failing test.

Usage: network-tools ovn-ipsec-connectivity

Examples:
  network-tools ovn-ipsec-connectivity

  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- network-tools ovn-ipsec-connectivity

```
* `network-tools ovn-nic-firmware`

```

This script checks the firmware of Openshift OVN cluster nodes match.
If there is a NIC firmware mismatch, it will show the firmware version mismatch.

Usage: network-tools ovn-nic-firmware

Examples:
  network-tools ovn-nic-firmware

  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- network-tools ovn-nic-firmware

```
* `network-tools ovn-pod-to-pod`

```
This script checks pod2pod connectivity on an Openshift OVN cluster.
By default this script spins up two pods (a client and a server) in the debug namespace.
You can optionally supply the script with a pair of source and destination names.
These can either be the source and destination node names on which the debug pods should be scheduled or
they can be existing pod names (format: <namespace/pod-name>) to run the connectivity test.

NOTE: If existing pods are passed as arguments, make sure ping utility is installed on the <src-pod> pods.

Method: We run a ping from the <src-pod> to <dst-pod>. If ping is not installed on the <src-pod> or if it fails,
we run a ping command from the network namespace of the <src-pod> to <dst-pod> to check connectivity.

If the connectivity test fails, it will run an ovnkube trace between the source and destination pods.

Usage: network-tools ovn-pod-to-pod [src] [dst]

Examples:
  network-tools ovn-pod-to-pod
  network-tools ovn-pod-to-pod <src-node-name> <dst-node-name>
  network-tools ovn-pod-to-pod <src-pod-namespace>/<src-pod-name> <dst-pod-namespace>/<dst-pod-name>
  network-tools ovn-pod-to-pod "" <dst-pod-namespace>/<dst-pod-name>
  network-tools ovn-pod-to-pod <src-pod-namespace>/<src-pod-name>

  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- network-tools ovn-pod-to-pod
  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- network-tools ovn-pod-to-pod <src-node-name> <dst-node-name>
  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- network-tools ovn-pod-to-pod <src-pod-namespace>/<src-pod-name> <dst-pod-namespace>/<dst-pod-name>
  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- network-tools ovn-pod-to-pod \"\" <dst-pod-namespace>/<dst-pod-name>
  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- network-tools ovn-pod-to-pod <src-pod-namespace>/<src-pod-name>

```
* `network-tools ovn-pod-to-svc`

```

This script checks pod2svc connectivity on an Openshift OVN cluster.
By default this script spins up a pod (a client) and a service (a backing-server pod and a clusterIP:port svc)
in debug namespace.
You can optionally supply the script with a pair of source and destination names.
These can either be the source and destination node names on which the debug pods should be scheduled or
they can be existing pod (format: <namespace/pod-name>) and service names (format: <namespace/svc-name>)
to run the connectivity test.

NOTE: If existing pod/svc are passed as arguments, make sure curl utility is installed on the pod and
svc has .spec.clusterIP:80 exposed for testing.

Method: We run a curl from the <src-pod> to <dst-svc-ip>. If curl is not installed on the pod or if it fails,
we run a netcat command from the network namespace of the <src-pod> to <dst-svc-ip> to check connectivity.

If the connectivity test fails, it will run an ovnkube trace between the pod and service.

Usage: network-tools ovn-pod-to-svc [src] [dst]

Examples:
  network-tools ovn-pod-to-svc
  network-tools ovn-pod-to-svc <src-node-name> <dst-node-name>
  network-tools ovn-pod-to-svc <src-pod-namespace>/<src-pod-name> <dst-pod-namespace>/<dst-pod-name>
  network-tools ovn-pod-to-svc "" <dst-pod-namespace>/<dst-pod-name>
  network-tools ovn-pod-to-svc <src-pod-namespace>/<src-pod-name>

  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- network-tools ovn-pod-to-svc
  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- network-tools ovn-pod-to-svc <src-node-name> <dst-node-name>
  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- network-tools ovn-pod-to-svc <src-pod-namespace>/<src-pod-name> <dst-svc-namespace>/<dst-svc-name>
  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- network-tools ovn-pod-to-svc \"\" <dst-svc-namespace>/<dst-svc-name>
  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- network-tools ovn-pod-to-svc <src-pod-namespace>/<src-pod-name>

```
* `network-tools sdn-cluster-info`

```

This script queries and displays some important cluster information:
- nodes, pods, services, endpoints, routers, clusternetwork, hostsubnets, netnamespace
on a SDN cluster.

It also by default spins up a host-network pod on each node in the cluster and grabs the following info:
- interface information, ip a, ip ro, iptables-save, ovs dump-flows, conntrack-dump, ct-stats, crictl ps -v
When run locally it will create must-gather folder in the current directory

Note: If you want the information only from a single node, you can provide that node's name as an argument.

Usage: network-tools sdn-cluster-info [node_name]

Examples:
  network-tools sdn-cluster-info

  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- network-tools sdn-cluster-info

```
* `network-tools sdn-node-connectivity`

```

This script checks the node connectivity on an Openshift SDN cluster from a must-gather pod.
ATTENTION! Can't be run locally

Usage: oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- network-tools sdn-node-connectivity

Examples:
  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- network-tools sdn-node-connectivity

```
* `network-tools sdn-pod-to-pod`

```

This script checks pod2pod connectivity on an Openshift SDN cluster.
By default this script spins up two pods (a client and a server) in the debug namespace.
You can optionally supply the script with a pair of source and destination names.
These can either be the source and destination node names on which the debug pods should be scheduled
or they can be existing pod names (format: <namespace/pod-name>) to run the connectivity test.

Method: We run a ping from the network namespace of the src-pod to the dst-pod to check connectivity.

If the connectivity test fails the script will report failure through logs.

Usage: network-tools sdn-pod-to-pod [src] [dst]

Examples:
  network-tools sdn-pod-to-pod
  network-tools sdn-pod-to-pod <src-node-name> <dst-node-name>
  network-tools sdn-pod-to-pod <src-pod-namespace>/<src-pod-name> <dst-pod-namespace>/<dst-pod-name>
  network-tools sdn-pod-to-pod "" <dst-pod-namespace>/<dst-pod-name>
  network-tools sdn-pod-to-pod <src-pod-namespace>/<src-pod-name>

  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- network-tools sdn-pod-to-pod
  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- network-tools sdn-pod-to-pod <src-node-name> <dst-node-name>
  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- network-tools sdn-pod-to-pod <src-pod-namespace>/<src-pod-name> <dst-pod-namespace>/<dst-pod-name>
  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- network-tools sdn-pod-to-pod \"\" <dst-pod-namespace>/<dst-pod-name>
  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- network-tools sdn-pod-to-pod <src-pod-namespace>/<src-pod-name>

```
* `network-tools sdn-pod-to-svc`

```

This script checks pod2svc connectivity on an Openshift SDN cluster.
By default this script spins up a pod (a client) and a service (a backing-server pod and a clusterIP:port svc)
in the debug namespace.
You can optionally supply the script with a pair of source and destination names.
These can either be the source and destination node names on which the debug pods should be scheduled or
they can be existing pod (format: <namespace/pod-name>) and service names (format: <namespace/svc-name>)
to run the connectivity test.

Method: We run a netcat command from the network namespace of the src-pod to each of the endpoints and
dst-svc-ip to check connectivity.

If the connectivity test fails the script will report failure through logs.

Usage: network-tools sdn-pod-to-svc [src] [dst]

Examples:
  network-tools sdn-pod-to-svc
  network-tools sdn-pod-to-svc <src-node-name> <dst-node-name>
  network-tools sdn-pod-to-svc <src-pod-namespace>/<src-pod-name> <dst-pod-namespace>/<dst-pod-name>
  network-tools sdn-pod-to-svc "" <dst-pod-namespace>/<dst-pod-name>
  network-tools sdn-pod-to-svc <src-pod-namespace>/<src-pod-name>

  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- network-tools sdn-pod-to-svc
  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- network-tools sdn-pod-to-svc <src-node-name> <dst-node-name>
  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- network-tools sdn-pod-to-svc <src-pod-namespace>/<src-pod-name> <dst-svc-namespace>/<dst-svc-name>
  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- network-tools sdn-pod-to-svc \"\" <dst-svc-namespace>/<dst-svc-name>
  oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest -- network-tools sdn-pod-to-svc <src-pod-namespace>/<src-pod-name>

```
* `network-tools ci-artifacts-get`

```
Download ci prow job artifacts.

ATTENTION! This is local command, can't be used with must-gather.
ATTENTION! You need gsutil [https://cloud.google.com/storage/docs/gsutil_install] installed.

Usage: network-tools ci-artifacts-get [-v] prowjob_url dest_path

Examples:
  network-tools ci-artifacts-get https://prow.ci.openshift.org/view/gs/origin-ci-test/pr-logs/pull/26359/pull-ci-openshift-origin-master-e2e-aws-single-node/1422822145540493312 ./

```
* `network-tools ovn-db-run-locally`

```
Run ovn-kubernetes container with ovn db restored from a given file.
You will get interactive pseudo-TTY /bin/bash running in created container,
after you end bash session (use Ctrl+D) container will be removed.

The script will wait max 10 seconds for ovn db to start,
if ovndb status is not active you will get warning message.

ATTENTION! For clustered dbs: db will be converted from cluster to standalone format
as this is the only way to run db from gathered data. Db UUIDs will be preserved.

ATTENTION! This is local command, can't be used with must-gather.

Usage: network-tools ovn-db-run-locally raw_db_file ovn_db_type [-e {docker,podman}]
  raw_db_file: db file from must-gather
  ovn_db_type: n for 'n' for northbound db, 's' for southbound db
  -e {docker,podman}: choose container engine to use. Default is docker

Examples:
  network-tools ovn-db-run-locally ./must-gather.local.8470413320584178988/quay-io-npinaeva-must-gather-sha256-48826a17ba08cf1ef1e27a7b85fdff459efb8fc5807c26cdb525eecbfb0ec6a3/network_logs/leader_nbdb n

```
* `network-tools ovn-pprof-forwarding`

```
This script enables port forwarding to make pprof endpoints for ovnkube containers available on localhost.
It checks all connections every 60 sec and stops if at least one fails (it can happen if some pod was deleted).
In this case just run this script again and it will use new pods.
The output will show local port for every pod, then you can find pprof web interface at localhost:<pod port>/debug/pprof,
and collect e.g. cpu profile with

curl http://localhost:<pod port>/debug/pprof/profile?seconds=<duration>

ATTENTION! This is local command, can't be used with must-gather.

Usage: network-tools ovn-pprof-forwarding

Examples:
  network-tools ovn-pprof-forwarding

```
