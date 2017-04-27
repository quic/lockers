#!/usr/bin/env bash
#
# Copyright (c) 2013, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

# A grace period is given to each id before checking it for staleness, this
# is tracked with an 'in_use' dir in the in_use subdir.  The timestamp on the
# dir indicates the last activity for the id.

q() { "$@" 2>/dev/null ; } # execute a cmd and quiet the stderr
q-shell-init() { # execute cmd, quiet potential bash startup error message
  "$@" 2>&1 | grep -v 'shell-init: error retrieving current directory' >&2
}
# Outputs a date when debug is on
debug_date() { [ "$DEBUG" = "DEBUG" ] && { echo "$(date) " ; } }
debug() { [ "$DEBUG" = "DEBUG" ] && echo "$(debug_date)$@" >&2 ; }
info() { debug "$@" ; [ "$DEBUG" = "INFO" ] && echo "$(debug_date)$@" >&2 ; }
error() { echo "$(debug_date)$1" >&2 ; exit $2 ; }

args() { # action needed optional [args]...
    local func=$1 needed=$2 optional=$3 n s min=0 supplied=0 ; shift 3
    for n in $needed ; do min=$((min+1)) ; done
    for s in "$@" ; do supplied=$((supplied +1)) ; done

    [ $supplied -ge $min ] && return
    usage "'$func' takes <$needed> [$optional], given ($*)"
}

in_args() { # arg [args]...
    local in=$1 arg ; shift
    for arg in "$@" ; do
        [ "$in" = "$arg" ] && return
    done
    return 1
}

# See if the id is stale
is_stale() {  # id
    [ -z "$1" ] && return 0
    "${STALE_CHECKER[@]}" "$1"
}

# Create a find option to find files newer than seconds ago
newer_seconds() { date -d "$1 seconds ago" ; } # seconds > newerdt date

refresh_find_stale() {
    if [ -z "$GRACE_SECONDS" ] ; then
        FIND_STALE=()
    else
        FIND_STALE=('!' -newermt "$(newer_seconds "$GRACE_SECONDS")")
    fi
}

is_check_needed() { # lock uid
    local lock=$1 uid=$2
    [ -z "$GRACE_SECONDS" ] && return 0

    refresh_find_stale
    [ -n "$(find "$lock/in_use/$uid" -type d "${FIND_STALE[@]}"))" ]
}

clean_if_stale() { # lock uid
    local lock=$1 uid=$2
    q touch -c "$lock/in_use/$uid" # delay subsequent checks
    # Consideration was given to adding a loop in the bg which touches
    # this file in case check is really long.  However that was
    # considered too risky.  If the bg process became errant (which
    # could easily happen), it would prevent the lock from ever
    # recovering if it became stale.
    if is_stale "$uid" ; then
        q rmdir "$lock/in_use/$uid" "$lock/in_use"
        "${FAST_LOCKER[@]}" clean_stale_ids "$lock" "$uid"
        info "cleaned stale id $uid"
    else
        debug "id not stale: $uid"
    fi
}

tracked_ids() { # lock > ids...
    local lock=$1 use
    shopt -s nullglob
    for use in "$lock"/in_use/* ; do
        basename "$use"
    done
}

ids_in_use() { # lock > ids...
    local lock=$1 uidb uida uidt

    local before=$("${FAST_LOCKER[@]}" ids_in_use "$lock")
    local tracked=$(tracked_ids "$lock")
    local after=$("${FAST_LOCKER[@]}" ids_in_use "$lock")
    debug "ids_in_use before: $before"
    debug "ids_in_use tracked: $tracked"
    debug "ids_in_use after: $after"

    # In tracked but not after? -> no longer in use
    for uidt in $tracked ; do
        in_args "$uidt" $after || q rmdir "$lock/in_use/$uidt"
    done
    q rmdir "$lock/in_use" "$lock"

    # Not in before and after? -> not yet or no longer in use
    for uidb in $before ; do
        if in_args "$uidb" $after ; then
            q mkdir -p "$lock/in_use/$uidb"
            echo "$uidb"
        fi
    done
}

ids_need_check() { # lock > potentially_stale_ids
    local lock=$1 use stale=()
    local ids=$(ids_in_use "$lock")
    debug "ids_in_use: $ids"

    refresh_find_stale
    for use in $(q find "$lock/in_use" -type d "${FIND_STALE[@]}") ; do
        [ "$use" = "$lock/in_use" ] && continue
        basename "$use"
    done
}

ponder_clean() { # lock skip_uid
    local lock=$1 skip=$2 uid cleaned=false

    local uids=$(ids_need_check "$lock")
    debug "ids_need_check: $uids"
    [ -z "$uids" -o "$skip" = "$uids" ] && return

    # Increase the chances that someone else checks instead of us by using
    # a random offset, the first one to get there will prevent subsequent
    # checks, until the next grace period.
    if [ -n "$GRACE_SECONDS" ] ; then
        local delay=$(($RANDOM % $GRACE_SECONDS / 2))
        debug "delay our staleness check by $delay"
        sleep $delay
    fi

    for uid in $uids ; do
        [ "$skip" = "$uid" ] && continue
        is_check_needed "$lock" "$uid" || continue
        clean_if_stale "$lock" "$uid"

        # leave things cleaner than when we started in a constrained fashion
        $cleaned && return
        cleaned=true
    done
}

# ---------- API ------------

lock_nocheck() { # lock id # => 10 critical error (stop spinning!)
    "${FAST_LOCKER[@]}" lock "$@"
}

lock() { # lock id [stale_seconds] # => 10 critical error (stop spinning!)
    args lock "lock id" "stale_seconds" "$@"
    local lock=$1 id=$2 secs=$3 rtn ; shift 2
    [ -n "$secs" ] && GRACE_SECONDS=$secs

    lock_nocheck "$lock" "$id" ; rtn=$?
    q rmdir "$lock/in_use/$id" "$lock"/in_use "$lock"
    q-shell-init ponder_clean "$lock" "$id"
    return $rtn
}

lock_check() { # lock id # => 10 critical error
    args lock_check "lock id" "" "$@"
    local lock=$1 id=$2  rtn

    lock_nocheck "$lock" "$id" ; rtn=$?
    if [ $rtn -ne 0 -a $rtn -lt 10 ] ; then
        local owner=$("${FAST_LOCKER[@]}" owner "$lock")
        clean_if_stale "$lock" "$owner"
        lock_nocheck "$lock" "$id" ; rtn=$?
    fi
    q rmdir "$lock/in_use/$id" "$lock"/in_use "$lock"
    q-shell-init ponder_clean "$lock" "$id"
    return $rtn
}

unlock() { # lock id [stale_seconds]
    args unlock "lock id" "[stale_seconds]" "$@"
    local lock=$1 id=$2 secs=$3 ; shift 2
    [ -n "$secs" ] && GRACE_SECONDS=$secs

    "${FAST_LOCKER[@]}" unlock "$lock" "$id"

    q rmdir "$lock/in_use/$id" "$lock"/in_use "$lock"
    q-shell-init ponder_clean "$lock"
}

owner() { # lock > id
    args owner "lock" "" "$@"
    "${FAST_LOCKER[@]}" owner "$@"
}

is_mine() { # lock id
    args is_mine "lock id" "" "$@"
    "${FAST_LOCKER[@]}" is_mine "$@"
}

usage() { # error_message
    local prog=$(basename "$0")
    cat >&2 <<EOF

    usage: $prog [gopts] <stale_checker> lock <lock_path> <id>
           $prog fast_lock <lock_path> <id>  # DEPRECATED: use lock_nocheck
           $prog lock_nocheck <lock_path> <id>
           $prog <stale_checker> lock_check <lock_path> <id>
           $prog [gopts] <stale_checker> unlock <lock_path> <id>

           $prog owner <lock_path> > id
           $prog is_mine <lock_path> id

    A filesystem based lock manager requiring a unique id representing
    the lock holder.  To properly recover from potential stale locks,
    the lock holder's stalness must be verifiable using the id, thus
    the stale checker:

    <stale_checker> can be <cmd [--checker-arg arg]...>

    <cmd [--checker-arg arg]...>

              Command to run to see if a lock owner (id) is stale.
              <id> will be the first argument to cmd after any specified
              args via --checker-arg.

    gopts (grace options):

    --grace-seconds <seconds>

    seconds   The amount of time a lock component needs to be untouched
              before even considering checking it for staleness.  To
              prevent multiple checkers, set this to longer then the
              worst case check time.  The longest stale recovery time is
              the sum of the worst case check time and twice this delay.

   This locker is meant to be used with expensive stale checks.  It
   therefore has a strategy aimed at reducing these checks.  Stale checks
   are performed by the checking process which gets there first after a
   grace period.  Additionally, each checker has a random delay after
   its grace period (bounded by the grace period), before checking.  The
   random delay drastically decreases the chance of redundant stale
   checks.

   Due to the sparse stale checks, it is OK to use the "lock" command for
   spinning checks.  However, the "lock" command is unlikely to succeed
   the first time when there is an actual stale lock.  If success is
   required in the presence of only a stale lock, use "lock_check".  Be
   aware of the associated stale check cost of using "lock_check", and
   don't use "lock_check" for spinning.

EOF
    [ $# -gt 0 ] && echo "Error - $@" >&2
    exit 10
}

mypath=$(readlink -e "$0")
mydir=$(dirname "$mypath")

FAST_LOCKER=("$mydir/fast_lock.sh")
STALE_CHECKER=()
while [ $# -gt 0 ] ; do
    case "$1" in
        -u|-h|--help) usage ;;
        -di|--info) DEBUG=INFO ; FAST_LOCKER+=("$1") ;;
        -d|--debug) DEBUG=DEBUG ; FAST_LOCKER+=("$1") ;;

        --grace-seconds) GRACE_SECONDS=$2 ; shift ;;

        -s|--checker-arg) STALE_CHECKER+=("$2") ; shift ;;

        lock_nocheck|fast_lock|owner|is_mine) STALE_CHECKER=(true) ; break ;;

        *)  [ -n "$STALE_CHECKER" ] && break
            STALE_CHECKER=("$1")
        ;;
    esac
    shift
done
[ -z "$STALE_CHECKER" ] && usage "you must specify a stale checker"

[ $# -lt 1 ] && usage "you must specify a stale checker and an action"
action=$1 ; shift
[ "$action" = "fast_lock" ] && action=lock_nocheck

"$action" "$@"
