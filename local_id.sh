#!/usr/bin/env bash
#
# Copyright (c) 2013, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

q() { "$@" 2>/dev/null ; } # execute a cmd and quiet the stderr

is_stale() {  # uid
   [ -n "$1" ] || return 0
   [ -z "$(pid "$1")" ]
}

uid() { # pid > uid
    local run_data=$(q awk '{print $22}' /proc/$1/stat) # starttime=22
    [ -z "$run_data" ] && return 1 # no longer running
    local boot=$(awk '/btime/{print $2}' /proc/stat)

    echo "$1:$run_data:$boot"
}

pid() { # uid > pid (or blank if pid not running)
    local pid=$(echo "$1" | awk -F: '{print $1}')
    local uid=$(uid "$pid")
    [ "$uid" = "$1" ] && echo "$pid"
}

usage() { # error_message
    local prog=$(basename "$0")
    cat <<EOF

    usage: $prog is_stale <uid>
           $prog uid <pid> > <uid>
           $prog pid <uid> > pid (or blank if pid not running)

    A local host process id/uid manipulator and runchecker.  Unlike a pid
    alone, this gives a safe way to identify currently running processes
    and to compare them with uids against no longer running processes even
    once the pids have wrapped around.  This safety is achieved by including
    the following in the uid:  the pid, start time, and boot time.

EOF
    [ $# -gt 0 ] && echo "Error - $@" >&2
    exit 10
}

[ $# -lt 2 ] && usage "no pid|uid specified"

"$@"
