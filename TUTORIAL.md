# Tutorial: Relations with Juju
Difficulty: Intermediate

Author: Erik Lönroth

# What you will learn
This tutorial will teach you about the fundamentals of relations in juju.
We will use two existing example charms to learn this that implements a 
master-worker pattern.

Get the code here: ```git clone https://github.com/erik78se/masterworker```

You will in this tutorial:

* Learn what a relation is and how to use it in your charms. 
* Learn how the hook-tools drives relation data exchange.
* Learn about relational-hooks and when they run.
* How to debug/introspect a relation with hook-tools

Lets get started!

# Preparations

* You need a basic understanding of what juju, charms and models are.
* You should have got through the getting started chapter of official juju documentation.
* You need to be able to deploy charms to a cloud.
* Make sure to have read: https://discourse.juju.is/t/the-lifecycle-of-charm-relations/1050
* You need beginner level python programming skills.

# The hook-tools
When working with relations and juju in general, you should know, that what goes on under 
the hood, is always calls to juju hook-tools.

Lets look at what those hook-tools are: 

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


## Hook contexts
Charms calls the hooks-tools from within 'hook contexts'. 
An example would be below, where we access the hook context by
referencing the environment variable JUJU_CURRENT_HOOK to produce
some logging.

<pre>
#!/bin/bash
juju-log "This is the hook context: $JUJU_CURRENT_HOOK"
status-set active "Ready"
</pre>

Debugging the hooks it its context is covered here. [link]

## Charmhelpers - the hook-tools python package
When building charms with python, the python package charmhelpers provides a set of 
functions that wrapps the hook-tools.
Charmhelpers can be installed with <pre>pip install charmhelpers</pre> This can be 
part of your install-hook, or even better, cloned into the "./lib/" 
of your charm, making it part of your charm software. 
Cloning charmhelpers into your charm is good practice since it isolates your charms 
software requirements from other charms that may live on the same host.

Lets now introduce the "master" and "worker" charms which
will be basis for this tutorial.

# Master worker
If you haven't already done this, clone the "masterworker" repo to your client.

```git clone https://github.com/erik78se/masterworker```

The repo contains two charms and parts of charmhelpers: 

* ./master
* ./worker
* ./lib/hookenv.py

Together they implement: A "master-worker pattern".

In the metadata.yaml file I picked a name for the 
relation interface: "keyexchange" which needs to be the same
for both "master" and "worker". If the interface name
don't match, juju will refuse to relate the charms.

Interfaces are covered in detail here, but for now, the only thing
to know about interfaces is that they need to have the same name for
all charms participating in the relation.

## Describing the master-worker pattern
The master-worker pattern is an idea about a "master" handing out
instructions to "workers". The master is often a single unit, 
whereas the workers can be many.

This is reflected in the metadata.yaml, where I put "limit: 1" to 
indicate that the master should be a single unit. 
Juju doen't enforce this, but it makes sense to the pattern.

The information the master hands out can be unique to a single worker, 
whereas some information is common to all.

This pattern is useful in a lot of situation in computer science, 
such as when implementing client-server solutions.

Go ahead and deploy the bundle so we can see how it looks.

```juju deploy ./bundle.yaml``` 

[picture]

The deployed charms exchange two pieces of information as part of getting related:

1. A unique worker-key for each worker is created by the master.
2. A common 'message' from the master to all the workers.

# Relational hooks

When the command:
 ```juju relate master worker```
triggers a specific set of hooks on all units involved in the relation. 
Those are the "relational hooks". The picture below shows how these 
relational hooks are called and in what order.

[picture]

Here is the master:s "master-application-relation-joined":

[code] -> https://github.com/erik78se/masterworker/blob/master/master/hooks/master-application-relation-joined

and the worker:s "master-relation-changed":

[code] -> https://github.com/erik78se/masterworker/blob/master/worker/hooks/master-relation-changed

The important code is the call to the hook-tools: 
"relation-set" and "relation-get". Those tools are used to get/set information shared 
between charms within the context of the hook they execute.

Lets see how the master can send out a "message" to the workers.

### Triggering a relation-change.
A change on a relation always trigger relation-change on relations, but we can
trigger this from other hooks too. 

The master implements an "action" to show this.

https://github.com/erik78se/masterworker/blob/master/master/actions/broadcast-message

If you run the action 'broadcast-message' and watch the "juju debug-log" you will see all units
logging the message sent.

This illustrates how juju sends the same data to all joined units whenever the data is 
changed - also from outside of the relation.

But, how do we send out unique data to units?

### Communicating unit unique data
The data exchanged on a relation is a dictionary. 

To hand out individual data, the master simply creates a composite key, made up by
the unit-name+key-name and set the individual key for the remote unit.

Look at the code in the worker: 
https://github.com/erik78se/masterworker/blob/master/worker/hooks/master-relation-changed

# Introspect the relation (debugging)
We will often need to see what goes on on a relation, what data is set etc. Lets see how that is 
done using the hook-tools.

<pre>
juju run --unit master/0 "relation-ids master-application"
master-application:0
</pre>

Remove and add back the relation to see how the relation-id changes from master-application:0 to master-application:1
<pre>
juju remove-relation master worker
juju relate master worker
juju run --unit master/0 'relation-ids master-application'
master-application:1
</pre>

Look at all keys/data on the relation
<pre>
juju run --unit worker/0 'relation-get -r master:1 - master/0'
egress-subnets: 172.31.27.134/32
ingress-address: 172.31.27.134
private-address: 172.31.27.134
worker/0-worker-key: "5914"
worker/1-worker-key: ADA1

juju run --unit master/0 'relation-get -r master-application:1 - worker/0'
egress-subnets: 172.31.35.128/32
ingress-address: 172.31.35.128
private-address: 172.31.35.128
</pre>

Individial keys can be retrieved also:
<pre>
juju run --unit master/0 "relation-get -r master-application:1 worker/1-worker-key master/0"
ADA1
</pre>


# A strategy for implementing a relation
A general pattern for implementing a relation could be:

* 'relation-set' is called on a local unit to push out some information. Do this in the
relation-joined or relation-changed as much as possible.
* 'relation-change' is triggered by the event on all units involved.
* Use 'relation-get' on remote units in the 'relation-change' hook to retrieve the information.

* Inspecting the relations



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
