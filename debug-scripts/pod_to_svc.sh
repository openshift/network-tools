#!/bin/bash
set -eu
set -o pipefail


get_container_pid(){
  local cid=$(oc get pod "${POD}" -o template --template \
             '{{range .status.containerStatuses}}{{if .state.running }}{{.containerID}}{{"\n"}}{{end}}{{end}}' |
             head -1 )

  if [[ -z $cid ]] ; then
    echo "FATAL: The container doesn't have any container running. Cannot complete the test"
    exit 1
  fi

  if [[ "${cid}" =~ 'cri-o://' ]]; then
    chroot /host crictl inspect -o go-template --template '{{.info.pid}}' $(echo "${cid}" | cut -d/ -f3)
  elif [[ "${cid}" =~ 'docker://' ]]; then
    chroot /host docker inspect --format '{{.State.Pid}}'
  else
    echo Unknown container engine, expecting docker or cri-o and the contianer id is: "${cid}"
  fi;
}


svc_ports(){
  # Only lists ports if they are TCP.
  oc get svc "${SVC}" \
    -o template \
    --template \
    '{{ range .spec.ports }}{{if eq .protocol "TCP"}}{{ .port }}{{ "\n" }}{{end}}{{end}}'
}

test_svc(){
  local attempts="$(( $(ep_len "${SVC}") * 10 ))"
  # Don't depend on DNS so that we can run test it outside the pod's namespace.
  local ip=$(oc get svc "${SVC}" -o template --template '{{.spec.clusterIP}}')
  for port in $(svc_ports); do
    for i in $(seq "${attempts}"); do
      if ! ${NSE} nc -z "${ip}" "${port}"; then
        echo FAIL: Unable to open TCP socket to service "${SVC}" on "${ip}":"${port}" after "${i}" attempts.
        return
      fi
    done
  done

  echo SUCCESS: Succesfully reached service ${SVC} ${attempts} times on every port.
}

ep_ports(){
  # Only lists ports if they are TCP.
  oc get ep "${SVC}" \
    -o template \
    --template \
    '{{with $s := index .subsets 0}}{{ range $p := $s.ports }}{{if eq $p.protocol "TCP"}}{{ $p.port }}{{ "\n" }}{{end}}{{end}}{{end}}'
}

ep_ips(){
  oc get ep "${SVC}" \
    -o template \
    --template \
    '{{with $s := index .subsets 0}}{{ range $s.addresses }}{{.ip}}{{"\n"}}{{end}}{{end}}'
}

ep_len(){
  oc get ep "${SVC}" \
    -o template \
    --template \
    '{{with $s := index .subsets 0}}{{ len $s.addresses }}{{"\n"}}{{end}}'
}

test_ep(){
  local success=$(true)
  for ip in $(ep_ips); do
    for port in $(ep_ports); do
      if ! ${NSE} nc -z "${ip}" "${port}" ; then
        echo FAIL: Unable to open TCP socket to "${ip}":"${port}".
        sucess=$(false)
      fi
    done
  done
  if [[ success ]]; then
    echo SUCCESS: Tested all TCP endpoints correctly
  fi
}

is_sdn(){
# not elegant at all, but works with both OCP 3 and 4.
  oc get clusternetwork  default -o template --template '{{.pluginName}}{{"\n"}}' 2>/dev/null |
    grep -q redhat/openshift-ovs-
}

is_ovn(){
  [[ $(oc get networks.config.openshift.io cluster -o template --template '{{.spec.networkType}}') == "OVNKubernetes" ]] 
}

# Expects $1 to be in the format that oc get -o name outputs
sdn_underlay_ip(){
  oc get "${1}" -o template --template '{{.hostIP}}'
}

# Expects $1 to be in the format that oc get -o name outputs
sdn_overlay_ip(){
  local subnet=$(oc get "${1}" -o template --template '{{.subnet}}')

  # Subnet addresses always have by definition the last byte set to zero.
  # This means we can assume the last number of the address will always be
  # even, so for all we care we only need to handle '[02468]/[012]?[0-9]$'.
  echo "${subnet}" |  sed -E \
  -e 's@8/([012])?[0-9]$@9@' \
  -e 's@6/([012])?[0-9]$@7@' \
  -e 's@4/([012])?[0-9]$@5@' \
  -e 's@2/([012])?[0-9]$@3@' \
  -e 's@0/([012])?[0-9]$@1@'
}

test_sdn_nodes(){
  for node in $(oc get hostsubnet -o name); do
    local success=overlay
    if ! ping $(sdn_overlay_ip "${node}") -w 2 -W 1 2>&1 >/dev/null ; then
      sucess=underlay
      if ! ping $(sdn_underlay_ip "${node}") -w 2 -W 1 2>&1 >/dev/null ; then
	success=no
      fi
    fi
    if [[ "${success}" == "overlay" ]]; then
      echo SUCCESS: Can ping ${node} on the overlay
    elif [[ "${success}" == "underlay" ]]; then
      echo FAIL: Cannot ping ${node} on the overlay but can reach it on the underlay.
    else
      echo FAIL: Cannot ping ${node} on the overlay or the underlay.
    fi

  done
}

test_ovn_nodes(){
  #TODO
  :
}


test_nodes(){
  if is_sdn ; then
    test_sdn_nodes
  elif [[ $(is_ovn) ]]; then
    test_ovn_nodes
  else
    echo Unable to test node connectivity. Only openshift-sdn and ovn-kubernetes are supported
  fi;
}

POD="${1}"
SVC="${2}"
CONTAINER_PID="$(get_container_pid)"
NSE="nsenter -n -t ${CONTAINER_PID}"
test_svc
test_ep
test_nodes
