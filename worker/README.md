# Overview
The **worker** - is an educational charm.

The worker retrieves data exchanged from master 
as a four character value (XYZW), assigned to a key named: *<worker-unit-name>-worker-key*.
 
This makes it possible for the worker unit to access its individual data by using its local unit name. 

The worker also can be informed about a message, which is the same for all units
in the relation and is triggered by an action on the *master* charm.

The worker charm will log this message.
 
# Usage
<pre>
juju deploy ./master
juju deploy ./worker
juju relate master worker
</pre>

# Configuration
No configuration.

# Actions
No actions.