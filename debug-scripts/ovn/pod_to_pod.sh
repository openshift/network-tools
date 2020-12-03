#!/bin/bash

create_pod () {

    POD_NAME=${1}
    DEBUG_NETWORK_NAMESPACE=${2}
    NODE_SELECTOR_LABEL=${3}

    if [ -z $NODE_SELECTOR_LABEL ]; then
        cat <<EOF | sed "s/{{POD_NAME}}/$POD_NAME/g" | sed "s/{{DEBUG_NETWORK_NAMESPACE}}/$DEBUG_NETWORK_NAMESPACE/g" | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: {{POD_NAME}}
  namespace: {{DEBUG_NETWORK_NAMESPACE}}
  labels:
    pod-name: {{POD_NAME}}
spec:
  containers:
  - name: {{POD_NAME}}
    image: registry.svc.ci.openshift.org/ocp/4.7:ocp-debug-network
    command:
      - /sbin/init
EOF
    else
        cat <<EOF | sed "s/{{POD_NAME}}/$POD_NAME/g" | sed "s/{{DEBUG_NETWORK_NAMESPACE}}/$DEBUG_NETWORK_NAMESPACE/g" | sed "s/{{NODE_SELECTOR_LABEL}}/$NODE_SELECTOR_LABEL/g" | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: {{POD_NAME}}
  namespace: {{DEBUG_NETWORK_NAMESPACE}}
  labels:
    pod-name: {{POD_NAME}}
spec:
  containers:
  - name: {{POD_NAME}}
    image: registry.svc.ci.openshift.org/ocp/4.7:ocp-debug-network
    command:
      - /sbin/init
  nodeSelector:
    use: {{NODE_SELECTOR_LABEL}}
EOF
    fi
}

do_pod_to_pod_connectivity_check () {

    src_node=${1}
    dst_node=${2}

    # create a debug-network namespace
    DEBUG_NETWORK_NAMESPACE="openshift-debug-network"-$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 5 | head -n 1)
    oc create namespace $DEBUG_NETWORK_NAMESPACE

    client_debug_pod="client-debug"-$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 5 | head -n 1)
    server_debug_pod="server-debug"-$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 5 | head -n 1)

    # create two pods
    if [ -z $src_node ] && [ -z $dst_node]; then
        create_pod $client_debug_pod $DEBUG_NETWORK_NAMESPACE
        create_pod $server_debug_pod $DEBUG_NETWORK_NAMESPACE
    else
        oc label nodes $src_node "use=client-pod"
        oc label nodes $dst_node "use=server-pod"
        create_pod $client_debug_pod $DEBUG_NETWORK_NAMESPACE "client-pod"
        create_pod $server_debug_pod $DEBUG_NETWORK_NAMESPACE "server-pod"
    fi

    # wait till pods are running
    oc wait -n $DEBUG_NETWORK_NAMESPACE --for=condition=Ready pod/$client_debug_pod --timeout=10m
    oc wait -n $DEBUG_NETWORK_NAMESPACE --for=condition=Ready pod/$server_debug_pod --timeout=10m

    client_debug_pod_ip=$(oc get pods -n $DEBUG_NETWORK_NAMESPACE $client_debug_pod -o jsonpath={.status.podIP})
    server_debug_pod_ip=$(oc get pods -n $DEBUG_NETWORK_NAMESPACE $server_debug_pod -o jsonpath={.status.podIP})
    
    # rsh into the client pod and ping the server
    if oc rsh -n $DEBUG_NETWORK_NAMESPACE $client_debug_pod ping $server_debug_pod_ip -c 1 -W 2 &> /dev/null; then
        echo "ping $server_debug_pod_ip  ->  success"
    else
        echo "ping $server_debug_pod_ip  ->  failed"
        echo "Running traceroute from client pod to server pod:"
        oc rsh -n $DEBUG_NETWORK_NAMESPACE $client_debug_pod traceroute $server_debug_pod_ip -m 10
        # incorportate the logic to use ovnkube-trace to output the ovn/ovs trace 
        echo "Something is wrong, running the ovnkube-trace and detrace to help figure out the packet route..."
        # [TODO]: Once ovnkube-trace is packed in oc, we can start using it directly and cleanup the nonsense from the below lines.
        git clone https://github.com/ovn-org/ovn-kubernetes.git && \
        pushd ovn-kubernetes/go-controller && make && \
        _output/go/bin/ovnkube-trace --tcp --dst-port 80  --src $client_debug_pod --dst $server_debug_pod -dst-namespace $DEBUG_NETWORK_NAMESPACE -src-namespace $DEBUG_NETWORK_NAMESPACE --loglevel=5
        popd && rm -rf ovn-kubernetes
    fi

    # delete debug-network namespace
    oc delete namespace $DEBUG_NETWORK_NAMESPACE
}

help()
{
   # Display Help
   echo
   echo "This script checks pod2pod connectivity on an OVN cluster. The script assumes a KUBECONFIG is mounted at /tmp/kubeconfig.
By default this script spins up two pods (a client and a server) in the openshift-debug-network-* namespace. You can optionally
supply the script with source and destination node names on which the pods should be scheduled.
"
   echo
   echo "Usage: oc rsh -n <DEBUG-NETWORK-NAMESPACE> <debug-network-podname> ./usr/bin/debug-network-scripts/ovn/pod_to_pod.sh  <src-node-name> <dst-node-name>"
   echo "or"
   echo "podman run -v /tmp/kubeconfig:/tmp/kubeconfig <IMAGE_ID> ./usr/bin/debug-network-scripts/ovn/pod_to_pod.sh"
   echo
}

main () {

    help

    export KUBECONFIG=/tmp/kubeconfig
    if [ -z "$KUBECONFIG" -o ! -f "$KUBECONFIG" ]; then
        echo "KUBECONFIG is unset or incorrect or not found"
    else
        echo "Found kubeconfig file at $KUBECONFIG"
        do_pod_to_pod_connectivity_check $src_node_name $dst_node_name
    fi
}

src_node_name=$1
dst_node_name=$2

main
