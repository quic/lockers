#!/usr/bin/env bash
#
# Copyright (c) 2013, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

SSH_LOGIN=(ssh -o StrictHostKeyChecking=yes -o PasswordAuthentication=no)

ERR_HOST_INCOMPATIBLE=10
ERR_FQDN_MISSMATCH=11
ERR_UID_FETCH=12
ERR_MALFORMED_UID=20
ERR_MISSING_ARG=127

qerr() { "$@" 2>/dev/null ; } # execute a cmd and quiet the stderr

d() { [ "$DEBUG" = "DEBUG" ] && { echo "$(date) " ; } } # > date(debug) | nothing
error() { echo "$(d) ERROR - $1" >&2 ; exit $2 ; }

fqdn() { "${SSH_LOGIN[@]}" "$host" hostname --fqdn ; } # host

notifier() { echo "$3" >&2 ; } # checking_host id message

notify() { # id reason
  local host=$(hostname --fqdn)
  "${NOTIFIER[@]}" "$host" "$1" "WARNING: host($host) is unable to identify live/staleness for $1: $2"
}

_host() { echo "$1" | awk -F: '{print $1}' ; } # uid > host
_pid() { echo "$1" | awk -F: '{print $2}' ; } # uid > pid
_starttime() { echo "$1" | awk -F: '{print $3}' ; } # uid > starttime
_boottime() { echo "$1" | awk -F: '{print $4}' ; } # uid > boottime

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

is_valid_uid() {  # uid # (SETS host pid starttime boottime)
    local uid=$1
    host=$(_host "$uid")
    pid=$(_pid "$uid")
    starttime=$(_starttime "$uid")
    boottime=$(_boottime "$uid")
    [ -n "$host" ] && [ -n "$pid" ] && [ -n "$starttime" ] && [ -n "$boottime" ]
}

validate_uid() {  # uid # (SETS host pid starttime boottime)
    local uid=$1
    if ! is_valid_uid "$uid" ; then
        notify "$uid" "Malformed UID"
        return $ERR_MALFORMED_UID
    fi
}

host() { validate_uid "$1" && echo "$host" ; } # uid > host
pid() {  validate_uid "$1" && echo "$pid" ; } # uid > pid

is_stale() {  # uid
    local uid=$1
    [ -z "$uid" ] && return $ERR_MISSING_ARG

    local host pid
    validate_uid "$uid" || return

    local ssh_uid rtn
    ssh_uid=$(ssh_uid "$host" "$pid") ; rtn=$?
    if [ $rtn -gt 1 ] ; then
        if [ $rtn = $ERR_HOST_INCOMPATIBLE ] ; then
            notify "$uid" "Host Incompatible"
        elif [ $rtn = $ERR_FQDN_MISSMATCH ] ; then
            notify "$uid" "FQDN Missmatch"
        else
            notify "$uid" "Unknown"
        fi
        return $rtn
    fi

    [ -z "$ssh_uid" ] && return 0 # no starttime
    [ "$ssh_uid" != "$uid" ] # different boottime
}

uid() { # pid > uid
    local pid=$1
    [ -z "$pid" ] && return $ERR_MISSING_ARG
    local starttime=$(qerr awk '{print $22}' /proc/"$pid"/stat) # starttime=22
    [ -z "$starttime" ] && return 1 # no longer running
    local boot=$(qerr awk '$1 == "btime" {print $2}' /proc/stat)
    [ -z "$boot" ] && error "Cannot determine local host boottime" $ERR_UID_FETCH
    local host=$(hostname --fqdn)
    [ -z "$host" ] && error "Cannot determine local hostname" $ERR_UID_FETCH

    echo "$host:$pid:$starttime:$boot"
}

usage() { # error_message
    local prog=$(basename "$0")
    cat >&2 <<EOF

    usage: $prog [nopts] is_stale <uid>
           $prog uid <pid> > <uid>  (must be run on host)

           $prog [nopts] pid <uid> > pid
           $prog [nopts] host <uid> > host

           $prog is_valid_uid uid
           $prog is_host_compatible host

    A remote host process id/uid manipulator and runchecker using ssh.
    A uid is used to identify currently running processes and to compare
    them with no longer running processes.  The following is included in
    the uid: hostname(fqdn), pid, start time, and boot time.  Staleness
    can only be confirmed when the current user can ssh freely into any
    ssh host associated with the uid using the hostname(fqdn) which the
    host reports.  Use is_host_compatible to manually check a user and
    host's ssh setup for compatability with this id manipulator.

    nopts (notifier options):

    --on-check-fail notifier  Specify a notifier to run a command when
                              it is not possible to determine
                              live/staleness.  Args may be added by
                              using --on-check-notifier multiple times.
                              (Default notifier prints warnings to stderr)

                              The notifier should expect the following
                              trailing arguments:
                                  <checking_host> <uid> <reason>
EOF
    [ $# -gt 0 ] && echo "Error - $@" >&2
    exit 10
}

while [ $# -gt 0 ] ; do
   case "$1" in
       --on-check-fail) shift ; NOTIFIER+=("$1") ;;
       *) break ;;
   esac
   shift
done
[ -z "$NOTIFIER" ] && NOTIFIER=(notifier)

[ $# -lt 2 ] && usage "no pid|uid specified"

"$@"
