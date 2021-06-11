# Contributor Documentation 

Contributing to OpenShift Network-Tools will enable us to provide a better way to debug OpenShift Cluster Networking. Any type of contributions such as improving existing scripts, fixing bugs, adding new scripts are valuable and most welcome. Please open issues on github for this repository if you find any. RH employees can also reach out to us on #forum-sdn.

## Scope 

This repository aims at providing debugging tools for:

- Checking overall cluster connectivity
- Features developed as a part of OpenShift Networking. Currently supported areas include:
    - OpenShiftSDN
    - OVNKubernetes
    - SRIOV
- Capturing packet dumps and traces from interfaces of nodes/pods/resources in the cluster real-time
- Gather networking metrics/logs from the cluster in situations where API is unreachable (must-gather will not help) by running the scripts locally
- Allowing to spinning up a hostnetwork pod with priviledges which has the basic networking command line tools installed
- Running commands in the pod's network namespace.

**NOTE :**  All the scripts can be executed using:

```
    oc adm must-gather --image=quay.io/openshift/origin-network-tools:latest
```
command. See the user documentation for more information on how to run existing scripts against an OpenShift cluster.

## Repository Structure

- All scripts live in `network-tools/debug-scripts`.
- When the image is build, the scripts are then copied into `/usr/bin/`.
- All docs live in `network-tools/docs`.
- All dependencies should be vendored and they live in `network-tools/vendor`.
- The main dockerfile used for the official release image build is `Dockerfile`.
- The dockerfile for development purposes is based of off fedora and is called `Dockerfile.fedora`.

## Adding Scripts

Please follow the undermentioned instructions when adding a new script to the network-tools repo. This is to maintain a minimum level of uniformity.

- Name of the script should reflect what it intends to do, eg: `ovn_pod_to_pod_connecvity` intends to check the connectivity between pods on an OVNKubernetes-k8s cluster.
- Name of the script should start with the name of high-level component that it is a part of. eg: All scripts testing openshift-sdn should start with the prefix `sdn_`.
- Functions that are reused in more than one script should be added to the `common` script.
- If the script is intended to be a part of the default collection of scripts to be run, it should be invoked from `network-tools`.
- A brief `help` method explaining the usage and options should be added which can be invoked with the `-h` option. eg: `ovn_pod_to_pod_connecvity -h`.
- The script should try and follow a basic structure similar to existing scripts in the respository. eg: a `main` function, a meaningful sub-function that starts with the prefix `do_$file_name`.
- The script should by default create the necessary resources to do the test if the user has not passed any arguments.
- Each script should be both standalone and at the same time if invoked in the default mode, be compatible when running with the rest of the scripts.
- Each message printed should fall under either `INFO` or `SUCCESS` or `FAILURE` categories.
- Should test the functionality of the script with `oc adm must-gather --`. Make sure the script does not break the build and is well tested.
- Add documentation regarding what the script does to the user docs.
- Even though this image can be accessed only by priviledges users/administrators, avoid security vulnerabilites.
- Use discretion when commands need to be run from a network namespace. First preference would be to use the `oc debug node/xx` command. If there are too many commands to be run create a hostNetwork pod.
- If script assumes to have direct ssh access into the nodes in the cluster, it should be explicitly stated in the help function and must be used only under exceptional circumstances like when the api is down and new pods cannot be created.
- All resources created for testing, must use the `openshift-network-tools` image.
- All resource names should start with the prefix `network-tools-*`.

## Reporting Bugs

- Open an [issue] ( https://github.com/openshift/network-tools/issues/new ) against the repository specifying the of the detail bug.

## Fixing Bugs

- Open a PR with the fix against the repository indicating the issue.

## Missing Tools

- If any networking CLI tools or packages need to be shipped to enhance debugging experience, open a PR adding it to the `Dockerfile`'s install packages with adequate justification.
