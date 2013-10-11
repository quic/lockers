# Copyright (c) 2013, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause
#
# A bash library of lock testing functions to be sourced by testers
#

source "$(dirname "$(readlink -e "${BASH_SOURCE[0]}")")"/test_lock.sh

test_semaphore_spin() { # semaphore max [acquire_args]
    args test_semaphore_spin "semaphore max" "acquire_args" "$@"
    local sem=$1 max=$2 locked=0 ; shift 2

    # 10 or above is critical, stop spinning.
    "${SEMAPHORE[@]}" acquire "$sem" "$max" "$@" ; locked=$?
    while [ $locked -gt 0  -a  $locked -lt 10 ] ; do
        "${SEMAPHORE[@]}" acquire "$sem" "$max" "$@" ; locked=$?
    done
    return $locked
}

test_semaphore_git_task() { # dir [id]
   test_lock_git_task "$@"
}

test_semaphore_one() { # dir max [id]
    args test_one "dir max" "id" "$@"
    local dir=$1 max=$2 id=($3) slot i=0 git

    q mkdir -p "$dir"
    cd "$dir" || exit

    while true ; do
        [ -f "stop" ] &&  { debug "stopping $id" ; exit ; }
        test_semaphore_spin semaphore "$max" "${id[@]}" || exit
        slot=$("${SEMAPHORE[@]}" slot semaphore "${id[@]}")
        [ -z "$slot" ] && error "no slot $id"
        info "slot $slot acquired by $id"
        git=git.$slot

        test_semaphore_git_task "$git" "${id[@]}"

        "${SEMAPHORE[@]}" release semaphore "${id[@]}"
    done
}

test_semaphore_newpid() { test_semaphore_one "$1" "$2" "$BASHPID" ; } # dir max

test_semaphore_ten() { # dir [--stop]
    args test_ten "dir" "--stop" "$@"
    [ "$2" == "--stop" ] && { touch "$1"/stop ; exit ; }

    local dir=$1 ; shift
    [ -d "$dir" ] &&  error "test dir $dir exists, please clean it up first"
    q mkdir -p "$dir"

    for i in $(seq 10) ; do
         test_semaphore_newpid "$dir" 3 > "$dir/$i.out" 2> "$dir/$i.err" &
         info "Started test_semaphore_newpid, pid: $!"
    done
}
