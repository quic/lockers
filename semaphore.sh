#!/usr/bin/env bash
#
# Copyright (c) 2013, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

#
# Design:
#
# This semaphore is fairly simple, it allocates "slots" numbered from
# 1 to max and uses a locker to grab a lock for any numbered slot it
# can.  Holding a slot lock means acquiring the semaphore, since the
# slots are limited to max, at most max users will acquire the semaphore
# at once.  Release a lock and a slot frees up for another user to grab.
#

args() { # action needed optional [args]...
    local func=$1 needed=$2 optional=$3 n s min=0 supplied=0 ; shift 3
    for n in $needed ; do  min=$((min+1)) ;  done
    for s in "$@" ; do supplied=$((supplied +1)) ; done

    [ $supplied -ge $min ] && return
    usage "'$func' takes <$needed> [$optional], given ($*)"
}

q() { "$@" 2>/dev/null ; } # execute a cmd and quiet the stderr
d() { [ "$DEBUG" = "DEBUG" ] && { echo "$(date) " ; } } # > date(debug) | nothing
debug() { [ "$DEBUG" = "DEBUG" ] && echo "$(d)$@" >&2 ; }
info() { debug "$@" ; [ "$DEBUG" = "INFO" ] && echo "$(d)$@" >&2 ; }
error() { echo "$(d)$1" >&2 ; exit $2 ; }

random_slots() { # max > 1..max(in some random order)
  local start=$(( (RANDOM % ($1 -1)) +1 ))
  seq $start $1
  [ $start -gt 1 ] && seq 1 $((start -1))
}

# ----------

fast_acquire() { # semaphore max [id] # => 10 critical error (stop spinning!)
    args fast_acquire "semaphore max" "id" "$@"
    local sem=$1 max=$2 id=($3)  slot locked

    for slot in $(random_slots $max) ; do
         "${LOCKER[@]}" fast_lock "$sem/$slot" "${id[@]}" ; locked=$?
         if [ $locked -eq 0 ] ; then
             info "$sem fast_acquired by $id (max $max)"
             return 0
         fi
         [ $locked -gt 9 ] && return $locked
    done
    info "$sem failed to be fast_acquired by $id (max $max)"
    return 1
}

acquire() { # semaphore max [id] # => 10 critical error (stop spinning!)
    args acquire "semaphore max" "id" "$@"
    local sem=$1 max=$2 id=($3)  slot locked

    fast_acquire "$@" ; locked=$?
    [ $locked -eq 0  -o  $locked -gt 9 ] && return $locked
    for slot in $(random_slots $max) ; do
         "${LOCKER[@]}"  lock "$sem/$slot" "${id[@]}" ; locked=$?
         if [ $locked -eq 0 ] ; then
             info "$sem acquired by $id (max $max)"
             return 0
         fi
         [ $locked -gt 9 ] && return $locked
    done
    info "$sem failed to be acquired by $id (max $max)"
    return 2
}

release() { # semaphore [id]
    args release "semaphore" "id" "$@"
    local sem=$1 id=($2)  lock

    for lock in "$sem"/* ; do
         [ "$lock" = "$sem"/'*' ] && continue
         "${LOCKER[@]}" is_mine "$lock" "${id[@]}" || continue
         "${LOCKER[@]}" unlock "$lock" "${id[@]}" || continue
         rmdir "$sem" 2> /dev/null
         info "$sem released by $id"
         return 0
    done
    error "$sem not held by $id" 19
}

owners() { # semaphore > ids...
    args owners "semaphore" "" "$@"
    local sem=$1 lock

    for lock in "$sem"/* ; do
         [ "$lock" = "$sem"/'*' ] && continue
         "${LOCKER[@]}"  owner "$lock"
    done
}

slot() { # semaphore [id] > slot
    args slot "semaphore" "id" "$@"
    local sem=$1 id=($2) lock

    for lock in "$sem"/* ; do
         [ "$lock" = "$sem"/'*' ] && continue
         "${LOCKER[@]}" is_mine "$lock" "${id[@]}" || continue
         echo "$(basename "$lock")"
         return
    done
}

# ----------

usage() { # error_message
    local prog=$(basename "$0")
    cat <<EOF

    usage: $prog <locker> acquire <semaphore_path> max [id]
           $prog <locker> fast_acquire <semaphore_path> max [id]
           $prog <locker> release <semaphore_path> [id]

           $prog <locker> owners <semaphore_path> > ids
           $prog <locker> slot <semaphore_path> id > slot

    A filesystem locker based semaphore manager.

    <locker> can consist of <cmd [-a arg]...> or -l|--local for safe local
             host only locking.

             The <locker> command must understand the following lock commands:

                lock <lock_path> [id] [seconds]
                unlock <lock_path> [id] [seconds]
                fast_lock <lock_path> [id]
                owner <lock_path> > id

    <semaphore_path> filesystem path which all semaphore users have write
                     access to.

    <max>  The maximum semaphore count

EOF
    [ $# -gt 0 ] && echo "Error - $@" >&2
    exit 10
}


mypath=$(readlink -e "$0")
mydir=$(dirname "$mypath")

LOCKER=()
LOCKER_TESTER=()
while [ $# -gt 0 ] ; do
    case "$1" in
        -u|-h|--help) usage ;;

        -di|--info) DEBUG=INFO ; TEST_DEBUG=$1 ;;
        -d|--debug) DEBUG=DEBUG ; TEST_DEBUG=$1 ;;

        -l|--local) LOCKER=("$mydir"/lock_local.sh)
                    LOCKER_TESTER=("$mydir"/test/lock_local.sh) ;;

        -a) LOCKER=("${LOCKER[@]}" "$2") ; shift ;;

        *)  [ -n "$LOCKER" ] && break
            LOCKER=("$1") ;;
    esac
    shift
done
[ "$DEBUG" = "DEBUG" ] && LOCKER=("${LOCKER[@]}" --debug)

"$@"
