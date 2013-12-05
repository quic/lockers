#!/usr/bin/env bash
#
# Copyright (c) 2013, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

qerr() { "$@" 2>/dev/null ; } # execute a cmd and quiet the stderr

is_host_compatible() { # host
    local junk rtn
    junk=$(ssh_uid "$1") ; rtn=$?
    [ $rtn -eq 10 ] || [ $rtn -eq 11 ] && return $rtn
    return 0
}

ssh_uid() { # host pid > uid (if running)
    local host=$1 pid=$2
    [ -z "$host" ] && return 1

    qerr ssh -o StrictHostKeyChecking=yes \
             -o PasswordAuthentication=no "$host" \
        hostname --fqdn ';'\
        awk "'\$1 == \"btime\" {print \$2}'" /proc/stat ';'\
        awk "'{print \$22}'" /proc/$pid/stat |\
        {
            read fqdn ; read boot ; read starttime
            [ -z "$fqdn" ] && return 10
            [ -z "$boot" ] && return 11

            # missing arg, but allow ssh test anyway for is_host_compatible
            [ -z "$pid" ] && return 2
            [ -z "$starttime" ] && return 0
            echo "$fqdn:$pid:$starttime:$boot"
        }
}

is_stale() {  # uid
   local uid=$1
   [ -z "$uid" ] && return 1

   local host=$(host "$uid") pid=$(pid "$uid")
   [ -n "$host" ] || return 1

   local ssh_uid
   ssh_uid=$(ssh_uid "$host" "$pid") || return 1
   [ -z "$ssh_uid" ] && return 0 # no starttime
   [ "$host" == "$(host "$ssh_uid")" ] || return 1
   [ "$ssh_uid" != "$uid" ] # different boottime
}

host() { echo "$1" | awk -F: '{print $1}' ; } # uid > host

pid() { echo "$1" | awk -F: '{print $2}' ; } # uid > pid

uid() { # pid > uid
    local starttime=$(qerr awk '{print $22}' /proc/$1/stat) # starttime=22
    [ -z "$starttime" ] && return 1 # no longer running
    local boot=$(qerr awk '$1 == "btime" {print $2}' /proc/stat)
    local host=$(hostname --fqdn)

    echo "$host:$1:$starttime:$boot"
}

usage() { # error_message
    local prog=$(basename "$0")
    cat >&2 <<EOF

    usage: $prog is_stale <uid>
           $prog uid <pid> > <uid>  (must be run on host)

           $prog pid <uid> > pid
           $prog host <uid> > host

           $prog is_host_compatible host

    A remote host process id/uid manipulator and runchecker using ssh.
    A uid is used to identify currently running processes and to compare
    them with no longer running processes.  The following is included in
    the uid: hostname(fqdn), pid, start time, and boot time.  Staleness
    can only be confirmed when the current user can ssh freely into any
    ssh host associated with the uid using the hostname(fqdn) which the
    host reports.  Use is_host_compatible to manually check a user and
    host's ssh setup for compatability with this locker.

EOF
    [ $# -gt 0 ] && echo "Error - $@" >&2
    exit 10
}

[ $# -lt 2 ] && usage "no pid|uid specified"

"$@"
