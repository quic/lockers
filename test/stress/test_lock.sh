# Copyright (c) 2013, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause
#
# A bash library of lock testing functions to be sourced by lock testers
#

source "$(dirname "$(readlink -e "${BASH_SOURCE[0]}")")"/../libdebug.sh

test_lock_scrub_git_ci() {
   grep -v '1 files* changed, 1 insertions*(+), 1 deletions*(-)' |\
   grep -v '\[master [a-f0-9]*\]'
}

test_lock_git_task() { # dir id
    args test_lock_git_task "dir id" "" "$@"
    local git=$1 id=$2 i=0 dir

    if [ ! -d "$git" ] ; then
        git init "$git"
        pushd "$git" > /dev/null || exit
    else
        pushd "$git" > /dev/null || exit
        i=$(< counter)
    fi

    i=$((i+1))
    echo $i > counter
    info "counter: $i"
    git add counter                            >> ../$id.out
    git commit -m $1 | test_lock_scrub_git_ci  >> ../$id.out
    [ $((i % 300)) = 0 ] && git gc             >> ../$id.gc 2>&1

    popd > /dev/null || exit
    return 0
}

# -----

test_lock_spin() { # lock [lock_args]
    args test_lock_spin "lock" "lock_args" "$@"
    local lock=$1 locked=0 ; shift 1

    # 10 or above is critical, stop spinning.
    "${LOCKER[@]}" lock "$lock" "$@" ; locked=$?
    while [ $locked -gt 0  -a  $locked -lt 10 ] ; do
        "${LOCKER[@]}" lock "$lock" "$@" ; locked=$?
    done
    return $locked
}

test_lock_one() { # dir id [lock_unlock_options]
    args test_lock_one "dir id" "lock_unlock_options" "$@"
    local dir=$1 id=$2  i=0 git=git

    q mkdir -p -- "$dir"
    cd "$dir" || exit

    while true ; do
        [ -f "stop" ] &&  { debug "stopping $id" ; exit ; }
        test_lock_spin "lock" "$id" $3       || error "test_lock_spin"
        "${LOCKER[@]}" is_mine "lock" "$id"  || error "not mine $id"
        test_lock_git_task "git" "$id"       || error "test_lock_git_task $id"
        "${LOCKER[@]}" unlock "lock" "$id" $3
    done

    # If the lock is failing to lock, you should see something like:
    #
    ## If no other git process is currently running, this probably means a
    ## git process crashed in this repository earlier. Make sure no other git
    ## process is running and remove the file manually to continue.
    ## fatal: Unable to create '<dir>/git/.git/index.lock': File exists.
}

test_lock_newpid() { # dir [lock_unlock_options]
   local dir=$1 ; shift
   test_lock_one "$dir" "$BASHPID" "$@"
}

test_lock_three() { # dir [--stop] [lock_unlock_options]
    args test_lock_three "dir" "--stop lock_unlock_options" "$@"
    [ "$2" == "--stop" ] && { touch "$1"/stop ; exit ; }

    local dir=$1 ; shift
    [ -d "$dir" ] &&  error "test dir $dir exists, please clean it up first"
    q mkdir -p -- "$dir"

    for i in $(seq 3) ; do
         test_lock_newpid "$dir" "$@" > "$dir/$i.out" 2> "$dir/$i.err" &
         info "Started test_lock_newpid, pid: $!"
    done
}

test_lock_one_fast() { # dir id [lock_unlock_options]
    args test_lock_one_fast "dir id" "lock_unlock_options" "$@"
    local dir=$1 id=$2  i=0

    q mkdir -p -- "$dir"
    cd "$dir" || exit

    while true ; do
        [ -f "stop" ] &&  { debug "stopping $id" ; exit ; }
        test_lock_spin "lock" "$id" $3 || exit
        [ -f counter ] && i=$(< counter)
        i=$((i+1))
        echo $i > counter
        info counter
        "${LOCKER[@]}" unlock "lock" "$id" $3
    done
}
