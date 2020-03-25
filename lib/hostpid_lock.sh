#!/usr/bin/env bash
#
# Copyright (c) 2020, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

ERR_MALFORMED_UID=20

d() { [ "$DEBUG" = "DEBUG" ] && { echo "$(date) " ; } } # > date(debug) | nothing
error() { echo "$(d) ERROR - $1" >&2 ; exit $2 ; }

uid() { "${ID_HELPER[@]}" uid "$1" ; } # pid|uid > uid
pid() { "${ID_HELPER[@]}" pid "$1" ; } # pid|uid > pid
hostid() { "${ID_HELPER[@]}" hostid "$1" ; } # uid > hostid
compatible() { "${ID_HELPER[@]}" is_host_compatible "$1" ; } # host

checker_args() { # args...
    local sw=''
    while [ $# -gt 0 ] ; do
        [ "${#CHECKER[@]}" -gt 0 ] && sw="--checker-arg"
        CHECKER+=($sw "$1")
        shift
    done
}

usage() { # error_message
    local prog=$(basename "$0")
    cat >&2 <<EOF

    usage: $prog [opts][gopts] lock <lock_path> <pid>
           $prog [opts] lock_check <lock_path> <pid>
           $prog [opts][gopts] unlock <lock_path> <pid|uid>

           $prog [opts] fast_lock <lock_path> <pid>
           $prog [opts] owner <lock_path> > uid
           $prog [opts] owner_pid <lock_path> > pid
           $prog [opts] owner_hostid <lock_path> > hostid
           $prog [opts] is_mine <lock_path> <pid|uid>

           $prog is_host_compatible <host>

    A lock manager designed for cluster use via a shared filesystem. Lock
    owner uids should be comprised of unique hostids and unique pids.

    gopts (grace options):

    --grace-seconds <seconds>

    seconds   The amount of time a lock component needs to be untouched for
              before even considering checking it for staleness. To prevent
              multiple checkers, set this to longer then the worst case check
              time.  The longest potential stale recovery time is the sum of
              the worst case check time and twice this delay.

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

     --idhelper <cmd/arg>     The id helper must support the following
                              commands:

                                  uid <pid|uid> > uid
                                  pid <pid|uid> > pid
                                  hostid <uid> > hostid
                                  is_host_compatible <host>

     --checker <cmd/arg>      The checker must support the following
                              command:


EOF
    [ $# -gt 0 ] && echo "Error - $@" >&2
    exit 10
}

MYPATH=$(readlink -e "$0")
MYDIR=$(dirname "$MYPATH")

ID_HELPER=()
CHECKER=()
GRACE_SECONDS=10
while [ $# -gt 0 ] ; do
    case "$1" in
        -di|--info) DEBUG=INFO ;;
        -d|--debug)
            DEBUG=DEBUG
            LOCKER_ARGS+=("$1")
        ;;
        --grace-seconds) GRACE_SECONDS=$2 ; shift ;;
        --on-check-fail) CHECK_FAIL+=("$1" "$2") ; shift ;;
        --idhelper) shift ; ID_HELPER+=("$1") ;;
        --checker) shift ; checker_args "$1" ;;

        *) break ;;
    esac
    shift
done

action=$1
lock=$2 ; dest=$2
shift 2

[ -z "$CHECKER" ] && CHECKER=("${ID_HELPER[@]}")
[ -n "$CHECK_FAIL" ] && checker_args "${CHECK_FAIL[@]}" --on-check-fail "$lock"
checker_args is_stale
LOCKER=("$MYDIR/grace_lock.sh" "${CHECKER[@]}" "${LOCKER_ARGS[@]}")

case "$action" in
    owner) "${LOCKER[@]}" "$action" "$lock" ;;

    owner_pid) pid "$("${LOCKER[@]}" "owner" "$lock")" ;;
    owner_hostid) hostid "$("${LOCKER[@]}" "owner" "$lock")" ;;

    lock|unlock|lock_check|fast_lock|is_mine)
        id=$1 ; shift
        uid=$(uid "$id") || error "obtaining UID for ID($id)" "$ERR_MALFORMED_UID"
        case "$action" in
            lock|unlock)
                [ -n "$1" ] && GRACE_SECONDS=$1
                LOCKER+=(--grace-seconds "$GRACE_SECONDS")
                "${LOCKER[@]}" "$action" "$lock" "$uid"
            ;;

            lock_check|fast_lock|is_mine)
                "${LOCKER[@]}" "$action" "$lock" "$uid" "$@"
            ;;
        esac
    ;;

    is_host_compatible) compatible "$dest" ;;

    *) usage "unknown action ($action)" ;;
esac
