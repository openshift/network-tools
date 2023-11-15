# Quick reference
- [Download source code and install dependencies](#download-source-code-and-install-dependencies)
- [Configure jira client](#configure-jira-client)
- [Run network_bugs_overview script](#run-network_bugs_overview-script)
- [Documentation](#documentation)

This is a quick reference for the `network_bugs_overview` command line.
`network_bugs_overview` is based on [jira library for Python](https://github.com/pycontribs/jira).

It fetches open bugs assigned to our team members from our jira server, analyzes them and prints out a per-developer summary in the order from the currently least-loaded to currently the most-loaded team member.

In particular, it queries:
- jira (OCPBUGS project) for bugs and
- jira (RHOCPPRIO project) for escalations.

## Download source code and install dependencies
```
$ git clone https://github.com/openshift/network-tools && pushd network-tools/jira-scripts

$ cat requirements.txt
jira
python-dateutil

$ pip install --upgrade pip
$ pip install -r requirements.txt
```

## Configure jira client
Generate your jira token by going on https://issues.redhat.com and clicking on the user icon on the top right, then "Profile" -> "Personal Access Tokens" -> "Create token".
Then configure your jira secrets by saving your work email and token in jira_secrets.py, which you will place **in the jira-scripts directory of the network-tools project**:

```
$ popd  # go back to jira-scripts folder
$ cat > jira_secrets.py
secrets = {
    "email": "your_email@redhat.com",
    "token": "your_token",
}
```

## Run network_bugs_overview script
The available input arguments are the following:

```
$ ./network_bugs_overview -h
usage: network_bugs_overview [-h] [--jira-bugs] [--jira-escalations] [-v] [-q] [-n] [-g] [--old-bugs]

options:
  -h, --help            show this help message and exit
  --jira-bugs           run a query to jira server for jira bugs. By default, when no bug type is specified as input arg, jira bugs are fetched, but not jira escalations.
  --jira-escalations    run a query to jira server for jira escalations. By default, when no bug type is specified as input arg, jira bugs are fetched, but not jira escalations.
  -v, --verbose         Print detailed results
  -q, --quick           Skip assign analysis and get results more quickly
  -n, --new-bugs        Print currently unassigned bugs in a markup format
  -g, --process-github-issues
                        For each ovn-org/ovn-kubernetes github issue with the ci-flake label, make sure a corresponding jira ticket exists
  --old-bugs            Print a list of bugs that have been in the new state for more than 30 days
```

By running the python script as is, it will execute by default the following:
1. it will make that sure all ovn-k upstream issues with the ci-flake label are tracked in jira ("--process-github-issues" above);
2. it will query the jira server for assigned bugs in the OCPBUGS project and output a ranking of team members according to their bug load ("--jira-bugs" above);
3. it will print a list of unassigned bugs in a markup format ("--new-bugs" above):

```
./network_bugs_overview
```

Alternatively, you can specify the single actions to execute:

```
./network_bugs_overview --new-bugs
```

```
./network_bugs_overview --process-github-issues --quick
```

You can also print a quick version of the team bug load, by skipping the "assigned <=21 days" column, which often takes a long time to run:
```
./network_bugs_overview --quick
```

Finally, you can print the bugs that have been in the NEW state for more than 30 days and are therefore considered stale:

```
./network_bugs_overview --old-bugs
```

## Documentation

https://jira.readthedocs.io/examples.html
