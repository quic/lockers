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
error() { echo "$(d) ERROR - $1" >&2 ; exit $2 ; }

random_slots() { # max > 1..max(in some random order)
  [ $1 -eq 1 ] && { echo 1 ; return ; }
  local start=$(( (RANDOM % ($1 -1)) +1 ))
  seq $start $1
  [ $start -gt 1 ] && seq 1 $((start -1))
}

_acquire_slot() { # [--nocheck] slot [id] # => 10 critical error (stop spinning!)
    local fast='' ; [ "$1" = "--nocheck" ] && { fast='fast_'; shift ; }
    local slot=$1 id=($2)  locked

    "${LOCKER[@]}" "$fast"lock "$SEMAPHORE/$slot" "${id[@]}" ; locked=$?
    if [ $locked -eq 0 ] ; then
        info "$SEMAPHORE ${fast}acquired by $id"
    fi
    return $locked
}

_acquire() { # [--nocheck] max [id] # => 10 critical error (stop spinning!)
    local nocheck=() ; [ "$1" = "--nocheck" ] && { nocheck=("$1"); shift ; }
    local max=$1 id=($2)  slot locked

    for slot in $(random_slots "$max") ; do
         _acquire_slot "${nocheck[@]}" "$slot" "${id[@]}" ; locked=$?
         [ $locked -eq 0 ] || [ $locked -gt 9 ] && return $locked
    done
    info "$SEMAPHORE failed to be acquired by $id (max $max)"
    return 1
}

# ----------

fast_acquire() { # max [id] # => 10 critical error (stop spinning!)
    args fast_acquire "max" "id" "$@"
    _acquire --nocheck "$@"
}

acquire() { # max [id] # => 10 critical error (stop spinning!)
    args acquire "max" "id" "$@"
    _acquire --nocheck "$@" ; local locked=$?
    [ $locked -eq 0  -o  $locked -gt 9 ] && return $locked
    _acquire "$@"
}

release() { # [id]
    local id=($1)  lock
    for lock in "$SEMAPHORE"/* ; do
         [ "$lock" = "$SEMAPHORE"/'*' ] && continue
         "${LOCKER[@]}" is_mine "$lock" "${id[@]}" || continue
         "${LOCKER[@]}" unlock "$lock" "${id[@]}"
         rmdir "$SEMAPHORE" 2> /dev/null
         info "$SEMAPHORE released by $id"
         return 0
    done
    error "$SEMAPHORE not held by $id" 19
}

owners() { # > uids...
    local lock
    for lock in "$SEMAPHORE"/* ; do
         [ "$lock" = "$SEMAPHORE"/'*' ] && continue
         "${LOCKER[@]}" owner "$lock"
    done
}

owner() { # slot > uid
    args owner "slot" "" "$@"
    "${LOCKER[@]}" owner "$SEMAPHORE/$1"
}

slot() { # [id] > slot
    local id=($1) lock
    for lock in "$SEMAPHORE"/* ; do
         [ "$lock" = "$SEMAPHORE"/'*' ] && continue
         "${LOCKER[@]}" is_mine "$lock" "${id[@]}" || continue
         echo "$(basename "$lock")"
         return
    done
}

# ----------

usage() { # error_message
    local prog=$(basename "$0")
    cat >&2 <<EOF

    usage: $prog <locker> acquire <semaphore_path> max [id]
           $prog <locker> fast_acquire <semaphore_path> max [id]
           $prog <locker> release <semaphore_path> [id]

           $prog <locker> owners <semaphore_path> > uids
           $prog <locker> owner <semaphore_path> <slot> > uid
           $prog <locker> slot <semaphore_path> id > slot

    A filesystem locker based semaphore manager.

    <locker> can consist of:
             <cmd [--locker-arg|-a arg]...>
               or
             -l|--local for safe local host only locking.

             The <locker> command must understand the following lock commands:

                lock <lock_path> [id] [seconds]
                unlock <lock_path> [id] [seconds]
                fast_lock <lock_path> [id]
                owner <lock_path> > uid

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

        -a|--locker-arg) LOCKER=("${LOCKER[@]}" "$2") ; shift ;;

        *)  if [ -z "$LOCKER" ] ; then
                LOCKER=("$1")
            elif [ -z "$ACTION" ] ; then
                ACTION=$1
            elif [ -z "$SEMAPHORE" ] ; then
                SEMAPHORE=$1
            else
                break
            fi
        ;;
    esac
    shift
done
[ "$DEBUG" = "DEBUG" ] && LOCKER=("${LOCKER[@]}" --debug)

[ -z "$ACTION" ] && usage "ACTION required"
[ -z "$SEMAPHORE" ] && usage "SEMAPHORE required for $ACTION"

"$ACTION" "$@"
