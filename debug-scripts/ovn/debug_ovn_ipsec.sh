#!/bin/bash

set -eoux pipefail

#TODO: move this function to a common place 
create_pod () {

    POD_NAME=${1}
    DEBUG_NETWORK_NAMESPACE=${2}
    NODE_SELECTOR_LABEL=${3}

    if [ -z "$NODE_SELECTOR_LABEL" ]; then
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
    image: quay.io/astoycos/debug-network:latest
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
    image: quay.io/astoycos/debug-network:latest
    command:
      - /sbin/init
  nodeSelector:
    kubernetes.io/hostname: {{NODE_SELECTOR_LABEL}}
EOF
    fi
}

do_ovn_ipsec_encryption_check () {
    echo "INFO: Ensuring ovn-ipsec is enabled"
    IPSEC_PODS=($(oc -n openshift-ovn-kubernetes get pods -l app=ovn-ipsec -o=jsonpath='{.items[*].metadata.name}'))
    WORKER_NODES=($(oc get nodes --selector='!node-role.kubernetes.io/master' -o jsonpath='{range .items[*]}{@.metadata.name} {.status.nodeInfo.operatingSystem==linux}'))
    RANDOM=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 5 | head -n 1) ||
    DEBUG_NETWORK_NAMESPACE="openshift-debug-network-${RANDOM}"
    DATE=$(date +"%Y-%m-%d")
    PCAP_FILENAME="ipsec-test-${DATE}.pcap"
        
    # TODO check with oc get network.operator.openshift.io/cluster -o=jsonpath='{.items[*].spec.defaultNetwork.ovnKubernetesConfig.ipsecConfig}' 
    # once tests can be run with real cluster 
    if [ -z "$IPSEC_PODS" ]; then
        echo "No ovn-ipsec pods exist, tunnel traffic will be unencrypted --> see $PCAP_FILENAME"
    else 
        echo "ovn-ipsec is enabled, tunnel traffic should be encryted --> see ${PCAP_FILENAME}"   
    fi 

    echo "ovn-ipsec is enabled"

    echo "making debug namespace: ${DEBUG_NETWORK_NAMESPACE}"

    oc create namespace "${DEBUG_NETWORK_NAMESPACE}"

    create_pod "client-debug" "${DEBUG_NETWORK_NAMESPACE}" "${WORKER_NODES[0]}" 
    create_pod "server-debug" "${DEBUG_NETWORK_NAMESPACE}" "${WORKER_NODES[1]}"

    kubectl wait -n "${DEBUG_NETWORK_NAMESPACE}" --for=condition=Ready pod/client-debug  --timeout=30s
    kubectl wait -n "${DEBUG_NETWORK_NAMESPACE}" --for=condition=Ready pod/server-debug  --timeout=30s

    server_debug_pod_ip=$(oc get pods -n "${DEBUG_NETWORK_NAMESPACE}" server-debug -o=jsonpath={.status.podIP})
    
    echo "INFO: make sure interface eth0 exists"

    if ip link list | grep -q eth0 ; then 
        echo "INFO: interface eth0 exists!"
        interface="eth0"
    else 
        echo "INFO: interface eth0 is not up sniff on all interfaces"
        interface="any"
    fi

    echo "INFO: packet sniffing command is: tcpdump -i ${interface} -vv -c 2 -w ${PCAP_FILENAME} src \
    $(kubectl get node "${WORKER_NODES[0]}" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}') \
    && dst $(kubectl get node "${WORKER_NODES[1]}" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')"

    #start sniffer in background, but only look for packets going over the tunnel from node1 -> node2 
    
    timeout 30s  tcpdump -i ${interface} -vv -c 2 -w "${PCAP_FILENAME}" \
    src "$(kubectl get node "${WORKER_NODES[0]}" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')" and dst "$(kubectl get node "${WORKER_NODES[1]}" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')" \
    & PID=$!

    echo "INFO: pinging server from client pod: oc rsh -n ${DEBUG_NETWORK_NAMESPACE} client-debug ping oc rsh -n ${DEBUG_NETWORK_NAMESPACE} client-debug ping ${server_debug_pod_ip} -c 5 -W 2"    

    oc rsh -n "${DEBUG_NETWORK_NAMESPACE}" client-debug ping "${server_debug_pod_ip}" -c 10 -W 2 > /dev/null 2>&1
    
    wait "${PID}"

    if [ -f "${PCAP_FILENAME}" ]; then 
        if tshark -r "${PCAP_FILENAME}" -T fields -e frame.protocols | grep -q "esp"; then 
            echo "Tunnel traffic is encrypted with ovn-ipsec!"
        else 
            echo "Tunnel traffic is not encrypted, check pcap: ${PCAP_FILENAME} for further details"
        fi
    else
        echo "tcpdump error ${PCAP_FILENAME} wasn't written" 
    fi

    echo "INFO: Cleaning up debug namespace"

    oc delete namespace "${DEBUG_NETWORK_NAMESPACE}"
}

main () {
    #TODO A better way of ensuring we can contact the API Server, serivce accounts 
    do_ovn_ipsec_encryption_check
}

main
