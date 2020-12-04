#!/bin/bash
set -eu
set -o pipefail

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

test_sdn(){
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


if [[ ${#} == "0" ]] ; 
POD="${1}"
SVC="${2}"
CONTAINER_PID="$(get_container_pid)"
NSE="nsenter -n -t ${CONTAINER_PID}"
test_sdn
