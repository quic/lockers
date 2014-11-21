#!/usr/bin/env bash
#
# Copyright (c) 2014, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

usage() { # error_message
    local prog=$(basename "$0")
    cat <<EOF

    usage: $prog <max> count [count] [--restart]

    Example in four separate windows:
      time $0 2 count 1000 --restart
      time $0 2 count 1000
      time $0 2 count 1000
      while true ; do $prog semaphore_go_stale ; done

EOF
    [ $# -gt 0 ] && echo "Error - $@" >&2
    exit 10
}

mypath=$(readlink -e "$0")
mydir=$(dirname "$mypath")
myprog=$(basename "$0") # no readlink to support other lockers
myname=$(basename "$myprog" .sh)
locker_dir=$(dirname "$(dirname "$mydir")")
. "$mydir"/lib_stress.sh

LIB_STRESS_SEMAPHORE=("$locker_dir/$myprog" -l)
DIR=$mydir/out/$myname

while [ $# -gt 0 ] ; do
    case "$1" in
        -u|-h|--help) usage ;;
        --dir) shift ; DIR=$1 ;;
        *) break ;;
    esac
    shift
done

LIB_STRESS_LOCK=$DIR/lock
LIB_STRESS_COUNTDIR=$DIR/count

max=$1 ; shift ;
[ -z "$max" ] && usage "you must specify a max for the semaphore"


lib_stress_setup_id_semaphore $max $$
echo "MY PID: $$"

action=$1 ; shift ;
[ -z "$action" ] && usage "you must specify an action"
lib_stress_"$action" "$@"
