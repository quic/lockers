#!/usr/bin/env bash
#
# Copyright (c) 2013, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

qerr() { "$@" 2>/dev/null ; } # execute a cmd and quiet the stderr

is_running() {  # uid
   [ -z "$1" ] && return 1
   [ -n "$(pid "$1")" ]
}

uid() { # pid > uid
    local run_data=$(qerr awk '{print $4 ":" $22}' /proc/$1/stat) # ppid=4 starttime=22
    [ -z "$run_data" ] && return 1 # no longer running
    local boot=$(qerr awk '$1 == "btime" {print $2}' /proc/stat)
    local host=$(hostname --fqdn)

    echo "$host:$1:$run_data:$boot"
}

ssh_uid() { # host pid > uid
                          # ppid=4 starttime=22
    qerr ssh "$1" awk "'{print \$4 \":\" \$22}'" /proc/$2/stat ';'\
               hostname --fqdn ';'\
               awk "'\$1 == \"btime\" {print \$2}'" /proc/stat |\
    {
        read run_data
        read host
        read boot
        echo "$host:$2:$run_data:$boot"
    }
}

pid() { # uid > pid (or blank if pid not running)
    local host=$(host "$1")
    [ -z "$host" ] && return 1
    local pid=$(echo "$1" | awk -F: '{print $2}')
    local uid=$(ssh_uid "$host" "$pid")
    [ "$uid" = "$1" ] && echo "$pid"
}

host() { # uid > host
    echo "$1" | awk -F: '{print $1}'
}

usage() { # error_message
    local prog=$(basename "$0")
    cat <<EOF

    usage: $prog is_running <uid>
           $prog uid <pid> > <uid>  (must be run on host)
           $prog ssh_uid <host> <pid> > <uid>
           $prog pid <uid> > pid (or blank if pid not running)
           $prog host <uid> > host

    A remote host process id/uid manipulator and runchecker using ssh.
    Unlike a pid alone, this gives a safe way to identify currently running
    processes and to compare them with uids against no longer running
    processes even once the pids have wrapped around.  This safety is
    achieved by including the following in the uid: the host, pid,
    parent pid, start time, and boot time.  Naturally, this only works if
    the running user can ssh freely into any ssh host associated with the
    uid using the hostname which the host reports.

EOF
    [ $# -gt 0 ] && echo "Error - $@" >&2
    exit 10
}

[ $# -lt 2 ] && usage "no pid|uid specified"

"$@"
