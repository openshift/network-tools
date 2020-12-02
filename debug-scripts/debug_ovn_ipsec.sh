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
    image: docker.io/centos/tools:latest
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
    image: docker.io/centos/tools:latest
    command:
      - /sbin/init
  nodeSelector:
    use: {{NODE_SELECTOR_LABEL}}
EOF
    fi
}


do_ovn_ipsec_encryption_check () {
    echo "INFO: Ensuring ovn-ipsec is enabled"
    IPSEC_PODS=($(oc -n openshift-ovn-kubernetes get pods -l app=ovn-ipsec -o=jsonpath='{.items[*].metadata.name}'))
    WORKER_NODES=($(oc get nodes --selector='!node-role.kubernetes.io/master' -o jsonpath='{range .items[*]}{@.metadata.name} {.status.nodeInfo.operatingSystem==linux}'))
    DEBUG_NETWORK_NAMESPACE="openshift-debug-network-"$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 5 | head -n 1)
    PCAP_FILENAME="ipsec-test-"$(date +"%Y-%m-%d")".pcap"
    
    # TODO check with oc get network.operator.openshift.io/cluster -o=jsonpath='{.items[*].spec.defaultNetwork.ovnKubernetesConfig.ipsecConfig}' 
    # once tests can be run with real cluster 
    if [-z "$IPSEC_PODS"]; then
        echo "No ovn-ipsec pods exist, tunnel traffic will be unencrypted --> see $PCAP_FILENAME"
    else 
        echo "ovn-ipesec is enabled, tunnel traffic should be encryted --> see ${PCAP_FILENAME}"   
    fi 

    echo "ovn-ipsec is enabled"

    echo "making debug namespace: ${DEBUG_NETWORK_NAMESPACE}"

    oc create namespace "${DEBUG_NETWORK_NAMESPACE}"

    create_pod "client-debug" "${DEBUG_NETWORK_NAMESPACE}" "${WORKER_NODES[0]}" 
    create_pod "server-debug" "${DEBUG_NETWORK_NAMESPACE}" "${WORKER_NODES[0]}"

    server_debug_pod_ip=$(oc get pods -n openshift-debug-network server-debug -o-o=jsonpath={.status.podIP})

    #start sniffer in background, but only look for packets going over the tunnel from node1 -> node2 
    tcpdump -i eth0 -vv -c 2 -w ${PCAP_FILENAME} src $(kubectl get node ${${WORKER_NODES[0]}} \
    -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}') \
    && dst $(kubectl get node ${${WORKER_NODES[0]}} \
    -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}')

    oc rsh -n $DEBUG_NETWORK_NAMESPACE client-debug ping $server_debug_pod_ip -c 1 -W 2 &> /dev/null

    if [-f "${PCAP_FILENAME}"]; then 
        if tshark -r out.pcap -T fields -e frame.protocols | grep -q "esp"; then 
            echo "Tunnel traffic is encrypted with ovn-ipsec!"
        else 
            echo "Tunner traffic is not encrypted, check pcap: ${PCAP_FILENAME} for further details"
        fi
    else
        echo "tcpdump error ${PCAP_FILENAME} wasn't written" 
    fi
}




main () {
    if [ -z "$KUBECONFIG" -o ! -f "$KUBECONFIG" ]; then
        die "KUBECONFIG is unset or incorrect"
    else
        do_ovn_ipsec_encryption_check
    fi
}

main