# Quick reference
- [Download source code and install dependencies](#download-source-code-and-install-dependencies)
- [Configure bugzilla client](#configure-bugzilla-client)
- [Configure jira client](#configure-jira-client)
- [Run network_bugs_overview script](#run-network_bugs_overview-script)
- [Documentation](#documentation)

This is a quick reference for the `network_bugs_overview` command line.
`network_bugs_overview` is based on [python-bugzilla project](https://github.com/python-bugzilla/python-bugzilla) and on [jira library for Python](https://github.com/pycontribs/jira).

It fetches open bugs assigned to our team members from our bugzilla and our jira servers, analyzes them and prints out a per-developer summary in the order from the currently least-loaded to currently the most-loaded team member.

In particular, it queries:
- bugzilla for existing bugs (the creation new bugs will soon be disabled on our bugzilla server),
- jira (OCPBUGS project) for bugs and
- jira (RHOCPPRIO project) for escalations.

## Download source code and install dependencies
```
$ git clone https://github.com/openshift/network-tools && pushd network-tools/jira-scripts

$ cat requirements.txt
python-bugzilla
jira
python-dateutil

$ pip install --upgrade pip
$ pip install -r requirements.txt
```

## Configure bugzilla client
First, generate the `api key` to communicate with bugzilla using `python-bugzilla` module.
Go to https://bugzilla.redhat.com and click: **Username -> Preferences -> API Keys**.

**ATTENTION:**
As soon you click: "**Generate the API-key**" a long string will be generated with chars and numbers, COPY it as it's only displayed **ONCE**.

```
$ mkdir -p ~/.config/python-bugzilla/ && cd ~/.config/python-bugzilla/
$ cat bugzillarc
[bugzilla.redhat.com]
api_key=qwertyuiopasdfghjklzxcvbnm           <----- Long string generated once in the step above.
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
usage: network_bugs_overview [-h] [--bz] [--jira-bugs] [--jira-escalations] [--old-bugs]

options:
  -h, --help          show this help message and exit
  --bz                run a query to bugzilla. By default, when no bug type is specified as input arg, bz and jira bugs are fetched, but not jira escalations.
  --jira-bugs         run a query to jira server for jira bugs. By default, when no bug type is specified as input arg, bz and jira bugs are fetched, but not jira escalations.
  --jira-escalations  run a query to jira server for jira escalations. By default, when no bug type is specified as input arg, bz and jira bugs are fetched, but not jira escalations.
  --old-bugs          Print a list of bugs that have been in the new state for more than 30 days
```

By running the python script as is, it will query the bugzilla server for existing bugs and the jira server for bugs in the OCPBUGS project:

```
./network_bugs_overview
```

Alternatively, we can specify the types of issues to query for:

```
./network_bugs_overview --jira-bugs --jira-escalations
```

Finally, you can print the bugs that have been in the NEW state for more than 30 days and are therefore considered stale:

```
./network_bugs_overview --old-bugs
```

## Documentation

https://bugzilla.readthedocs.io/en/latest/api/core/v1/bug.html#search-bugs

https://jira.readthedocs.io/examples.html
