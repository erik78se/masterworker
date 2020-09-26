Tutorial: Relations with Juju
Difficulty: Intermediate
Author: Erik Lönroth

What you will learn
This tutorial will teach you about the fundamentals of relations in juju.

You will:

* Learn what a relation is and how to use it in your charms. That is:
  - The core relational-hooks: created,joined,changed,departed,broken
  - How & when, to set and get data on a relation.
  - ...

Lets get started!

## Preparations

* You should have basic understanding of what juju, charms and models are.
* You should have got through the Getting started chapter of official juju documentation.
* You need to be able to deploy charms to a cloud.
* Make sure to have read: https://discourse.juju.is/t/the-lifecycle-of-charm-relations/1050
* You need to have beginner level python programming skills.

# The hook-tools
When working with relations, what goes on under the hood,
is always a call to a juju hook-tool.

Run the command below to see what those tools provide: 

``` $ juju help hook-tools```

<pre>
Juju charms can access a series of built-in helpers called 'hook-tools'.
These are useful for the charm to be able to inspect its running environment.
Currently available charm hook tools are:

    action-fail              set action fail status with message
    action-get               get action parameters
    action-log               record a progress message for the current action
    action-set               set action results
    add-metric               add metrics
    application-version-set  specify which version of the application is deployed
    close-port               ensure a port or range is always closed
    config-get               print application configuration
    credential-get           access cloud credentials
    goal-state               print the status of the charm's peers and related units
    is-leader                print application leadership status
    juju-log                 write a message to the juju log
    juju-reboot              Reboot the host machine
    k8s-raw-get              get k8s raw spec information
    k8s-raw-set              set k8s raw spec information
    k8s-spec-get             get k8s spec information
    k8s-spec-set             set k8s spec information
    leader-get               print application leadership settings
    leader-set               write application leadership settings
    network-get              get network config
    open-port                register a port or range to open
    opened-ports             lists all ports or ranges opened by the unit
    pod-spec-get             get k8s spec information (deprecated)
    pod-spec-set             set k8s spec information (deprecated)
    relation-get             get relation settings
    relation-ids             list all relation ids with the given relation name
    relation-list            list relation units
    relation-set             set relation settings
    state-delete             delete server-side-state key value pair
    state-get                print server-side-state value
    state-set                set server-side-state values
    status-get               print status information
    status-set               set status information
    storage-add              add storage instances
    storage-get              print information for storage instance with specified id
    storage-list             list storage attached to the unit
    unit-get                 print public-address or private-address
</pre>

Charms calls those hooks tools which is straight forward, 
lets say in a charm 'hooks/start'

<pre>
#!/bin/bash
status-set active "Ready"
</pre>

Pay some attention to the hooks: "relation-set" and "relation-get"
Those tools are what is used to pass information between charms via relations.

## charmhelpers - python package
When building charms with python, a package that wrapps the hook-tools exist: charmhelpers. 

It can be installed with "pip install charmhelpers" and made part of your install-hook, 
or better, cloned into the "./lib/" of your charm, making it part of your charm software. 
This is a good practice since it isolates your charms requirements 
from others on the same host.

Its time to introduce the "master" and "worker" charms.

# Master worker
Clone the "masterworker" repo to your client.

```git clone https://github.com/erik78se/masterworker```

The repo contains two charms: 
* master
* worker

They implement as a pair a pattern: "The master-worker pattern".

## Describing the pattern
The master-worker pattern is an idea about a "master" handing out
instructions to "workers". A master is often a single unit, 
whereas the workers can be many.

The information the master hands out can be unique to a single worker, 
whereas some information is common to all workers.

This pattern is useful in a lot of situation in computer science, 
such as when implementing client-server solutions. 
This is why I created this tutorial, since its a common occuring pattern.

Now deploy the bundle so we can get an idea of what it might look.

```juju deploy ./bundle.yaml``` 

This deploys a master with two workers.

[picture]

The deployed charms are now active and related.
A small piece of information has been passed between them.

The hook-tools involved in passing that was "relation-set" and 
"relation-get".

The master "set" some values, and the "workers" have "get" them.

Lets see when its triggered and the code for it.

# Relational hooks

When the command:
 ```juju relate master worker```
is ran, it triggers a specific set of hooks on all units
involved in the relation. Those are the "relational hooks". 
The picture below shows how these relational hooks are called 
and in what order.

Here is the master:s "master-application-relation-joined":

[code] -> https://github.com/erik78se/masterworker/blob/master/master/hooks/master-application-relation-joined

and the worker:s "master-relation-changed":

[code] -> https://github.com/erik78se/masterworker/blob/master/worker/hooks/master-relation-changed

This is how data is exchanged in relations.

Now, knowing the details of relational hooks is absolutely 
FUNDAMENTAL to understand charms with relations.

If you have not studied this, juju will remain magic to you.
If you want to become a Juju Jedi, you should grab a coffee and read 
this carefully.
 
## The relation event cycle
Below is the relational state machine. 
[picture]


### Exchanging information (relation-change) with units
When a change on a relation occurs, E.g. a unit calls "relation-set", 
ALL related units will get notified and fire the relation-change hook.
     
In a way, juju broadcasts relational data to all units when relation changes.

The juju function/action, demonstrates this:

https://github.com/erik78se/masterworker/blob/master/master/actions/broadcast-message

If you run the action and watch the "juju debug-log" you will see all units
logging the message sent.

Isn't this cool?

But, how do we send out unique data to units?

### Communicating unit unique data
The data exchanged on a relation is a dictionary. So, one way to hand out 
data for an individual units, is to have a key-name on the relation data
composed of the unit-name.

This way, we knows what data we should set or get, based on 
the unit name which is always available to us.

Look at the code in the worker: 
https://github.com/erik78se/masterworker/blob/master/worker/hooks/master-relation-changed



* Inspecting the relations

$ juju run --unit master/0 "relation-ids master-application"
master-application:0

# Remove and add back the relation to see how the relation-id changes from
# master-application:0 to master-application:1
$ juju remove-relation master worker
$ juju relate master worker

$ juju run --unit master/0 'relation-ids master-application'
master-application:1

$ juju run --unit worker/0 'relation-get -r master:1 - master/0'
egress-subnets: 172.31.27.134/32
ingress-address: 172.31.27.134
private-address: 172.31.27.134
worker/0-worker-key: "5914"
worker/1-worker-key: ADA1
$ juju run --unit master/0 'relation-get -r master-application:1 - worker/0'
egress-subnets: 172.31.35.128/32
ingress-address: 172.31.35.128
private-address: 172.31.35.128

# Get individial keys: (relation-get -r <relation-id> <key> <unit>, if "-", get all keys)
$ juju run --unit master/0 "relation-get -r master-application:1 worker/1-worker-key master/0"
ADA1

 * Adding more units

 * Departing
 * The last unit to depart:
  - the final unit to depart a relation marked for termination is responsible
    for destroying the relation and all associated data.

* Relation
 [master/0 has master-application:1] <---- simian ---> [master:1 has worker/0]
                                 <---- simian ---> [master:1 has worker/1]

* Introspect
$ juju run --unit master/0 "relation-ids master-application"
master-application:0

$ juju run --unit master/0 "relation-list -r master-application:1"
worker/0
worker/1

$ juju run --unit worker/0 "relation-list -r master:1"
master/0

# Look at the relation data for the master-application on the master/0 side.
# where we would expect to see the worker-keys.
$ juju run --unit master/0 "relation-get -r master-application:1 - master/0"
egress-subnets: 172.31.27.134/32
ingress-address: 172.31.27.134
private-address: 172.31.27.134
worker/0-worker-key: "5914"
worker/1-worker-key: ADA1

# Look at the worker/0 side of the same relation. Where the keys shouldn't be
$ juju run --unit master/0 "relation-get -r master-application:1 - worker/0"
egress-subnets: 172.31.35.128/32
ingress-address: 172.31.35.128
private-address: 172.31.35.128
