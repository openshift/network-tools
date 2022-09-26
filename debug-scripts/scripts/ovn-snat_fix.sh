#! /bin/bash
#
## Temporary checking and cleaning of stale SNAT entries
#
set -eo pipefail

# First check if cluster is 4.10
get_clusterversion() {
  oc get clusterversion/version -o jsonpath='{.status.desired.version}'
}

# To simplify let's check the ovn_nbdb leader and commands to use in OVNkube-master pod
get_ovnnbdb_leader() {
  for MASTER_POD in $(oc -n openshift-ovn-kubernetes get pods -l app=ovnkube-master -o=jsonpath='{.items[*].metadata.name}'); do
	RAFT_ROLE=$(oc exec -n openshift-ovn-kubernetes "${MASTER_POD}" -c nbdb -- bash -c "ovn-appctl -t /var/run/ovn/ovnnb_db.ctl cluster/status OVN_Northbound 2>&1 | grep \"^Role\"")
   	if echo "${RAFT_ROLE}" | grep -q -i leader; then
     		LEADER=$MASTER_POD
     		break
   	fi
 done
 echo "${LEADER}"
}

OVNKMASTER=$(get_ovnnbdb_leader)

# Main OVN commands needed
find_podip() {
  oc -n openshift-ovn-kubernetes rsh -Tc northd $OVNKMASTER ovn-nbctl --columns=logical_ip find nat external_ip="$NODEIP"
}

find_nats() {
  oc -n openshift-ovn-kubernetes rsh -Tc northd $OVNKMASTER ovn-nbctl --columns=_uuid find nat external_ip="$NODEIP"
}

find_nat_podip() {
  oc -n openshift-ovn-kubernetes rsh -Tc northd $OVNKMASTER ovn-nbctl --columns=_uuid,logical_ip find nat external_ip="$NODEIP"
}

find_nat_nodeip() {
  oc -n openshift-ovn-kubernetes rsh -Tc northd $OVNKMASTER ovn-nbctl --columns=_uuid,external_ip find nat external_ip="$NODEIP"
}

find_nat_per_podip() {
  oc -n openshift-ovn-kubernetes rsh -Tc northd $OVNKMASTER ovn-nbctl --columns=_uuid find nat logical_ip="$PODIP"
}

del_nats() {
  oc -n openshift-ovn-kubernetes rsh -Tc northd $OVNKMASTER ovn-nbctl remove logical_router GR_"$LR" nat "$UUID"
}

# Getting OVN node-subnets, nodeName and nodeIP
get_nodesubnet() {
  oc describe node $LR | egrep "k8s.ovn.org/node-subnets\:" | awk '{print $2}' | tr -d '{}' | egrep '"default"' | cut -d':' -f2 | tr -d '""'
}

get_nodeip() {
  oc describe node $LR | grep "InternalIP\:" | awk '{print $2}'
}

get_nodename() {
  oc get nodes -o=custom-columns=NAME:.metadata.name --no-headers
}

get_hostprefix() {
  oc get network cluster -o jsonpath='{.spec.clusterNetwork[0].hostPrefix}'
}

function int_ip() {
    OIFS=$IFS
    IFS='.'
    ip=($1)
    IFS=$OIFS
    echo "${ip[0]} * 256 ^ 3 + ${ip[1]} * 256 ^ 2 + ${ip[2]} * 256 ^ 1 + ${ip[3]} * 256 ^ 0" | bc
}

# Compare Node ovn-subnet and respective NATs for simplicity
# Do it in several steps so we end up with the output we need to start the clean up
get_subnet_prefix() {
  NODESUBNET=$(get_hostprefix) ;
  if [[ "$NODESUBNET" == "24" ]]; then
    echo "Subnet is $NODESUBNET" ;
    compare_podip_to_subnet_24
  elif [[ "$NODESUBNET" == "23" ]]; then
    echo "Subnet is $NODESUBNET" ;
    compare_podip_to_subnet_23
  elif [[ "$NODESUBNET" == "22" ]]; then
    echo "Subnet is $NODESUBNET" ;
    compare_podip_to_subnet_22
  fi
}

compare_podip_to_subnet_24() {
  for LR in $(get_nodename); do
    natpodipfile=$(mktemp -t nat-podip.XXX --suffix .$LR) ;
    SUBNET=$(get_nodesubnet | sed 's/\.[^.]*$//') ;
    for NODEIP in $(get_nodeip); do
      find_nat_podip | grep -v $SUBNET >> $natpodipfile ;
      sleep 1;
    done
  done
  get_stale_nats
}

compare_podip_to_subnet_23() {
  for LR in $(get_nodename); do
    nodepodipfile=$(mktemp -t podip-node.XXX --suffix .$LR) ;
    for SUBNETBIT in $(get_nodesubnet | awk -F. -v OFS=. '{print $3}'); do
      NEXTSUBNET=$(($SUBNETBIT + 1)) ;
      MINADDR=$(get_nodesubnet | awk -F. -v OFS=. '{print $1, $2, $3}').1 ;
      MAXADDR=$(get_nodesubnet | awk -F. -v OFS=. '{print $1, $2}')."$NEXTSUBNET".254 ;
      for NODEIP in $(get_nodeip); do
        for PODIP in $(find_podip | awk -F: '{print $2}' | tr -d '""'); do
          HOSTMIN=$(int_ip ${MINADDR}) ;
          HOSTMAX=$(int_ip ${MAXADDR}) ;
          IPINT=$(int_ip ${PODIP}) ;
          if ! [[ ${IPINT} -le ${HOSTMAX} && ${IPINT} -ge ${HOSTMIN} ]]; then
            echo "IP: $PODIP - Node: $LR. Out of range" >> $nodepodipfile
            continue
          else
            echo "IP $PODIP is in Range on Node $LR"
            continue
          fi
        done
      done
    done
  done
  match_stale_nats
}

compare_podip_to_subnet_22() {
  for LR in $(get_nodename); do
    nodepodipfile=$(mktemp -t podip-node.XXX --suffix .$LR) ;
	  for SUBNETBIT in $(get_nodesubnet | awk -F. -v OFS=. '{print $3}'); do
		  NEXTSUBNET=$(($SUBNETBIT + 3)) ;
		  MINADDR=$(get_nodesubnet | awk -F. -v OFS=. '{print $1, $2, $3}').1 ;
    	MAXADDR=$(get_nodesubnet | awk -F. -v OFS=. '{print $1, $2}')."$NEXTSUBNET".254 ;
		  for NODEIP in $(get_nodeip); do
			  for PODIP in $(find_podip | awk -F: '{print $2}' | tr -d '""'); do
				  HOSTMIN=$(int_ip ${MINADDR}) ;
          HOSTMAX=$(int_ip ${MAXADDR}) ;
          IPINT=$(int_ip ${PODIP}) ;
          if ! [[ ${IPINT} -le ${HOSTMAX} && ${IPINT} -ge ${HOSTMIN} ]]; then
            echo "IP: $PODIP - Node: $LR. Out of range" >> $nodepodipfile
            continue
          else
            echo "IP $PODIP is in Range on Node $LR"
            continue
          fi
        done
      done
    done
  done
  match_stale_nats
}

compare_podip_to_subnet_21() {
  for LR in $(get_nodename); do
    nodepodipfile=$(mktemp -t podip-node.XXX --suffix .$LR) ;
	  for SUBNETBIT in $(get_nodesubnet | awk -F. -v OFS=. '{print $3}'); do
		  NEXTSUBNET=$(($SUBNETBIT + 7)) ;
		  MINADDR=$(get_nodesubnet | awk -F. -v OFS=. '{print $1, $2, $3}').1 ;
    	MAXADDR=$(get_nodesubnet | awk -F. -v OFS=. '{print $1, $2}')."$NEXTSUBNET".254 ;
		  for NODEIP in $(get_nodeip); do
			  for PODIP in $(find_podip | awk -F: '{print $2}' | tr -d '""'); do
				  HOSTMIN=$(int_ip ${MINADDR}) ;
          HOSTMAX=$(int_ip ${MAXADDR}) ;
          IPINT=$(int_ip ${PODIP}) ;
          if ! [[ ${IPINT} -le ${HOSTMAX} && ${IPINT} -ge ${HOSTMIN} ]]; then
            echo "IP: $PODIP - Node: $LR. Out of range" >> $nodepodipfile
            continue
          else
            echo "IP $PODIP is in Range on Node $LR"
            continue
          fi
        done
      done
    done
  done
  match_stale_nats
}

# If everything is good we can stop right here immediately
get_stale_nats() {
  echo "Getting NATs stale and on each node"
  stalenatfile=$(mktemp -t stale_nat.XXX)
  egrep "logical_ip" /tmp/nat-podip.* -B1 | grep -v '\-\-' >> $stalenatfile &&
  local RESULT=$(grep -o '_uuid' $stalenatfile | wc -l)
  local ENTRIES=$(echo $RESULT | sed -e 's/^[[:space:]]*//')
  if [[ "$ENTRIES" -eq "0" ]]; then
    echo "Everything looks good!"
    rm -f /tmp/nat-podip.* $stalenatfile
    exit 0
  else
    echo "There are stale entries. Starting clean up"
    rm -f /tmp/nat-podip.* && get_nats_per_node
  fi
}

match_stale_nats() {
  echo "Getting NATs stale and on each node"
  stalenatfile=$(mktemp -t stale_nat.XXX)
  for PODIP in $(grep "IP\:" /tmp/podip-node.* | awk '{print $2}'); do
    find_nat_per_podip >> $stalenatfile ;
    sleep 1;
  done
  local RESULT=$(grep -o '_uuid' $stalenatfile | wc -l)
  local ENTRIES=$(echo $RESULT)
  if [[ "$ENTRIES" -eq "0" ]]; then
    echo "Everything looks good!"
    rm -f /tmp/podip-node.* $stalenatfile
    exit 0
  else
    echo "There are stale entries. Starting clean up"
    rm -f /tmp/podip-node.* && get_nats_per_node
  fi
}

# To make sure we will use the correct NAT UUID on the respective GR,
# we need to have data separated until we get which NAT to delete and its respective external_ip
get_nats_per_node() {
  echo "Getting NATs per node"
  rm -f /tmp/nat-podip.*
  for LR in $(get_nodename); do
    NODEIP=$(get_nodeip) ;
    natpernodefile=$(mktemp -t nat-on.XXX --suffix .$LR)
    find_nat_nodeip >> $natpernodefile ;
    sleep 1;
  done
  match_stale_nat_per_node
}

match_stale_nat_per_node() {
  echo "Matching NAT entries on each node"
  natuuidfile=$(mktemp -t nat_uuids.XXX)
  for i in $(grep '_uuid' $stalenatfile | awk -F":" '{print $2}'); do
    egrep $i /tmp/nat-on.* -A1 >> $natuuidfile ;
    sleep 1;
  done
  rm -f /tmp/nat-on.*
  clean_stale_nats
}

# With all data taken we can securely delete NATs on the correct node GR
clean_stale_nats() {
  echo "Clean up will start now"
  nodenamefile=$(mktemp -t nodename.XXX)
  for i in $(grep external_ip $natuuidfile | awk -F":" '{print $2}' | uniq | tr -d '""'); do
    oc get nodes -o wide | grep "$i" | awk '{print $1}' >> $nodenamefile;
  done
  for LR in $(cat $nodenamefile); do
    for NATUUID in $(get_nodeip); do
      natidpernodefile=$(mktemp -t nat-gr.XXX --suffix .$LR) ;
      grep $NATUUID $natuuidfile -B1 >> $natidpernodefile &&
      continue;
    done
  done
  for LR in $(cat $nodenamefile); do
    for NODEIP in $(get_nodeip); do
      for UUID in $(sudo find /tmp -type f -iname "nat-gr.*.$LR" | xargs cat | grep $NODEIP -B1 | grep '_uuid' | awk -F":" '{print $3}'); do
        echo "Delete NAT on GR_$LR with UUID $UUID" ;
        sleep 1 ;
        del_nats ; sleep 2;
      done
    done
  done
  rm -f /tmp/nat-gr.* $nodenamefile $stalenatfile $natuuidfile
  echo "All clean ups done!"
}

# Will run all the checks and finally call the clean up task
# End by deleting all the temp files and to clean up filesystem
run_checks_and_clean() {
  echo "Looking at the NBDB for stale nat entries"
  get_subnet_prefix
}

main() {
  VERSION=$(get_clusterversion | awk -F. -v OFS=. '{print $1, $2}')
  if [[ "$VERSION" == "4.10" ]]; then
    echo "Version is compatible. Continuing" && \
    run_checks_and_clean
  else
    echo "Version is not compatible with this tool"
    exit 0
  fi
}

main
