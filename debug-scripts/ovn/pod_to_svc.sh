#!/bin/bash

create_pod () {

    POD_NAME=${1}
    DEBUG_NETWORK_NAMESPACE=${2}

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
}

create_svc () {
    SVC_NAME=${1}
    DEBUG_NETWORK_NAMESPACE=${2}

    create_pod $SVC_NAME $DEBUG_NETWORK_NAMESPACE
    oc wait -n $DEBUG_NETWORK_NAMESPACE --for=condition=Ready pod/$SVC_NAME --timeout=10m
    # start webserver and expose the port
    oc rsh -n $DEBUG_NETWORK_NAMESPACE $SVC_NAME systemctl start nginx
    oc expose -n $DEBUG_NETWORK_NAMESPACE pod/$SVC_NAME --port=80
}

do_pod_to_svc_connectivity_check () {

    # create a debug-network namespace
    DEBUG_NETWORK_NAMESPACE="openshift-debug-network"-$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 5 | head -n 1)
    oc create namespace $DEBUG_NETWORK_NAMESPACE

    debug_pod="debug-pod"-$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 5 | head -n 1)
    debug_svc="debug-svc"-$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 5 | head -n 1)

    # create a pod and svc
    create_pod $debug_pod $DEBUG_NETWORK_NAMESPACE
    create_svc $debug_svc $DEBUG_NETWORK_NAMESPACE

    # wait till pod is running and svc endpoint is created
    oc wait -n $DEBUG_NETWORK_NAMESPACE --for=condition=Ready pod/$debug_pod --timeout=10m
    while [[ $(oc get ep -n $DEBUG_NETWORK_NAMESPACE $debug_svc -o 'jsonpath={.subsets[0].addresses[0].ip}') == "" ]]; do echo "waiting for svc" && sleep 1; done

    debug_svc_ip=$(oc get svc -n $DEBUG_NETWORK_NAMESPACE $debug_svc -o 'jsonpath={.spec.clusterIP}')

    # rsh into the client pod and curl the svc
    curl_output=$(oc rsh -n $DEBUG_NETWORK_NAMESPACE $debug_pod curl -sL -w "%{http_code}" "http://$debug_svc_ip:80" -o /dev/null --connect-timeout 3 --max-time 5)
    if [ $curl_output == "200" ]; then
        echo "curl http://$debug_svc_ip:80  ->  success"
    else
        echo "curl http://$debug_svc_ip:80  ->  failed"
        # incorportate the logic to use ovnkube-trace to output the ovn/ovs trace
        echo "Something is wrong, running the ovnkube-trace and detrace to help figure out the packet route..."
        # [TODO]: Once ovnkube-trace is packed in oc, we can start using it directly and cleanup the nonsense from the below lines.
        git clone https://github.com/ovn-org/ovn-kubernetes.git && \
        pushd ovn-kubernetes/go-controller && make && \
        _output/go/bin/ovnkube-trace --tcp --dst-port 80  --src $debug_pod --service $debug_svc -dst-namespace $DEBUG_NETWORK_NAMESPACE -src-namespace $DEBUG_NETWORK_NAMESPACE --loglevel=5
        popd && rm -rf ovn-kubernetes
    fi

    # delete debug-network namespace
    oc delete namespace $DEBUG_NETWORK_NAMESPACE
}

help()
{
   # Display Help
   echo
   echo "This script checks pod2svc connectivity on an OVN cluster. The script assumes a KUBECONFIG is mounted at /tmp/kubeconfig.
By default this script spins up a pod and service in the openshift-debug-network-* namespace.
"
   echo
   echo "Usage: oc rsh -n <DEBUG-NETWORK-NAMESPACE> <debug-network-podname> ./usr/bin/debug-network-scripts/ovn/pod_to_svc.sh "
   echo "or"
   echo "podman run -v /tmp/kubeconfig:/tmp/kubeconfig <IMAGE_ID> ./usr/bin/debug-network-scripts/ovn/pod_to_svc.sh "
   echo
}

main () {

    help

    export KUBECONFIG=/tmp/kubeconfig
    if [ -z "$KUBECONFIG" -o ! -f "$KUBECONFIG" ]; then
        echo "KUBECONFIG is unset or incorrect or not found"
    else
        echo "Found kubeconfig file at $KUBECONFIG"
        do_pod_to_svc_connectivity_check
    fi
}

main
