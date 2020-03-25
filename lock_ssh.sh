#!/usr/bin/env bash
#
# Copyright (c) 2013, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

usage() { # error_message
    local prog=$(basename -- "$0")
    cat >&2 <<EOF

    usage: $prog [opts][gopts] lock <lock_path> <pid>
           $prog [opts] lock_check <lock_path> <pid>
           $prog [opts][gopts] unlock <lock_path> <pid|uid>

           $prog [opts] fast_lock <lock_path> <pid>
           $prog [opts] owner <lock_path> > uid
           $prog [opts] owner_pid <lock_path> > pid
           $prog [opts] owner_hostid <lock_path> > hostid
           $prog [opts] is_mine <lock_path> <pid|uid>

           $prog is_host_compatible <sshdest|hostid>

    A lock manager designed for cluster use via a shared filesystem with
    ssh run checks.

    gopts (grace options):

    --grace-seconds <seconds>

    seconds   The amount of time a lock component needs to be untouched for
              before even considering checking it for staleness.  Checking
              for staleness requires logging into the lock host via ssh.
              To prevent multiple checkers, set this to longer then the worst
              case check time.  The longest potential stale recovery time is
              the sum of the worst case check time and twice this delay.

              The default is 10s.

    opts (global options)

    --on-check-fail notifier  Specify a notifier to run a command when
                              it is not possible to determine
                              live/staleness.  Args may be added by
                              using --on-check-notifier multiple times.
                              (Default notifier prints warnings to stderr)

                              The notifier should expect the following
                              trailing arguments:
                              <lock> <locking_host> <uid> <reason>

EOF
    [ $# -gt 0 ] && echo "Error - $@" >&2
    exit 10
}

MYPATH=$(readlink -e -- "$0")
MYDIR=$(dirname -- "$MYPATH")

"$MYDIR/lib/hostpid_lock.sh" --idhelper "$MYDIR/ssh_id.sh" "$@"
