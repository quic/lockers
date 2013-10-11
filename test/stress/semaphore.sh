#!/usr/bin/env bash
#
# Copyright (c) 2013, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

usage() { # error_message
    local prog=$(basename "$0")
    cat <<EOF
       $prog test_one <dir> <max> [id]
       $prog test_ten <dir> [--stop]

    Examples:

       $prog -d -l test_ten sem
       $prog -d -l test_ten sem --stop

EOF
    [ $# -gt 0 ] && echo "Error - $@" >&2
    exit 10
}

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

spin_constant() { # semaphore max sec [id]
    args spin_constant "semaphore max sec" "id" "$@"
    local sem=$1 max=$2 sec=$3 id=($4)  locked=0 ; shift 4

    # 10 or above is critical, stop spinning.
    "${SEMAPHORE[@]}" acquire "$sem" "$max" "${id[@]}" ; locked=$?
    while [ $locked -gt 0  -a  $locked -lt 10 ] ; do
        sleep "$sec"
        "${SEMAPHORE[@]}" acquire "$sem" "$max" "${id[@]}" ; locked=$?
    done
    return $locked
}

test_one() { # dir max [id]
    args test_one "dir max" "id" "$@"
    local dir=$1 max=$2 id=($3) slot i=0 git

    q mkdir -p "$dir"
    cd "$dir" || exit

    while true ; do
        [ -f "stop" ] &&  { debug "stopping $id" ; exit ; }
        spin_constant semaphore "$max" 0 "${id[@]}" || exit
        slot=$("${SEMAPHORE[@]}" slot semaphore "${id[@]}")
        [ -z "$slot" ] && { error "no slot $id" ; exit ; }
        info "slot $slot acquired by $id"
        git=git.$slot

        "${LOCKER_TESTER[@]}" test_git_task "$git" "${id[@]}"

        "${SEMAPHORE[@]}" release semaphore "${id[@]}"
    done
}

test_one_newpid() { "$0" -l $TEST_DEBUG test_one "$1" "$2" $$ ; } # dir max

test_ten() { # dir [--stop]
    args test_ten "dir" "--stop" "$@"
    [ "$2" == "--stop" ] && { touch "$1"/stop ; exit ; }
    q mkdir -p "$1"
    for i in $(seq 10) ; do
         "$0" $TEST_DEBUG -l test_one_newpid "$1" 3 > "$1/$i.out" 2> "$1/$i.err" &
    done
}

mypath=$(readlink -e "$0")
mydir=$(dirname "$mypath")
locker_dir=$(dirname "$(dirname "$mydir")")

SEMAPHORE=("$locker_dir"/semaphore.sh)
LOCKER_TESTER=("$mydir"/fast_lock.sh)
while [ $# -gt 0 ] ; do
    case "$1" in
        -di|--info) DEBUG=INFO ; TEST_DEBUG=$1
            SEMAPHORE=("${SEMAPHORE[@]}" "$1") ;;
        -d|--debug) DEBUG=DEBUG ; TEST_DEBUG=$1
            SEMAPHORE=("${SEMAPHORE[@]}" "$1") ;;
        -l) SEMAPHORE=("${SEMAPHORE[@]}" "$1") ;;

        *) break ;;
    esac
    shift
done

[ $# -eq 0 ] && usage

"$@"
