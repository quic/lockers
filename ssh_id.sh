#!/usr/bin/env bash
#
# Copyright (c) 2013, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

qerr() { "$@" 2>/dev/null ; } # execute a cmd and quiet the stderr

SSH_LOGIN=(ssh -o StrictHostKeyChecking=yes -o PasswordAuthentication=no)

ERR_HOST_INCOMPATIBLE=10
ERR_FQDN_MISSMATCH=11
ERR_MALFORMED_UID=20
ERR_MISSING_ARG=127

fqdn() { "${SSH_LOGIN[@]}" "$host" hostname --fqdn ; } # host

is_host_compatible() { # host
    local host=$1
    local fqdn=$(fqdn "$host")
    [ -z "$fqdn" ] && return $ERR_HOST_INCOMPATIBLE
    [ "$host" = "$fqdn" ] && return
    [ "$fqdn" = "$(fqdn "$fqdn")" ] || return $ERR_HOST_INCOMPATIBLE
}

ssh_uid() { # fqdn_host pid > uid (if running)
    local host="$1" pid=$2
    ( [ -n "$host" ] && [ -n "$pid" ] ) || return $ERR_MISSING_ARG

    qerr "${SSH_LOGIN[@]}" "$host"\
        hostname --fqdn ';'\
        awk "'\$1 == \"btime\" {print \$2}'" /proc/stat ';'\
        awk "'{print \$22}'" /proc/$pid/stat |\
        {
            read fqdn ; read boot ; read starttime
            [ -z "$fqdn" ] && return $ERR_HOST_INCOMPATIBLE
            [ "$host" != "$fqdn" ] && return $ERR_FQDN_MISSMATCH
            [ -z "$boot" ] && return $ERR_HOST_INCOMPATIBLE

            [ -z "$starttime" ] && return 0
            echo "$fqdn:$pid:$starttime:$boot"
        }
}

is_stale() {  # uid
   local uid=$1
   [ -z "$uid" ] && return $ERR_MISSING_ARG

   local host=$(host "$uid") pid=$(pid "$uid")
   ( [ -n "$host" ] && [ -n "$pid" ] ) || return $ERR_MALFORMED_UID

   local ssh_uid rtn
   ssh_uid=$(ssh_uid "$host" "$pid") ; rtn=$?
   [ $rtn = $ERR_HOST_INCOMPATIBLE ] && return $ERR_HOST_INCOMPATIBLE
   [ $rtn = $ERR_FQDN_MISSMATCH ] && return $ERR_FQDN_MISSMATCH

   [ -z "$ssh_uid" ] && return 0 # no starttime
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
