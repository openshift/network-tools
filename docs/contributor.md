# Contributor Documentation 

Contributing to OpenShift Network-Tools will enable us to provide a better way to debug OpenShift Cluster Networking. 
Any type of contributions such as improving existing scripts, fixing bugs, adding new scripts are valuable and most welcome. 
Please open issues on github for this repository if you find any. RH employees can also reach out to us on #forum-sdn.

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
- Running commands in the pod's network namespace
- All other networking-related tools that can improve debugging process

## Repository Structure

- All scripts live in `debug-scripts`.
- `debug-scripts/network-tools` is the entry point that provides list of all available commands
- `debug-scripts/local-scripts` are not copied to the image and usually only make sense to run locally
- `debug-scripts/test-networking` is a set of script that run connectivity checks on the cluster
- `debug-scripts/scripts` contains all other scripts, is your script is not local, add it here
- When the image is build, the scripts are then copied into `/opt/bin/`.
- All docs live in `network-tools/docs`.
- All dependencies should be vendored and they live in `vendor`.
- The main dockerfile used for the official release image build is `Dockerfile`.
- The dockerfile for development purposes is based of off fedora and is called `Dockerfile.fedora`.

## Adding Scripts

Please follow the undermentioned instructions when adding a new script to the network-tools repo. 
This is to maintain a minimum level of uniformity.

  - Name of the script should reflect what it intends to do, the general pattern is `<object>_<action>` or `<object1>_<object2>...`
where the scope reduces, e.g. if a script only works for ovn-k clusters, it should start with `ovn` and for openshift-sdn with `sdn`
  - Functions that are reused in more than one script should be added to the `utils`.
  - You can use `docs/script-template` as a template for a new script, make sure to update `description` and `help` functions
  - Add command name <-> script path association in `network-tools` `other_commands` or in `local-scripts/local-scripts-map`
    for local scripts.
  - Make sure your script can be run both locally and with `oc adm must-gather`
  - Make sure that `network-tools -h` and `network-tools <new script name> -h` shows your command and its help properly.
  - Update documentation by running `./docs/generate-docs`.
  - Even though this image can be accessed only by privileges users/administrators, avoid security vulnerabilities.
  - If script assumes to have direct ssh access into the nodes in the cluster, it should be explicitly stated in the help function and must be used only under exceptional circumstances like when the api is down and new pods cannot be created.
  - All resources created for testing, must use the `network-tools` image.
  - All resource names should start with the prefix `network-tools-*`.

## Testing Scripts

To test a new version on the cluster use `Dockerfile.fedora`
1. Build an image `docker build -f Dockerfile.fedora . -t quay.io/<username>/network-tools:v1`
   
   if you get error accessing `registry.ci.openshift.org`, 
   1. get your token from https://oauth-openshift.apps.ci.l2s4.p1.openshiftapps.com/oauth/token/request
   2. run `podman login --authfile ~/.docker/config.json -u <username> -p <token> registry.ci.openshift.org`
2. Push `docker push quay.io/<username>/network-tools:v1`
3. Make sure repo is public or setup secrets for your repo
4. Use this image to run must-gather 
`oc adm must-gather --image quay.io/<username>/network-tools:v1 -- network-tools -h`

## Reporting Bugs

- Open an [issue]( https://github.com/openshift/network-tools/issues/new ) against the repository specifying the of the detail bug.

## Fixing Bugs

- Open a PR with the fix against the repository indicating the issue.

## Missing Tools

- If any networking CLI tools or packages need to be shipped to enhance debugging experience, open a PR adding it to the `Dockerfile`'s install packages with adequate justification.
