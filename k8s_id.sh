#!/usr/bin/env bash
#
# Copyright (c) 2021, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

ERR_UID_FETCH=12
ERR_MALFORMED_UID=20
ERR_NOT_IN_K8=30
ERR_MISSING_ARG=127
ERR_INCOMPLETE=13

# Minimum seconds to determine a missed heartbeat. The default delay
# between heartbeats in K8s v1.20 is 5mins. This value provides a
# 10 seconds threshold to it.
SECONDS_HEARTBEAT_DELAY=310

qerr() { "$@" 2>/dev/null ; } # execute a cmd and quiet the stderr
error() { echo "ERROR - $1" >&2 ; exit $2 ; }

notifier() { echo "$3" >&2 ; } # checking_host id message

wait_for() { # timeout cmd [args]...
    local timeout=$1 ; shift
    local remaining_time
    for remaining_time in $(seq "$timeout" -2 1) ; do
        "$@" && return
        sleep 2s
    done
    return 1
}

notify() { # id reason
  local hostid=$(pod_uhost)
  "${NOTIFIER[@]}" "$hostid" "$1" "WARNING: host($hostid) is unable to identify live/staleness for $1: $2"
}

_hostid() { echo "$1" | awk -F: '{print $1}' ; } # uid > hostid
_pid() { echo "$1" | awk -F: '{print $2}' ; } # uid > pid
_starttime() { echo "$1" | awk -F: '{print $3}' ; } # uid > starttime
_boottime() { echo "$1" | awk -F: '{print $4}' ; } # uid > boottime

_node() { _hostid "$1" | awk -F+ '{print $1}' ; } # uid > node_name
_namespace() { _hostid "$1" | awk -F+ '{print $2}' ; } # uid > namespace
_pod_name() { _hostid "$1" | awk -F+ '{print $3}' ; } # uid > pod_name
_pod_uid() { _hostid "$1" | awk -F+ '{print $4}' ; } # uid > pod_uid

is_host_compatible() {
    [ -n "$POD_NODE" ] && [ -n "$POD_NAMESPACE" ] && \
    [ -n "$POD_NAME" ] && [ -n "$POD_UID" ] || return $ERR_NOT_IN_K8
}

pod_uhost() {
    is_host_compatible || return

    # pod_uid and namespace could alone give unique id, but
    # node and pod name are required for staleness checks
    # and to exec into them.

    # From the naming convetions of K8s objects explained in the references below
    # it is assumed that chances of occurance of character '+' are low and hence
    # used as a delimeter.
    #
    # https://kubernetes.io/docs/concepts/overview/working-with-objects/names/
    # https://github.com/kubernetes/community/blob/master/contributors/design-proposals/architecture/identifiers.md
    #
    # Below are sentences quoted from the references which contributes the above assumption: 
    #
    # 1. Most resource types require a name that can be used as a DNS subdomain/label name as defined in RFC 1123.
    #      - contain at most 63 characters
    #      - contain only lowercase alphanumeric characters or '-'
    #      - start with an alphanumeric character
    #      - end with an alphanumeric character
    # 2. Some resource types require their names to be able to be safely encoded as a path segment.
    #    In other words, the name may not be "." or ".." and the name may not contain "/" or "%"
    echo "${POD_NODE}+${POD_NAMESPACE}+${POD_NAME}+${POD_UID}"
}

is_valid_uid() { # uid
    local uid=$1
    [ -n "$(_hostid "$uid")" ] && [ -n "$(_pid "$uid")" ] && \
    [ -n "$(_starttime "$uid")" ] && [ -n "$(_boottime "$uid")" ] && \
    [ -n "$(_node "$uid")" ] && [ -n "$(_namespace "$uid")" ] && \
    [ -n "$(_pod_name "$uid")" ] && [ -n "$(_pod_uid "$uid")" ]
}

validate_uid() { # uid
    local uid=$1
    if ! is_valid_uid "$uid" ; then
        notify "$uid" "Malformed UID"
        return $ERR_MALFORMED_UID
    fi
}

is_process_stale() { # uid
    local uid=$1
    local pid=$(_pid "$uid")
    local starttime=$(_starttime "$uid")
    local boottime=$(_boottime "$uid")
    local namespace=$(_namespace "$uid")
    local pod_name=$(_pod_name "$uid")
    local curr_info
    local marker=COMPLETED

    local curr_info=$(kubectl -n "$namespace" exec "$pod_name" -- \
                    awk -v pid="$pid" -v marker="$marker" '$1 == "btime" \
                    { btime=$2 ; \
                      pidfile="/proc/"pid"/stat" ; getline < pidfile ; \
                      print btime, $22, $3, marker \
                    }' /proc/stat 2>/dev/null)  || return 1

    curr_boottime=$(echo "$curr_info" | awk 'NR==1 {print $1}' ; )
    curr_starttime=$(echo "$curr_info" | awk 'NR==1 {print $2}' ; )
    curr_state=$(echo "$curr_info" | awk 'NR==1 {print $3}' ; )
    curr_marker=$(echo "$curr_info" | awk 'NR==1 {print $4}' ; )

    [ -z "$curr_boottime" ] && return 1
    if [ "$curr_marker" != "$marker" ] ; then
        [ "$curr_state" = "$marker" -o "$curr_starttime" = "$marker" ] || return $ERR_INCOMPLETE
    fi

    # treat zombie processes as stale
    [ -z "$curr_starttime" -o -z "$curr_state" -o "$curr_state" = "Z" ] && return 0
    # Linux bootimes can vary by up to one second:
    #   https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=119971
    [ "$curr_boottime" = "$boottime" ] || \
        [ "$curr_boottime" = "$(($boottime +1))" ] || \
            [ "$curr_boottime" = "$(($boottime -1))" ] || return 0
    [ "$curr_starttime" != "$starttime" ]
}

is_pod_not_registered() { # uid
    local uid=$1
    local namespace=$(_namespace "$uid")
    local pod_name=$(_pod_name "$uid")
    local pod_uid=$(_pod_uid "$uid")
    local curr_pod_uid
    if ! curr_pod_uid=$(kubectl -n "$namespace" get pod "$pod_name" \
                            -o jsonpath="{.metadata.uid}" 2>&1) ; then
        echo "$curr_pod_uid" | grep -q "\"$pod_name\" not found"
        return
    fi
    [ -n "$curr_pod_uid" -a "$pod_uid" != "$curr_pod_uid" ]
}

node_heartbeat_epoch() { # node > date_in_seconds_since_epoch
    local heartbeat=$(kubectl get node "$1" -o \
                    jsonpath="{.status.conditions[?(@.type == 'Ready')].lastHeartbeatTime}")
    # < 2021-03-09T18:27:59Z > 1615314479
    date --date="$heartbeat" +"%s"
}

is_heartbeat_ge_epoch() { [ "$(node_heartbeat_epoch "$1")" -ge "$2" ] ; } # node date_in_seconds_since_epoch

is_node_receiving_heartbeats() { # node
    local epoch_now=$(date +"%s")
    wait_for "$SECONDS_HEARTBEAT_DELAY" "is_heartbeat_ge_epoch" "$1" "$epoch_now"
}

is_node_ready() { # node
    [ "$(kubectl get node "$1" -o \
        jsonpath="{.status.conditions[?(@.type == 'Ready')].status}")" = "True" ]
}

is_pod_stale() { # uid
    local uid=$1
    if is_pod_not_registered "$uid" ; then
        local node="$(_node "$uid")"
        # is_pod_not_registered doesn't mean pod is not running, it may
        # still be running but disconnected from the network (api server).
        # If node is active and sending heartbeats, then we can confirm
        # is_pod_not_registered implies pod is not running.
        if is_node_ready "$node" ; then
            if is_node_receiving_heartbeats "$node" ; then
                is_pod_not_registered "$uid" && return 0
            fi
        fi
    fi
    return 1
}

is_stale() { # uid
    local uid=$1
    [ -z "$uid" ] && return $ERR_MISSING_ARG

    validate_uid "$uid" || return
    is_pod_stale "$uid" && return 0
    is_process_stale "$uid"
}

uid() { # pid > uid
    # Sample Format: node+namespace+pod_name+pod_uid:process_id:process_starttime:node_boottime
    local pid=$1
    [ -z "$pid" ] && return $ERR_MISSING_ARG
    local starttime=$(qerr awk '{print $22}' /proc/"$pid"/stat) # starttime=22
    [ -z "$starttime" ] && return 1 # no longer running
    local boottime=$(qerr awk '$1 == "btime" {print $2}' /proc/stat)
    [ -z "$boottime" ] && error "Cannot determine local host boottime" $ERR_UID_FETCH
    local hostid
    hostid=$(pod_uhost) || error "Cannot determine local hostid" $?

    echo "$hostid:$pid:$starttime:$boottime"
}

usage() { # error_message
    local prog=$(basename -- "$0")
    cat >&2 <<EOF

    usage: $prog [nopts] is_stale <uid>
           $prog uid <pid> > <uid>  (must be run on host)
           $prog is_valid_uid <uid>

    A remote host process id/uid manipulator and runchecker using k8s.
    A uid is used to identify currently running processes and to compare
    them with no longer running processes.  The following is included in
    the uid: pod_id, pid, start time, and boot time. pod_id: node name,
    namespace, pod name, pod uid.

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
