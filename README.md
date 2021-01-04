The lockers package contains various locking mechanism and building blocks.

The package is structured such that lockers that would likely be used by
applications directly are in the top level directory. Low level building
blocks not intended for application use are in the `lib` subdirectory.

The main test entry point is `test/package.sh` meant for automation usage.
The setup to run tests in a dockerized environment is also provided at
`test/docker`, `test/docker/run.sh` is the main entry point.


## Staleness Checkers

The `<policy>_lock.sh` scripts can implement a staleness checking policy, but
they need helpers to do the actual staleness checking.  Checking for
staleness requires a basic understanding of the ids used for locking.  The
`<type>_id.sh` scripts help implement unique ids within a certain context,
along with a way to check these ids for staleness.  Some of the helpers are:

* `local_id.sh`:  Uses a process pid as a basis along with more data to uniquely
              identify a process.  This id helper expects a single host as a
              context.

* `ssh_id.sh`:  Uses a process pid and the process' hostname as a basis along
            with more data to uniquely identify a process in a cluster.
            This id helper can thus be used across machines in a cluster
            as long as automated ssh access to each machine is setup.


## Higher Level Lockers

Although it is possible to build a custom locker using the lower level locker
building blocks mentioned up to this point, there are some pre-built higher
level lockers meant for more general consumption.  These higher level lockers
generally combine a staleness policy helper with a staleness checker to
create a simple to use locker.  The following higher level lockers are
currently recommended for use:

* `lock_local.sh`:  Combines `check_lock.sh` with `local_id.sh`.  Meant for use on a
                single machine.
* `lock_ssh.sh`:  Combines `grace_lock.sh` with `ssh_id.sh`.  Meant for use on a
              cluster via a shared filesystem.


## Semaphores

This directory also has a semaphore implementation: `semaphore.sh`.  This
semaphore defaults to using `lock_local.sh` as its internal locker
implementation.  However, it is also capable of using an alternate locker
implementation.

## ToDo

See the [lib/README.md](./lib/README.md) for low level ToDos


### zookeeper

* create a `zookeeper_lock.sh` (mimicks `fast_lock.sh`)

* create a `zookeeper_grace_lock.sh` (mimics `grace_lock.sh`) recovery policy

* create a `lock_ssh_zookeeper.sh` (mimics `lock_ssh.sh`) a high level locker


### higher level lockers

* The higher level lockers miss-guided error messages when used with a stale
id, this should be cleaned up.

* Potentially create a multi-lock helper that can share multiple high level
lockers


### queues

* The task_bucket could benefit from reliable fast clean methods.  Ways to
force a clean is needed to more efficiently close buckets with many servers
and many tasks.

* The fs_queue needs a way to kill tasks.  That is possible currently with
a hack by using the PID of the semaphore.  It might make sense to push
killing down to the id helper level?  Then some high level lockers could be
modified to kill their owners?  (If we have the id from the helper, it might
be OK to bypass the high level locker)?


### Gerrit

* The proposed replicate_all script probably needs a way to identify if lock
owners are stale, so high level lockers may want to expose this.

## Copyright and License

```text
Copyright (c) 2013, Qualcomm Innovation Center, Inc. All rights reserved.
SPDX-License-Identifier: BSD-3-Clause
```
