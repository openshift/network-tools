debug-network
=============

`openshift-debug-network` is a tool for debugging network.
The directory structure, as well as specific details behind this tool can be found [in this enhancement](https://github.com/openshift/enhancements/blob/master/enhancements/oc/debug-network.md).

## Debugging Scripts
Debugging scripts are kept in `./debug-scripts`.  The content of that folder is placed in `/usr/bin` in the image.
The debug network scripts should only include debug logic for OpenShift Networking.
Outside components are encouraged to produce a similar "debug-network" image, but this is not the spot to be
included.
