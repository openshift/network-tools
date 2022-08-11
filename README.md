network-tools
=============

`network-tools` is a collection of tools for debugging OpenShift cluster network issues.
It will contain both debugging scripts (described in the next section) and useful tools that can be used
by network engineers and openshift operators to debug and diagnose issues.

## How to use

### Locally
To use network-tools locally, you can just clone this repo and run
`./debug-scripts/network-tools -h` - that will list all available commands.

You can also create a symlink for your convenience to just use `network-tools`
`ln -s <repo-path>/debug-scripts/network-tools /usr/bin/network-tools`
`network-tools -h`

### On the cluster

You can use almost all the same scripts on the cluster via network-tools image, to run one command you can use
`oc adm must-gather --image quay.io/openshift/origin-network-tools:latest -- network-tools -h`

WARNING! `must-gather` doesn't allow interactive input, don't use interactive options with must-gather.

For more examples and options check [user docs](https://github.com/openshift/network-tools/blob/master/docs/user.md)

## Debugging Scripts
Debugging scripts are kept in `debug-scripts`.  The content of that folder is placed in `/opt/bin` in the image.
Symlink is created for `/opt/bin/network-tools` to `/usr/bin/network-tools` that allows to just call `network-tools`.

`debug-scripts/local-scripts` folder contains scripts that shouldn't be run on the cluster via `oc adm must-gather`, they
are not copied to the image. But these scripts are available for local use (`network-tools -h` will list currently available commands).

`debug-scripts/network-tools` is a single entry point for all commands that were tested and properly documented. Not all scripts from
`debug-scripts` folder may be included to the `network-tools`. If you need to run such a script, call it directly via
`debug-scripts/<script path>` locally or `/opt/bin/<script path>` in the image.

## Documentation

* Please see [contributor docs](https://github.com/openshift/network-tools/blob/master/docs/contributor.md) for more information regarding the scope of this repository and how to contribute.
* Users can go to [user docs](https://github.com/openshift/network-tools/blob/master/docs/user.md) for information on how to leverage the tools and scripts shipped by this image.

