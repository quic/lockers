#!/usr/bin/env bash
#
# Copyright (c) 2013, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

#
# Design:
#
# This lock can provide these 2 primary conditions:
#
# 1) Provide an atomic lock which can only succeed for one locker
# 2) Provide an unlock which allows #1 to succeed
#
# With some help, it can also provide this third condition
#
# 3) Provide a way to safely recover from (delete) stale locks
#    without accidentally deleting a new unstale lock
#
#
# This lock is held by a subdirectory named 'owner' with an 'id' file
# in it.
#
# To get:
#
#  #1: simply create such a dir/file combo elsewhere and atomically
#      move the dir into place (will only succeed if such a dir/file
#      combo does not already exist).
#
#  #2: delete the id file (then cleanup dir, but not essential)
#
#  #3: if the owner is verified to be stale externally, the lock can be
#      released by impersonating the owner and unlocking it, this will simply
#      delete the id file.  As long as the id file represents a unique locker
#      (part of the contract), it is safe to delete by anyone at anytime once
#      the locker is no longer running.
#

q() { "$@" 2>/dev/null ; } # execute a cmd and quiet the stderr
d() { [ "$DEBUG" = "DEBUG" ] && { echo "$(date) " ; } } # > date(debug) | nothing
debug() { [ "$DEBUG" = "DEBUG" ] && echo "$(d)$@" >&2 ; }
info() { debug "$@" ; [ "$DEBUG" = "INFO" ] && echo "$(d)$@" >&2 ; }
error() { echo "$(d)$1" >&2 ; exit $2 ; }

args() { # action needed optional [args]...
    local func=$1 needed=$2 optional=$3 n s min=0 supplied=0 ; shift 3
    for n in $needed ; do  min=$((min+1)) ;  done
    for s in "$@" ; do supplied=$((supplied +1)) ; done

    [ $supplied -ge $min ] && return
    usage "'$func' takes <$needed> [$optional], given ($*)"
}

# ---------- markers are potential locks, not yet owners ----------

delete_markdirs() { # lock uid
    local lock=$1 uid=$2
    q rmdir "$lock/markers/$uid/owner" "$lock/markers/$uid" "$lock/markers"
}

delete_marker() { # lock uid
    local lock=$1 uid=$2
    q rm "$lock/markers/$uid/owner/$uid"
    delete_markdirs "$lock" "$uid"
}

marker_ids() { # lock > markerids_in_use
    local lock=$1 m
    for m in "$lock/markers"/* ; do
        [ "$m" = "$lock/markers"/'*' ] && continue
        basename "$m"
    done
}

clean_markers() { # lock
    local lock=$1  m ; shift
    for m in "$lock/markers"/* ; do
        [ "$m" = "$lock/markers"/'*' ] && continue
        if [ -d "$m" ] ; then
            sleep 2
            # deleting marker dirs without a marker can cause really
            # slow creates to fail (oh well, they will have to try
            # again, locking is a privellege not a right).  This helps
            # remove stale dirs without a marker.
            delete_markdirs "$lock" "$(basename "$m")"
        fi
    done
    q rmdir "$lock"
}

create_marker() { # lock uid > [markdir] (if success)
    local lock=$1 uid=$2
    local markdir="$lock/markers/$uid/owner"
    local marker="$lock/markers/$uid/owner/$uid"

    q mkdir -p "$markdir"
    q touch "$marker"
    [ -f "$marker" ] && echo "$markdir"
}

# ---------- API ------------

ids_in_use() { # lock > ids...
    args ids_in_use "lock" "" "$@"
    local lock=$1
    owner "$lock"
    marker_ids "$lock"
}

stale_ids() { # lock [ids]...
    args stale_ids "lock" "[ids]" "$@"
    local lock=$1 uid ; shift
    for uid in "$@" ; do
        debug "cleaning stale id $uid"
        delete_marker "$lock" "$uid"
        q unlock "$lock" "$uid"
    done
    clean_markers "$lock"
}

lock() { # lock id # => 10 critical error (stop spinning!)
    args fast_lock "lock id" "" "$@"
    [ $# -lt 2 ] && usage "fast_lock too few args ($@)"
    local lock=$1 uid=$2  rtn

    [ -f "$lock/owner/$uid" ] && error "$lock already locked by $uid" 20

    local markdir=$(create_marker "$lock" "$uid")
    [ -n "$markdir" ] || return 2

    debug "attempting to lock with $markdir"
    # In rare cases, mv prompts, so us -f to prevent blocking by prompt
    q mv -f "$markdir" "$lock" ; rtn=$?
    if [ $rtn = 0 ] ; then
        info "$lock locked by $2"
    else
        rtn=1
        info "$lock failed to lock for $2"
    fi

    delete_marker "$lock" "$uid"
    return $rtn
}

unlock() { # lock id
    args unlock "lock id" "" "$@"
    local lock=$1 uid=$2

    rm "$lock/owner/$uid" # unlock
    q rmdir "$lock/owner" "$lock"

    info "$lock unlocked by $uid"
    clean_markers "$lock" &
}

owner() { # lock > id
    args owner "lock" "" "$@"
    for owner in "$1"/owner/* ; do
         [ "$owner" = "$1"'/owner/*' ] && continue
         basename "$owner"
    done
}

is_mine() { # lock id
    args is_mine "lock id" "" "$@"
    [ "$2" = "$(owner "$1")" ]
}

# ----------

usage() { # error_message
    local prog=$(basename "$0")
    cat <<EOF

    usage: $prog lock <lock_path> <id>
           $prog unlock <lock_path> <id>

           $prog owner <lock_path> > id
           $prog is_mine <lock_path> id

           $prog ids_in_use <lock_path> > ids
           $prog stale_ids <lock_path> [ids]...

    A filesystem based lock manager requiring a unique id representing
    the lock holder.  This lock manager is mainly meant as a building
    block for other lock managers since it cannot recover from stale
    locks on its own.  To recover stale locks an external caller should
    call 'ids_in_use', then check the run status of the ids and then
    clean up the ids of processes which are no longer running by calling
    'stale_ids' with those ids.

EOF
    [ $# -gt 0 ] && echo "Error - $@" >&2
    exit 10
}

while [ $# -gt 0 ] ; do
    case "$1" in
        -di|--info) DEBUG=INFO ;;
        -d|--debug) DEBUG=DEBUG ;;

        *)  break ;;
    esac
    shift
done

"$@"
