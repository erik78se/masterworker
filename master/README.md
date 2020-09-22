# Overview
Master - is an educational charm.

The **master** implements one side (the master) of a "master-worker" pattern, 
commonly used in various client-server services.

The related charm - **worker** is to be related with master 
to demonstrate how data is exchanged from the master
with related workers.

The data exchanged from master is a four character value (XYZW), 
assigned to a key named: *unitname-worker-key*.
 
This makes it possible for workers to access its individual data. 
Effectively implementing the master-worker pattern.

# Usage
<pre>
juju deploy ./master
juju deploy ./worker
juju relate master worker

# Run an action and watch the juju debug-log
juju run-action master/0 broadcast-message message="WORK" --wait
</pre>

# Configuration
This charm has no configuration.

# Actions
This charm has an action that manipulates the relation
on the master (a message) which is picked up by related worker units.

It demonstrates how relations can be used together with actions,
outside of the relational hooks.

## Action: broadcast-message
On the master:

<pre>
juju run-action master/0 broadcast-message message="HELLO WORD" --wait
</pre>

Use debug-log to watch the message getting logged.

<pre>
juju debug-log --include worker/0
</pre>