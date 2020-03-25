The `lib` directory contains various building blocks meant to be used by
higher level lockers. Applications would not typically use the building
blocks in here directly, if they need to, it is likely a sign that the
building block should be moved to the top level directory.

## fast_lock.sh

Much of the functionality of the lockers depends on the fundamental
`fast_lock.sh` building block.  The `fast_lock.sh` script mimics the
traditional voluntary file locking mechanism, but it uses lock directories
instead of lock files.  By using several layers of directories to construct
its voluntary locks, the `fast_lock.sh` script makes it possible to recover
from stale locks in a safe fashion.


## Recovery Policies

Although safe recovery of stale locks is possible with `fast_lock.sh`, this
is only true if a way to identify such stale locks is possible, `fast_lock.sh`
cannot do this on its own.  There are locker helpers in this directory
built upon `fast_lock.sh` which implement different staleness checking policies.
These helpers are named for the policy they use, `<policy>_lock.sh`.  These
helpers don't actually do any staleness checking themselves, they rely on
a pluggable program to do so.  These helpers only determine when to query
the staleness checker, and they use `fast_lock.sh` to recover once
staleness is identified.

Example of staleness policy locker helpers:

* `check_lock.sh`:  Assumes staleness check is cheap, always checks for staleness.
* `grace_lock.sh`:  Assumes staleness check is expensive, checks for staleness
                after a grace period from the lock acquisition and the
                last check.

## Clusters

hostpid_lock.sh is an ssh_id.sh based helper and is useful for building
cluster lockers that know how to identify a host and access it to verify
if a process is no longer running.

## ToDo

### fast_lock.sh

* My testing has shown that fast_lock does not really benefit from a grace
period on deleting markdirs, remove it.

* Currently the fast_lock mechanism has constraints which prevent markers
from being assumed to be stale.  A simple update to the constraints, checking
both that the move is successful and that the id leaf exists after the move,
will allow this.  This would prevent the need for expensive staleness checks
to have to be performed on markdirs to clean them.

* With the above improvements it should be possible to expose a clean method
to wrappers.  This clean can then be layered up the stack to reduce the amount
of internal knowledge of fast_lock's mechanics.

* It is possible to convert fast_lock to only use directories (currently
the leaf is a file).  This conversion makes it possible to use a single
`mkdir -p` to create markdirs making themselves potentially even less likely to
get interrupted.


### all

* It might be helpful to be more object oriented and use "file" (object) level
variables instead of passing around arguments like `$lock` to every
method.  Cleaning this up reduces much of the code and pushes most argument
checking to the script level.


### other lock types

* create a rw_lock

* create a "fair" lock

* create a "fair" semaphore (might be possible without a "fair" lock)

