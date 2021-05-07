#!/usr/bin/env bash
#
# Copyright (c) 2013, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

q() { "$@" 2>/dev/null ; } # execute a cmd and quiet the stderr

args() { # action needed optional [args]...
    local func=$1 needed=$2 optional=$3 n s min=0 supplied=0 ; shift 3
    for n in $needed ; do  min=$((min+1)) ;  done
    for s in "$@" ; do supplied=$((supplied +1)) ; done

    [ $supplied -ge $min ] && return
    usage "'$func' takes <$needed> [$optional], given ($*)"
}

spin_constant() { # lock id sec [stale_seconds]
    args spin_constant "lock id sec" "stale_seconds" "$@"
    local lock=$1 id=$2 sec=$3 locked=0 ; shift 3

    # 10 or above is critical, stop spinning.
    "${LOCKER[@]}" lock "$lock" "$id" "$@" ; locked=$?
    while [ $locked -gt 0  -a  $locked -lt 10 ] ; do
        sleep "$sec"
        "${LOCKER[@]}" lock "$lock" "$id" "$@" ; locked=$?
    done
    return $locked
}

# ----------

scrub_git_ci() {
   grep -v '1 files* changed, 1 insertions*(+), 1 deletions*(-)' |\
   grep -v '\[master [a-f0-9]*\]'
}

test_git_task() { # dir id
    args test_git_task "dir id" "" "$@"
    local git=$1 id=$2 i=0 dir

    if [ ! -d "$git" ] ; then
        git init "$git"
        cd "$git" || exit
    else
        cd "$git" || exit
        i=$(< counter)
    fi

    i=$((i+1))
    echo $i > counter
    git add counter                  >> ../$id.out
    git commit -m $1 | scrub_git_ci  >> ../$id.out
    [ $((i % 300)) = 0 ] && git gc   >> ../$id.gc 2>&1

    return 0
}

test_one() { # dir id [lock_unlock_options]
    args test_one "dir id" "lock_unlock_options" "$@"
    local dir=$1 id=$2  i=0 git=git

    q mkdir -p -- "$dir"
    cd "$dir" || exit

    while true ; do
        spin_constant "lock" "$id" 0 $3 || exit
        (test_git_task "git" "$id")     || exit # () is in case of cd
        "${LOCKER[@]}" unlock "lock" "$id" $3
    done

    # If the lock is failing to lock, you should see something like:
    #
    ## If no other git process is currently running, this probably means a
    ## git process crashed in this repository earlier. Make sure no other git
    ## process is running and remove the file manually to continue.
    ## fatal: Unable to create '<dir>/git/.git/index.lock': File exists.
}

# This is to test maximum speed, it will not detect locking issues
test_one_fast() { # dir id [lock_unlock_options]
    args test_one_fast "dir id" "lock_unlock_options" "$@"
    local lock=$1 id=$2

    while true ; do
        spin_constant "$lock" "$id" 0 $3
        "${LOCKER[@]}" unlock "$lock" "$id" $3
    done
}

usage() { # error_message
    local prog=$(basename "$0")
    cat <<EOF

    usage: $prog test_one <dir> <id> [lock_unlock_options]
           $prog test_one_fast <dir> <id> [lock_unlock_options]
           $prog test_git_task <dir> <id>

    Example:

          $prog -d test_one fast \$\$ > \$\$.out 2> \$\$.err

EOF
    [ $# -gt 0 ] && echo "Error - $@" >&2
    exit 10
}

mypath=$(readlink -e "$0")
mydir=$(dirname "$mypath")
locker_dir=$(dirname "$(dirname "$mydir")")

LOCKER=()
LOCKER_ARGS=()
while [ $# -gt 0 ] ; do
    case "$1" in
        -d*|--info|--debug) LOCKER_ARGS=("${LOCKER_ARGS[@]}" "$1") ;;
        -l)  shift ; LOCKER=("${LOCKER[@]}" "$1") ;;
        *) break ;;
    esac
    shift
done
[ -z "$LOCKER" ] && LOCKER=("$locker_dir/fast_lock.sh")
LOCKER=("${LOCKER[@]}" "${LOCKER_ARGS[@]}")

[ $# -eq 0 ] && usage

"$@"
