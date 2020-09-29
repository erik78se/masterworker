# Tutorial: Relations with Juju
Difficulty: Intermediate

Author: Erik Lönroth

# What you will learn
This tutorial will teach you about the fundamentals of relations in juju.
We will use two existing charms that implements a master-worker pattern and study
that code for reference.

Get the code here: ```git clone https://github.com/erik78se/masterworker```

You will in this tutorial:

* Learn what a relation is and how to use it in your charms. 
* Learn more about hooks and how hook-tools drives relation data exchanges.
* Learn about relational-hooks and when they run.
* How to debug/introspect a relation with hook-tools

Lets get started!

# Preparations

* You need a basic understanding of what juju, charms and models are.
* You should have got through the getting started chapter of official juju documentation.
* You need to be able to deploy charms to a cloud.
* You have read: [the lifecycle of charm relations]
* You have read: [charm writing relations].
* You need beginner level python programming skills.

# Refreshing our memory a little
Before we jump into it, lets refresh some of the key elements we are going to work with.

## Juju hook-tools
When working with relations and juju in general, what goes on under 
the hood, is many times calls to juju various juju hook-tools.

Refresh your memory, by looking at what those hook-tools are: 

```juju help hook-tools```

Two specific hook-tools are of major importance when working with juju relations:

**relation-get** & **relation-set**

Those are our primary tools when working on the data on juju relations.

## Hooks, their environment & context
Hooks-tools are normally executed in a 'hook' where some environment variables
are available to us, dependent on the context/hook.
 
An example would be below, where we access the environment variable
'JUJU_RELATION_ID' to produce some logging.

<pre>
#!/bin/bash
juju-log "This is the relation id: $JUJU_RELATION_ID"
status-set active "Ready"
</pre>


## Charmhelpers
When building charms with python, the python package [charmhelpers] provides a set of 
functions that wrapps the hook-tools.
Charmhelpers can be installed with <pre>pip install charmhelpers</pre>.

Installing this package for use within you charm, could be part of your install-hook,
or even better, cloned into the "./lib/" of your charm, making it part of your charm software.

Cloning charmhelpers into your charm is a good practice since it isolates your charms 
software requirements from other charms that may live on the same host.

Feeling all refreshed, lets now introduce the "master" and "worker" charms.
basis for this tutorial.

# Master worker
Clone the "masterworker" repo to your client.

```git clone https://github.com/erik78se/masterworker```

The repo contains:

<pre>
├── bundle.yaml         # <--- A bundle to deploy
├── master              # <--- The master charm
├── worker              # <--- The worker charm
├── ./lib/hookenv.py    # <--- Part of charmhelpers
</pre>


The master + worker, implements a pattern, where a "master" hands out
instructions to "worker(s)". The master is a single unit, whereas the workers can be many.

The master hands out some unique information to single worker units, 
whereas some other information is common to all workers units.

The workers don't send any information at all to the master.

This pattern is useful in a lot of situations in computer science, 
such as when implementing client-server solutions.

Deploy via the bundle or manually the master workers so we can see how it looks
and how the charms are related.

```
juju deploy master
juju deploy worker -n 2
juju relate master worker
``` 

[picture]

# Implementation
So, the first step in implementing the relation between two charms starts with defining the
relational endpoints.

## Step 1. Define an endpoint and select an interface name
A starting point to create a relational charm, is to modify the the metadata.yaml file 
for both master and worker to define the juju [endpoint](https://juju.is/docs/concepts-and-terms) for the relation.

The interface name must be same for all participants in the relation
or juju will refuse to relate the charms.

The endpoints for the master and worker are defined as below.

*master/metadata.yaml*
<pre>
provides:                # <--- Role
  master-application:    # <--- Relation Name
    interface: exchange  # <--- Interface name 
    limit: 1
</pre>

*worker/metadata.yaml*
<pre>
requires:                # <--- Role
  master:                # <--- Relation name
    interface: exchange  # <--- Interface name
</pre>

At this point, the charms can be related.

## Step 2. Decide what data to pass
The master and worker charms exchange two pieces of information as part of our invented interface:

1. A **worker-key** for each unique worker. The worker-key is created by the master.
2. A **message** from the master to all the workers.

The workers will not pass any data at all.


## Step 3. Use the relational hooks to set/get data.

Calling:
 ```
 juju relate master worker
```

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

The best practice to adopt here, is to use **relation-joined** and/or **relation-created** to set
initial data and **relation-changed** to retrieve them just as we have done in the 
master and worker charms.

So, how do we make the master send out data that is unique to our worker units?

### Communicating unit unique data
The data exchanged on juju relations is a dictionary. 

The simple strategy I decided for passing individual data to workers, 
was to have the master create composite dictionary keys, made up by the 
joining remote **unit-name + key-name** and set data for that composite key.

Look at the code for the worker on how they access their individual **worker-key** it in the
 master-relation-changed hook: 
https://github.com/erik78se/masterworker/blob/master/worker/hooks/master-relation-changed

Pretty straight forward, right?

Lets also see how we can have the master use an alternative way to send out 
a custom "message" to the workers outside of the relational hooks.

### Triggering a relation-change via a juju action.
Any change on a relation triggers the hook *xxx-relation-change* on the remote units 
in the relation, we can trigger this from other hooks too since we can access the relations
by their id:s. 

The master implements this in a juju "action" to show how this is achieved.

https://github.com/erik78se/masterworker/blob/master/master/actions/broadcast-message

If you run the action 'broadcast-message' and watch the "juju debug-log" you will see all units
logging the message sent.

This is pretty much all there is to it writing simple relations. Below are some useful trix to use
when debugging relations to inspect what data is available in a relation.

## Introspect the relation (debugging)
We will often need to see what goes on on a relation, what data is set etc. Lets see how that is 
done using the hook-tools.

Here we retrieve the relation-ids for the master/0 unit.
<pre>
juju run --unit master/0 "relation-ids master-application"
master-application:0
</pre>

Removing and adding back a relation show how the relation-id changes 
from master-application:0 to master-application:1
<pre>
juju remove-relation master worker
juju relate master worker
juju run --unit master/0 'relation-ids master-application'
master-application:1
</pre>

We can see from the command below, how the worker can access all (-)
keys/data on the master/0 unit.
<pre>
juju run --unit worker/0 'relation-get -r master:1 - master/0'
egress-subnets: 172.31.27.134/32
ingress-address: 172.31.27.134
private-address: 172.31.27.134
worker/0-worker-key: "5914"
worker/1-worker-key: ADA1
</pre>
We can from the command below, that on the master/0 there is no information
from the worker, which is expected. The workers don't set any data.
<pre>
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

## Step 4. Departing the relation
When a unit departs from a relation, the programmer should:
 
  1. Do whatever is needed to remove a departing unit from the service e.g. 
  perform reconfiguration, removing databases etc. 
  1. Remove any relational data associated with the departing unit from 
  the relational dictionary with the *relation-set* hook tool. 

Lets see how the two charms deals with this in our example.

So, lets remove a worker:

```juju remove-unit worker/1```

The master (and worker) gets notified of the event.
 
The master executes: *master-application-relation-departed* and is 
responsible for removing the relation data for the remote-unit (E.g. worker/1):
 
*./master/hooks/master-application-relation-departed*
<pre>
    # Set a None value on the key (removes it from the relation data dictionary)
    relation_data = {f"{remoteUnitName}-worker-key": None}

    # Update the relation data on the relation.
    relation_set(relation_id(), relation_settings=relation_data) 
</pre>

Inspecting the relation will show that the data for worker/1 is gone:
<pre>
juju run --unit worker/0 'relation-get -r master:1 - master/0'
egress-subnets: 172.31.27.134/32
ingress-address: 172.31.27.134
private-address: 172.31.27.134
worker/0-worker-key: "5914"
</pre>

The master hasn't done anything else, so its duties are complete. 

On the **worker** side of the relation, the worker didn't set any relation data, 
so it doesn't have to do anything to clean up in its relational data.

But, the worker should remove the *WORKERKEY.file* that it created on the 
host as part of joining the relation.

I placed this activity as part of the 'relation-broken' hook.

*./worker/hooks/master-relation-broken*
<pre>
    # Remove the WORKERKEY.file
    os.remove("WORKERKEY.file")
</pre>
 
The *relation-broken* hook is the state where units are completely cut-off 
from each other, as if the relation was never there and happens last in the 
relation life-cycle. 

Keep in mind that the name of the hook *"-broken"* has nothing to do with 
that the relation is "bogus/error". Its just that the relation is "cut".

Lets remove all the relations:

```juju remove-relation master worker```.

Go ahead and try this and inspect the relations and look for 
the file WORKERKEY.file on the remaining worker units (they are gone!).

Congratulations, you have completed the tutorial on juju relations!

[charm writing relations]: https://juju.is/docs/charm-writing/relations
[the lifecycle of charm relations]: https://discourse.juju.is/t/the-lifecycle-of-charm-relations/1050
[debugging hooks]: https://discourse.juju.is/t/the-hook-environment-hook-tools-and-how-hooks-are-run/1047
[charmhelpers]: https://github.com/juju/charm-helpers