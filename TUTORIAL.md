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

# Preparations

* You need a basic understanding of what juju, charms and models are.
* You should have got through the getting started chapter of official juju documentation.
* You need to be able to deploy charms to a cloud.
* You have read: [the lifecycle of charm relations]
* You have read: [charm writing relations].
* You need beginner level python programming skills.

# Refreshing our memory a little
We will start by refreshing some of the key elements we are going to work with.

## Juju hook-tools
When working with relations and juju in general, what goes on under 
the hood are calls to juju hook-tools.

Refresh your memory, by looking at what those hook-tools are: 

```juju help hook-tools```

Two specific hook-tools are of major importance when working with juju relations:

**relation-get** & **relation-set**

Those are our primary tools when working with juju relations 
because they get/set data in the relation. 

Important: You set data on the local unit, and get data from remote units.

## Hooks, their environment & context
Hooks-tools are normally executed in a 'hook' where some environment variables
are available to us, dependent on the context/hook. These variables are used 
get or set specific data, for specific relations. 
 
An example would be below, where we access the environment variables
'JUJU_RELATION_ID', 'JUJU_REMOTE_UNIT' and 'JUJU_UNIT_NAME'
 to produce some logging.

<pre>
#!/bin/bash
juju-log "This is the relation id: $JUJU_RELATION_ID"
juju-log "This is the remote unit: $JUJU_REMOTE_UNIT"
juju-log "This is the local unit: $JUJU_UNIT_NAME"
</pre>


## Charmhelpers
When building charms with python, the python package [charmhelpers] provides a set of 
functions that wrapps the hook-tools.
Charmhelpers can be installed with <pre>pip install charmhelpers</pre>.

Here is the documentation [charmhelpers-docs].

Installing this package for use within you charm, could be part of your install-hook,
or even better, cloned into the "./lib/" of your charm, making it part of your charm software.

Cloning charmhelpers into your charm is a good practice since it isolates your charms 
software requirements from other charms that may live on the same host.

Feeling all refreshed, lets now introduce the "master" and "worker" charms.

# Master worker
Clone the "masterworker" repo to your client.

```git clone https://github.com/erik78se/masterworker```

The repo contains:

<pre>
├── bundle.yaml         # <--- A bundle with a related master + 2 workers
├── master              # <--- The master charm
├── worker              # <--- The worker charm
├── ./lib/hookenv.py    # <--- Part of charmhelpers
</pre>


The master + worker, implements a pattern, where a "master" hands out
instructions to "worker(s)". The master is a single unit, whereas the workers can be many.

The master hands out some unique information to single worker units, 
whereas some other information is common to all workers units.

The workers don't send (relation-set) any information.

This pattern is useful in a lot of situations in computer science, 
such as when implementing client-server solutions.

Lets deploy the master and two workers so we can see how it looks
and how the charms are related.

```
juju deploy master
juju deploy worker -n 2
juju relate master worker
``` 

Note: You could of course deploy the bundle instead:
```
juju deploy ./bundle.yaml
```

[picture]

# Implementation
So, lets go through the steps required to produce the relation between these charms.

The first step in implementing the relation between two charms starts with defining the
relational [endpoint] for the charms and its interface name.

## Step 1. Define an endpoint and select an interface name
A starting point to create a relational charm, is to modify the the metadata.yaml file. 
We do this for both master and worker since they have different roles in the relation.

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

The interface name must be same for the master/worker endpoints or 
juju will refuse to relate the charms.

## Step 2. Decide what data to pass
The master exchange two pieces of information 
in our invented *exchange* interface with the worker:

1. A **worker-key** for each unique worker. The worker-key is created by the master.
2. A **message** from the master to all the workers.

The worker does not pass (relation-set) any data to make things simple.

Now that we have defined all we need, to be able to relate the charms, 
lets start looking at exchanging some data.

## Step 3. Use the relational hooks to set/get data.

When calling:
 ```
 juju relate master worker
```

juju triggers a specific set of hooks on all units involved in the relation called
 "relational hooks". The picture below shows how these hooks are called and in what order.

[picture]

Here is how we implement the master:s "master-application-relation-joined":

[code] -> https://github.com/erik78se/masterworker/blob/master/master/hooks/master-application-relation-joined

and the worker:s "master-relation-changed":

[code] -> https://github.com/erik78se/masterworker/blob/master/worker/hooks/master-relation-changed

The best practice to adopt here, is to use **relation-joined** and/or **relation-created** to set
initial data and **relation-changed** to retrieve them just as we have done in the 
master and worker charms.

Observe in the code the calls to the hook-tools: 
"relation-set" and "relation-get".

So, lets look a bit closer on how the master sends out data 
that is unique to our worker units.

### Communicating unit unique data
Data exchanged on juju relations is a dictionary. 

The simple strategy used here is to pass individual data to workers by havign 
the master create a composite dictionary key, made up by the 
joining remote **unit-name + key-name** and *relation-set* data for that composite key.

Look at the code for the worker on how they access their individual **worker-key** in the
 [master-relation-changed] hook:
<pre>
    # Get the key with our worker name on it, e.g.: 'worker/0-worker-key'
    workerKey = relation_get(f"{localunitname}-worker-key")
</pre>

Pretty straight forward, right?

Lets see now also how we use an alternative way to send out a message to the workers outside of the relational hooks.

### Triggering a relation-change via a juju action.
Any change on a relation triggers the hook *relation_name-relation-change* on the remote units, 
we can trigger this from other non relational hooks since we can access the relations by their id:s. 

Look at the juju-action [broadcast-message] to show how this is achieved.

If you run the action 'broadcast-message' and watch the "juju debug-log" you will see all units
logging the message sent.

```
juju run-action master/0 broadcast-message message="Hello there"
```


## Introspect the relations (debugging)
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
The last step to implement in juju relation is taking case of when a unit departs from a relation, 
the programmer should:
 
  1. Do whatever is needed to remove a departing unit from the service e.g. 
  perform reconfiguration, removing databases etc. 
  1. Remove any relational data associated with the departing unit from 
  the relational dictionary with the *relation-set* hook tool. 

Lets see how the master and worker charms deal with this in our example.

Lets walk through this by removing a worker. Follow the events with *juju debug-log*.

```juju remove-unit worker/1```

The master (and worker/1) gets notified of the event.
 
The master executes: *master-application-relation-departed* and is 
responsible for removing the relation data it previously set:
 
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

The master hasn't done anything else on the host itself, so its duties are complete. 

On the **worker** side of the relation, the worker didn't set any relation data, 
so it doesn't have to do anything to clean up in its relational data.

But, the worker should remove the *WORKERKEY.file* that it created on the 
host as part of joining the relation.

This cleanup procedure is placed in the 'relation-broken' hook.

*./worker/hooks/master-relation-broken*
<pre>
    # Remove the WORKERKEY.file
    os.remove("WORKERKEY.file")
</pre>
 
The *relation-broken* hook is the final state when units are completely cut-off 
from each other, as if the relation was never there. It is last in the 
relation life-cycle and is a good place to do cleanup related to the host or
underlying service deployed by the charm.

Keep in mind that the name of the hook *"-broken"* has nothing to do with 
that the relation is "bogus/error". Its just that the relation is "cut".

Lets finish up by removing all the relations:

```juju remove-relation master worker```.

Inspect the relations and look for the file WORKERKEY.file on the remaining worker units (they are gone!).

Congratulations, you have completed the tutorial on juju relations!

[charm writing relations]: https://juju.is/docs/charm-writing/relations
[the lifecycle of charm relations]: https://discourse.juju.is/t/the-lifecycle-of-charm-relations/1050
[debugging hooks]: https://discourse.juju.is/t/the-hook-environment-hook-tools-and-how-hooks-are-run/1047
[charmhelpers]: https://github.com/juju/charm-helpers
[charmhelpers-docs]: https://charm-helpers.readthedocs.io/en/latest/
[endpoint]: https://juju.is/docs/concepts-and-terms
[master-relation-changed]: https://github.com/erik78se/masterworker/blob/master/worker/hooks/master-relation-changed
[broadcast-message]: https://github.com/erik78se/masterworker/blob/master/master/actions/broadcast-message