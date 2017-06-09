#!/usr/bin/env bash
#
# Copyright (c) 2013, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause
#
# Design:
#
# This lock can provide these 2 primary conditions:
#
# 1) Provide an atomic lock which can only succeed for one locker until unlocked
# 2) Provide an unlock which honors condition #1
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
# Lock Directory Layout:
#
#  <lock_path>/                         # top level dir, in place of lock file
#  <lock_path>/markers/                 # holds potential future locks
#  <lock_path>/markers/<id>/owner/<id>  # potential future lock
#  <lock_path>/owner/<id>               # represents the locked state
#

q() { "$@" 2>/dev/null ; } # execute a cmd and quiet the stderr
d() { [ "$DEBUG" = "DEBUG" ] && { echo "$(date) " ; } } # > date(debug) | nothing
debug() { [ "$DEBUG" = "DEBUG" ] && echo "$(d)$@" >&2 ; }
info() { debug "$@" ; [ "$DEBUG" = "INFO" ] && echo "$(d)$@" >&2 ; }
error() { echo "$(d)$1" >&2 ; exit $2 ; }

# paths... > basenames... (one line each)
basenames() { local p ; for p in "$@" ; do basename "$p" ; done ; }

# ---------- markers are potential locks, not yet owners ----------

delete_markdirs() { # id
    local id=$1
    q rmdir "$BASE/markers/$id/owner" "$BASE/markers/$id" "$BASE/markers"
}

delete_marker() { # id
    local id=$1
    q rm "$BASE/markers/$id/owner/$id"
    delete_markdirs "$id"
}

# > markerids_in_use
marker_ids() { ( shopt -s nullglob ; basenames "$BASE/markers"/* ) }

clean_markers() {
    local mids=($(marker_ids))
    [ -z "$mids" ] && return
    sleep 2
    # deleting marker dirs without a marker can cause really
    # slow creates to fail (oh well, they will have to try
    # again, locking is a privellege not a right).  This helps
    # remove stale dirs without a marker.
    local mid
    for mid in "${mids[@]}" ; do
        delete_markdirs "$mid"
    done
    q rmdir "$BASE"
}

create_marker() { # id > [markdir] (if success)
    local id=$1
    local markdir=$BASE/markers/$id/owner
    local marker=$BASE/markers/$id/owner/$id

    q mkdir -p "$markdir"
    q touch "$marker"
    [ -f "$marker" ] && echo "$markdir"
}

# ---------- API ------------

ids_in_use() { (owner ; marker_ids) | sort --unique ; } # > ids...

clean_stale_ids() { # [ids]...
    local id
    for id in "$@" ; do
        debug "cleaning stale id $id"
        delete_marker "$id"
        q unlock "$id"
    done
    clean_markers
}

lock() { # id # => 10 critical error (stop spinning!)
    local id=$1  rtn
    [ -n "$id" ] || usage "action '$ACTION' needs <ID>"

    [ -f "$BASE/owner/$id" ] && error "$BASE already locked by $id" 20

    local markdir=$(create_marker "$id")
    [ -n "$markdir" ] || return 2

    debug "attempting to lock with $markdir"
    # In rare cases, mv prompts, so us -f to prevent blocking by prompt
    q mv -f "$markdir" "$BASE" ; rtn=$?
    if [ $rtn = 0 ] ; then
        info "$BASE locked by $id"
    else
        rtn=1
        info "$BASE failed to lock for $id"
    fi

    delete_marker "$id"
    return $rtn
}

unlock() { # id
    local id=$1
    [ -n "$id" ] || usage "action '$ACTION' needs <ID>"

    rm "$BASE/owner/$id" # unlock
    q rmdir "$BASE/owner" "$BASE"

    info "$BASE unlocked by $id"
    clean_markers &
}

owner() { ( shopt -s nullglob ; basenames "$BASE"/owner/* ) ; } # > id

is_mine() { # id
    [ -n "$1" ] || usage "action '$ACTION' needs <ID>"
    [ "$1" = "$(owner)" ]
}

# ----------

usage() { # error_message
    local prog=$(basename "$0")
    cat >&2 <<EOF

    usage: $prog lock <lock_path> <id>
           $prog unlock <lock_path> <id>

           $prog owner <lock_path> > id
           $prog is_mine <lock_path> id
           $prog ids_in_use <lock_path> > ids

           $prog clean_stale_ids <lock_path> [ids]...

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

ACTION=$1 ; [ -n "$ACTION" ] || usage "unspecified <ACTION>"
BASE=$2 ; [ -n "$BASE" ] || usage "action '$ACTION' needs <LOCK_PATH>"
shift 2

"$ACTION" "$@"
