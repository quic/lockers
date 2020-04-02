#!/usr/bin/env bash
#
# Copyright (c) 2013, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

ERR_MALFORMED_UID=20

d() { [ "$DEBUG" = "DEBUG" ] && { echo "$(date) " ; } } # > date(debug) | nothing
error() { echo "$(d) ERROR - $1" >&2 ; exit $2 ; }

uid() { "${ID_HELPER[@]}" uid "$1" ; } # pid|uid > uid
pid() { "${ID_HELPER[@]}" pid "$1" ; } # pid|uid > pid

usage() { # error_message
    local prog=$(basename "$0")
    cat >&2 <<EOF

    usage: $prog -u|-h|--help
           $prog lock <lock_path> <pid>
           $prog lock_nocheck <lock_path> <pid>
           $prog fast_lock <lock_path> <pid>  (DEPRECATED, use lock_nocheck)
           $prog unlock <lock_path> <pid|uid>

           $prog owner <lock_path> > uid
           $prog owner_nocheck <lock_path> > uid
           $prog owner_pid <lock_path> > pid
           $prog owner_pid_nocheck <lock_path> > pid
           $prog is_mine <lock_path> <pid|uid>

    options: -di|--info | -d|--debug

    A filesystem based lock manager requiring a pid representing
    the lock holder.

EOF
    [ $# -gt 0 ] && echo "Error - $@" >&2
    exit 10
}

mypath=$(readlink -e "$0")
mydir=$(dirname "$mypath")

ID_HELPER=("$mydir/local_id.sh")
STALE_CHECKER=("$mydir/local_id.sh" -s is_stale)

while [ $# -gt 0 ] ; do
    case "$1" in
        -u|-h|--help) usage ;;
        -di|--info) DEBUG=INFO ;;
        -d|--debug) DEBUG=DEBUG ; STALE_CHECKER+=(-r --debug) ;;

        *) break ;;
    esac
    shift
done

action=$1
lock=$2
shift 2

[ "$action" = "fast_lock" ] && action=lock_nocheck

locker=("$mydir"/lib/check_lock.sh $DEBUG)
case "$action" in
    owner|owner_pid|lock|unlock)
        locker=("${locker[@]}" "${STALE_CHECKER[@]}")
    ;;
esac

case "$action" in
    owner|owner_nocheck) "${locker[@]}" "$action" "$lock" ;;
    owner_pid) pid "$("${locker[@]}" "owner" "$lock")" ;;
    owner_pid_nocheck) pid "$("${locker[@]}" "owner_nocheck" "$lock")" ;;

    lock|unlock|lock_nocheck|fast_lock|is_mine)
        id=$1 ; shift
        uid=$(uid "$id") || error "obtaining UID for ID($id)" "$ERR_MALFORMED_UID"
        "${locker[@]}" "$action" "$lock" "$uid"
    ;;

    *) usage "unknown action ($action)" ;;
esac
