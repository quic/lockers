#!/usr/bin/env bash
#
# Copyright (c) 2013, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

# Ignoring host keys here allows an attacker to potentially spoof the staleness
# of an id. Ignoring host keys can drastically reduce the maintenance burden
# otherwise required to set each host in a cluster up to know about all the other
# hosts in the cluster. Known host tracking is likely intractable in dynamic host
# environments such as in the cloud with kubernetes.
# StrictHostKeyChecking=yes forces rejection on new o changed keys
# StrictHostKeyChecking=no  forces rejection on changed keys, but auto accepts new keys
# StrictHostKeyChecking=no UserKnownHostsFile=/dev/null forces accept on new or changed keys
SSH_LOGIN=(ssh -o PasswordAuthentication=no)
SSH_LOGIN+=(-o StrictHostKeyChecking=no)
SSH_LOGIN+=(-o UserKnownHostsFile=/dev/null)

ERR_SSHDEST_INCOMPATIBLE=10
ERR_HOSTID_MISSMATCH=11
ERR_UID_FETCH=12
ERR_INCOMPLETE=13
ERR_MALFORMED_UID=20
ERR_MISSING_ARG=127

MARKER=COMPLETED

qerr() { "$@" 2>/dev/null ; } # execute a cmd and quiet the stderr

d() { [ "$DEBUG" = "DEBUG" ] && { echo "$(date) " ; } } # > date(debug) | nothing
error() { echo "$(d) ERROR - $1" >&2 ; exit $2 ; }

dest2hostid() { "${SSH_LOGIN[@]}" "$1" hostname --fqdn ; } # dest > hostid

notifier() { echo "$3" >&2 ; } # checking_host id message

notify() { # id reason
  local hostid=$(hostname --fqdn)
  "${NOTIFIER[@]}" "$hostid" "$1" "WARNING: host($hostid) is unable to identify live/staleness for $1: $2"
}

_hostid() { echo "$1" | awk -F: '{print $1}' ; } # uid > hostid
_pid() { echo "$1" | awk -F: '{print $2}' ; } # uid > pid
_starttime() { echo "$1" | awk -F: '{print $3}' ; } # uid > starttime
_boottime() { echo "$1" | awk -F: '{print $4}' ; } # uid > boottime

is_host_compatible() { # sshdest|hostid
    local dest=$1
    local dest_hostid=$(dest2hostid "$dest")
    [ -z "$dest_hostid" ] && return $ERR_SSHDEST_INCOMPATIBLE
    [ "$dest" = "$dest_hostid" ] && return
    [ "$dest_hostid" = "$(dest2hostid "$dest_hostid")" ] || return $ERR_HOSTID_MISSMATCH
}

ssh_uid() { # hostid pid [marker] > uid[marker] (if running)
    local hostid="$1" pid=$2 marker=$3
    ( [ -n "$hostid" ] && [ -n "$pid" ] ) || return $ERR_MISSING_ARG
    local sshdest=$hostid

    qerr "${SSH_LOGIN[@]}" "$sshdest"\
        hostname --fqdn ';'\
        awk "'\$1 == \"btime\" {printf(\"%s $marker\n\", \$2)}'" /proc/stat ';'\
        awk "'BEGIN {getline < \"/proc/$pid/stat\"; printf(\"%s $marker\n\", \$22)}'" < /dev/null |\
        {
            read dest_hostid ; read boot checkboot ; read starttime checkstart
            [ -z "$dest_hostid" ] && return $ERR_SSHDEST_INCOMPATIBLE
            [ "$hostid" != "$dest_hostid" ] && return $ERR_HOSTID_MISSMATCH
            [ -z "$boot" ] && return $ERR_SSHDEST_INCOMPATIBLE
            [ "$checkboot" = "$marker" ] || return $ERR_INCOMPLETE
            [ "$checkstart" = "$marker" -o "$starttime" = "$marker" ] || return $ERR_INCOMPLETE

            echo "$dest_hostid:$pid:$starttime:$boot$marker"
            return 0
        }
}

is_valid_uid() {  # uid # (SETS hostid pid starttime boottime)
    local uid=$1
    hostid=$(_hostid "$uid")
    pid=$(_pid "$uid")
    starttime=$(_starttime "$uid")
    boottime=$(_boottime "$uid")
    [ -n "$hostid" ] && [ -n "$pid" ] && [ -n "$starttime" ] && [ -n "$boottime" ]
}

validate_uid() {  # uid # (SETS hostid pid starttime boottime)
    local uid=$1
    if ! is_valid_uid "$uid" ; then
        notify "$uid" "Malformed UID"
        return $ERR_MALFORMED_UID
    fi
}

hostid() { validate_uid "$1" && echo "$hostid" ; } # uid > hostid
sshdest() { hostid "$1" ; } # uid > sshdest
pid() {  validate_uid "$1" && echo "$pid" ; } # uid > pid

is_stale() {  # uid
    local uid=$1
    [ -z "$uid" ] && return $ERR_MISSING_ARG

    local hostid pid
    validate_uid "$uid" || return

    local ssh_uid rtn
    ssh_uid=$(ssh_uid "$hostid" "$pid" "$MARKER") ; rtn=$?
    if [ $rtn -gt 1 ] ; then
        if [ $rtn = $ERR_SSHDEST_INCOMPATIBLE ] ; then
            notify "$uid" "SSHDEST Incompatible"
        elif [ $rtn = $ERR_HOSTID_MISSMATCH ] ; then
            notify "$uid" "HOSTID Missmatch"
        else
            notify "$uid" "Unknown"
        fi
        return $rtn
    fi

    if ! echo "$ssh_uid" | grep -q "$MARKER"'$' ; then
        notify "$uid" "Check Incomplete"
        return $ERR_INCOMPLETE
    fi

    [ "$ssh_uid" == "$uid$MARKER" ] && return 1

    # Linux bootimes can vary by up to one second:
    #   https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=119971
    uid=$hostid:$pid:$starttime:$(($boottime +1))
    [ "$ssh_uid" == "$uid$MARKER" ] && return 1

    uid=$hostid:$pid:$starttime:$(($boottime -1))
    [ "$ssh_uid" == "$uid$MARKER" ] && return 1

    return 0 # Likely no starttime or different boottime
}

uid() { # pid > uid
    local pid=$1
    [ -z "$pid" ] && return $ERR_MISSING_ARG
    local starttime=$(qerr awk '{print $22}' /proc/"$pid"/stat) # starttime=22
    [ -z "$starttime" ] && return 1 # no longer running
    local boot=$(qerr awk '$1 == "btime" {print $2}' /proc/stat)
    [ -z "$boot" ] && error "Cannot determine local host boottime" $ERR_UID_FETCH
    local hostid=$(hostname --fqdn)
    [ -z "$hostid" ] && error "Cannot determine local hostid" $ERR_UID_FETCH

    echo "$hostid:$pid:$starttime:$boot"
}

usage() { # error_message
    local prog=$(basename -- "$0")
    cat >&2 <<EOF

    usage: $prog [nopts] is_stale <uid>
           $prog uid <pid> > <uid>  (must be run on host)

           $prog [nopts] pid <uid> > <pid>
           $prog [nopts] hostid <uid> > <hostid>
           $prog [nopts] sshdest <uid> > <sshdest>

           $prog is_valid_uid <uid>
           $prog is_host_compatible <sshdest|hostid>

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
