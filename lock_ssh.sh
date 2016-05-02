#!/usr/bin/env bash
#
# Copyright (c) 2013, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

uid() { "${ID_HELPER[@]}" uid "$1" ; } # pid|uid > uid
pid() { "${ID_HELPER[@]}" pid "$1" ; } # pid|uid > pid
host() { "${ID_HELPER[@]}" host "$1" ; } # uid > host
compatible() { "${ID_HELPER[@]}" is_host_compatible "$1" ; } # host

checker_args() { # args...
    while [ $# -gt 0 ] ; do
        CHECKER+=(--checker-arg "$1")
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
           $prog [opts] owner_host <lock_path> > host
           $prog [opts] is_mine <lock_path> <pid|uid>

           $prog is_host_compatible host

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

mypath=$(readlink -e "$0")
mydir=$(dirname "$mypath")

ID_HELPER=("$mydir/ssh_id.sh")
CHECKER=("$mydir/ssh_id.sh")
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

        *) break ;;
    esac
    shift
done

action=$1
lock=$2 ; host=$2
shift 2

if [ -n "$CHECK_FAIL" ] ; then
    checker_args "${CHECK_FAIL[@]}" --on-check-fail "$lock"
fi
checker_args is_stale
LOCKER=("$mydir/grace_lock.sh" "${CHECKER[@]}" "${LOCKER_ARGS[@]}")

case "$action" in
    owner) "${LOCKER[@]}" "$action" "$lock" ;;

    owner_pid) pid "$("${LOCKER[@]}" "owner" "$lock")" ;;
    owner_host) host "$("${LOCKER[@]}" "owner" "$lock")" ;;

    lock|unlock)
        id=$1 ; shift;
        [ -n "$1" ] && GRACE_SECONDS=$1
        LOCKER+=(--grace-seconds "$GRACE_SECONDS")
        "${LOCKER[@]}" "$action" "$lock" "$(uid "$id")"
    ;;

    lock_check|fast_lock|is_mine)
        id=$1 ; shift
        "${LOCKER[@]}" "$action" "$lock" "$(uid "$id")" "$@"
    ;;

    is_host_compatible) compatible "$host" ;;

    *) usage "unknown action ($action)" ;;
esac
