#!/usr/bin/env bash
#
# Copyright (c) 2013, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

#
# Design:
#
# This lock uses a fast_lock and can do run checking to recover stale ids
# using local_id.sh
#

q() { "$@" 2>/dev/null ; } # execute a cmd and quiet the stderr
d() { [ "$DEBUG" = "DEBUG" ] && { echo "$(date) " ; } } # > date(debug) | nothing
debug() { [ "$DEBUG" = "DEBUG" ] && echo "$(d)$@" >&2 ; }
info() { debug "$@" ; [ "$DEBUG" = "INFO" ] && echo "$(d)$@" >&2 ; }

args() { # action needed optional [args]...
    local func=$1 needed=$2 optional=$3 n s min=0 supplied=0 ; shift 3
    for n in $needed ; do  min=$((min+1)) ;  done
    for s in "$@" ; do supplied=$((supplied +1)) ; done

    [ $supplied -ge $min ] && return
    usage "'$func' takes <$needed> [$optional], given ($*)"
}

is_running() {  # pid|uid
    [ -z "$1" ] && return 1
    [ -n "$(pid "$1")" ]
}

uid() { "${ID_HELPER[@]}" uid "$1" ; } # pid|uid > uid

pid() { # pid|uid > pid (or if helper, blank if uid not running)
    local pid=$("${ID_HELPER[@]}" pid "$1")
    local uid=$(uid "$pid")
    [ "$uid" = "$1" ] && echo "$pid"
}

clean_stale() { # lock
    local lock=$1 uid stale=''
    for uid in $("${FAST_LOCKER[@]}" ids_in_use "$lock") ; do
         [ -n "$uid" ] || continue
         is_running "$uid" && continue
         stale="$stale $uid"
    done
    [ -n "$stale" ] && "${FAST_LOCKER[@]}" stale_ids "$lock" $stale
}

clean_stale_owner() { # lock
    local lock=$1
    local owner=$("${FAST_LOCKER[@]}" owner "$lock")
    [ -z "$owner" ] && return

    local id=$(pid "$owner")
    [ -n "$id" ] && return

    info "recovery needed for $owner"
    "${FAST_LOCKER[@]}" stale_ids "$lock" "$owner"
}

# ---------- API ------------

fast_lock() { # lock pid # => 10 critical error (stop spinning!)
    local lock=$1 uid=$(uid "$2")
    "${FAST_LOCKER[@]}" lock "$lock" "$uid"
}

lock() { # lock pid # => 10 critical error (stop spinning!)
    args lock "lock pid" "" "$@"
    local lock=$1 pid=$2  rtn

    clean_stale_owner "$lock"
    fast_lock "$lock" "$pid" ; rtn=$?
    return $rtn
}

unlock() { # lock pid|uid
    args unlock "lock pid|uid" "" "$@"
    local lock=$1 uid=$(uid "$2")

    "${FAST_LOCKER[@]}" unlock "$lock" "$uid"

    clean_stale "$lock" &
}

owner() { # lock > pid
    args owner "lock" "" "$@"
    pid "$("${FAST_LOCKER[@]}" owner "$@")"
}

is_mine() { # lock pid|uid
    args is_mine "lock pid|uid" "" "$@"
    local lock=$1 uid=$(uid "$2")
    [ -z "$uid" ] && return 1
    "${FAST_LOCKER[@]}" is_mine "$lock" "$uid"
}

usage() { # error_message
    local prog=$(basename "$0")
    cat <<EOF

    usage: $prog lock <lock_path> <pid>
           $prog unlock <lock_path> <pid|uid>

           $prog fast_lock <lock_path> <pid>
           $prog owner <lock_path> > pid
           $prog is_mine <lock_path> <pid|uid>

    A filesystem based lock manager requiring a pid representing
    the lock holder.

    WARNING: use of owner is discouraged since it returns a
             potentially non unique pid

EOF
    [ $# -gt 0 ] && echo "Error - $@" >&2
    exit 10
}

mypath=$(readlink -e "$0")
mydir=$(dirname "$mypath")

ID_HELPER=("$mydir/local_id.sh")
FAST_LOCKER=("$mydir/fast_lock.sh")
while [ $# -gt 0 ] ; do
    case "$1" in
        -u|-h|--help) usage ;;
        -di|--info) DEBUG=INFO ;;
        -d|--debug) DEBUG=DEBUG ; FAST_LOCKER=("$mydir/fast_lock.sh" --debug) ;;

        *) break ;;
    esac
    shift
done

"$@"
