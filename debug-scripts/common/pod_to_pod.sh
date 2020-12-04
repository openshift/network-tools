#!/bin/bash
set -eu
set -o pipefail

make_debug_ns(){
  local ns=oc-debug-network-$(date '+%s')
  if oc new-project ${ns} >/dev/null ; then
    echo ${ns}
  else
   echo FATAL: Unable to create debug namepsace ${ns}
   exit 1
  fi
}

verify_server_socket(){
  # Many pods will not have either ss or netstat, so use procfs to figure out
  # the sockets instead
  if oc rsh ${SERVER_POD} cat /proc/net/tcp |
       awk '{print $2}' |
       grep -q "00000000:$(printf '%X' "${PORT}")"; then 
    echo socket listening on 0.0.0.0:${PORT}
    return true 
  elif oc rsh ${SERVER_POD} cat /proc/net/tcp6 |
         awk '{print $2}' |
         grep -q "00000000000000000000000000000000:$(printf '%X' ${PORT})"; then
    echo socket listening on *:${PORT}
    return true
  else
    echo WARN: Possible error: Port not listening or listening in an unexpected address. Expected 0.0.0.0:${PORT} or *:${PORT}.
  fi 
}

get_pod_ip(){
  local pod="${1}"
  oc get pod "${pod}" \
    -o template \
    --template '{{.status.podIP}}{{"\n"}}'
}

get_pod_net_ns(){
  local pod="${1}"
  if ! oc debug \
         node/$(get_pod_node "${pod}")  \
         -- chroot /host bash -c \
         "pod_id=$(crictl pods --namespace ${POD_NAMESPACE} --name ${pod} -q)
          runc state $pod_id | jq .pid"
  then
    echo FATAL: Unable to get ${client} pod sandbox net namespace. Aborting the test.
    oc delete project "${DEBUG_NAMESPACE}"
    exit 1
  fi  
}

test_connectivity(){
  local client="${1}"
  local server="${2}"
  local port="${3}"
  local kind="${4}"
  local node="$(get_pod_node ${client})"
  
  # We don't care about--stdin but --tty requires --stdin
  if oc run client \
       --image="${TEST_IMAGE}" \
       --namespace "${TEST_NAMESPACE}" \
       --stdin --tty \
       --overrides='{"kind":"Pod", "apiVersion":"v1", "spec": {"hostNetwork": true}}'
       --restart Never
       --command nsenter -n -t "$(get_net_ns client)" -- nc -z -w 2 "${server}" "${port}"
  then
    echo SUCCESS: ${kind} pod ${client} established a TCP connection successfully against ${server}:${port}
  else
    echo FAIL: ${kind} pod ${client} unable to establish a TCP connection successfully against ${server}:${port}
  fi
}


get_pod_node(){
  local pod="${1}"
  oc get pod -n "${POD_NAMESPACE}" "${pod}" \
    -o template \
    --template '{{.spec.nodeName }}'
}

TEST_IMAGE="docker.io/centos/tools:latest"
CLIENT_POD="${1}"
SERVER_POD="${2}"
PORT="${3}"

POD_NAMESPACE="$(oc project -q)"
DEBUG_NAMESPACE="$(make_debug_ns)"
SERVER_IP=$(get_pod_ip "${SERVER_POD}")

test_connectivity "${CLIENT_POD}" "${SERVER_IP}" "${PORT}" "client"
test_connectivity "${CLIENT_POD}" "${SERVER_IP}" "${PORT}" "server"
verify_server_socket 

oc delete project "${DEBUG_NAMESPACE}"
