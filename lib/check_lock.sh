#!/usr/bin/env bash
#
# Copyright (c) 2013, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

q() { "$@" 2>/dev/null ; } # execute a cmd and quiet the stderr

# Outputs a date when debug is on
debug_date() { [ "$DEBUG" = "DEBUG" ] && { echo "$(date) " ; } }
debug() { [ "$DEBUG" = "DEBUG" ] && echo "$(debug_date)$@" >&2 ; }
info() { debug "$@" ; [ "$DEBUG" = "INFO" ] && echo "$(debug_date)$@" >&2 ; }

args() { # action needed optional [args]...
    local func=$1 needed=$2 optional=$3 n s min=0 supplied=0 ; shift 3
    for n in $needed ; do  min=$((min+1)) ;  done
    for s in "$@" ; do supplied=$((supplied +1)) ; done

    [ $supplied -ge $min ] && return
    usage "'$func' takes <$needed> [$optional], given ($*)"
}

is_stale() {  # id
    [ -z "$1" ] && return 0
    "${STALE_CHECKER[@]}" "$1"
}

clean_stale() { # lock
    local lock=$1 id stale=()
    for id in $("${FAST_LOCKER[@]}" ids_in_use "$lock") ; do
         [ -n "$id" ] || continue
         is_stale "$id" || continue
         stale+=$id
    done
    [ -n "${stale[*]}" ] && "${FAST_LOCKER[@]}" clean_stale_ids "$lock" "${stale[@]}"
}

clean_stale_owner() { # lock
    local lock=$1
    local owner=$("${FAST_LOCKER[@]}" owner "$lock")
    [ -z "$owner" ] && return

    is_stale "$owner" || return

    info "recovery needed for $owner"
    "${FAST_LOCKER[@]}" clean_stale_ids "$lock" "$owner"
}

# ---------- API ------------

lock_nocheck() { # lock id # => 10 critical error (stop spinning!)
    args lock "lock id" "" "$@"
    local lock=$1 id=$2
    "${FAST_LOCKER[@]}" lock "$lock" "$id"
}

lock() { # lock id # => 10 critical error (stop spinning!)
    args lock "lock id" "" "$@"
    local lock=$1 id=$2  rtn

    clean_stale_owner "$lock"
    lock_nocheck "$lock" "$id" ; rtn=$?
    return $rtn
}

unlock() { # lock id
    args unlock "lock id" "" "$@"
    local lock=$1 id=$2

    "${FAST_LOCKER[@]}" unlock "$lock" "$id"

    clean_stale "$lock" &
}

owner_nocheck() { # lock > id
    args owner "lock" "" "$@"
    "${FAST_LOCKER[@]}" owner "$@"
}

owner() { # lock > id
    args owner "lock" "" "$@"
    clean_stale_owner "$1"
    owner_nocheck "$@"
}

is_mine() { # lock id
    args is_mine "lock id" "" "$@"
    local lock=$1 id=$2
    [ -z "$id" ] && return 1
    "${FAST_LOCKER[@]}" is_mine "$lock" "$id"
}

usage() { # error_message
    local prog=$(basename "$0")
    cat >&2 <<EOF

    usage: $prog -u|-h|--help
           $prog lock_nocheck <lock_path> <id>
           $prog <stale_checker> lock <lock_path> <id>
           $prog <stale_checker> unlock <lock_path> <id>

           $prog owner_nocheck <lock_path> > id
           $prog <stale_checker> owner <lock_path> > id
           $prog is_mine <lock_path> id

    options: -di|--info | -d|--debug

    A filesystem based lock manager requiring a unique id representing
    the lock holder.  To properly recover from potential stale locks,
    the lock holder's staleness must be verifiable using the id, thus
    the stale checker:

    <stale_checker> can be <cmd [-s args]...>

    <cmd [-s args]...>

              Command to run to see if a lock owner (id) is stale.
              <id> will be the first argument to cmd after any specified
              args via -s.

   This locker is meant to be used with inexpensive stale checks since they
   will occur on every lock attempt.  For expensive checks, consider using
   the grace_lock instead.

EOF
    [ $# -gt 0 ] && echo "Error - $@" >&2
    exit 10
}

mypath=$(readlink -e "$0")
mydir=$(dirname "$mypath")

ID_HELPER=("$mydir/local_id.sh")
FAST_LOCKER=("$mydir/fast_lock.sh")
STALE_CHECKER=()
while [ $# -gt 0 ] ; do
    case "$1" in
        -u|-h|--help) usage ;;
        -di|--info) DEBUG=INFO ;;
        -d|--debug) DEBUG=DEBUG ; FAST_LOCKER=("$mydir/fast_lock.sh" --debug) ;;

        -s) STALE_CHECKER+=("$2") ; shift ;;

        lock_nocheck|owner_nocheck|is_mine) STALE_CHECKER=(true) ; break ;;

        *)  [ -n "$STALE_CHECKER" ] && break
            STALE_CHECKER=("$1")
        ;;
    esac
    shift
done

[ -z "$STALE_CHECKER" ] && usage "you must specify a stale checker"

[ $# -lt 1 ] && usage "you must specify a stale checker and an action"

"$@"
