#!/usr/bin/env bash
#
# Copyright (c) 2013, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

uid() { "${ID_HELPER[@]}" uid "$1" ; } # pid|uid > uid
pid() { "${ID_HELPER[@]}" pid "$1" ; } # pid|uid > pid

usage() { # error_message
    local prog=$(basename "$0")
    cat <<EOF

    usage: $prog -u|-h|--help
           $prog lock <lock_path> <pid>
           $prog lock_nocheck <lock_path> <pid>
           $prog fast_lock <lock_path> <pid>  (DEPRECATED, use lock_nocheck)
           $prog unlock <lock_path> <pid|uid>

           $prog owner <lock_path> > pid      (DEPRECATED, see warning)
           $prog owner_pid <lock_path> > pid
           $prog owner_pid_nocheck <lock_path> > pid
           $prog is_mine <lock_path> <pid|uid>

    options: -di|--info | -d|--debug

    A filesystem based lock manager requiring a pid representing
    the lock holder.

    WARNING: use of owner is going to change, it will soon return
             uid instead of pid.  If you need a pid (warning:  pids
             are non-unique over time) use owner_pid instead.

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

LOCKER=("$mydir"/check_lock.sh $DEBUG)
CLOCKER=("${LOCKER[@]}" "${STALE_CHECKER[@]}")

case "$action" in
    owner|owner_pid) pid "$("${CLOCKER[@]}" "owner" "$lock")" ;;
    owner_pid_nocheck) pid "$("${LOCKER[@]}" "owner_nocheck" "$lock")" ;;

    lock|unlock) "${CLOCKER[@]}" "$action" "$lock" "$(uid "$1")" ;;

    lock_nocheck|fast_lock|is_mine)
        [ "$action" = "fast_lock" ] && action=lock_nocheck
        "${LOCKER[@]}" "$action" "$lock" "$(uid "$1")"
    ;;

    *) usage "unknown action ($action)" ;;
esac
