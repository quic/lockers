#!/usr/bin/env bash
#
# Copyright (c) 2016, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

usage() { # error_message
    local prog=$(basename -- "$0")
    cat >&2 <<EOF

    usage: $prog -u|-h|--help
           $prog [lopts] acquire <semaphore_path> max id
           $prog [lopts] fast_acquire <semaphore_path> max id
           $prog [lopts] acquire_slot <semaphore_path> slot id
           $prog [lopts] release <semaphore_path> id

           $prog [lopts] owners <semaphore_path> > uids
           $prog [lopts] owner <semaphore_path> <slot> > uid
           $prog [lopts] slot <semaphore_path> id > slot

    The semaphore_ssh is a convenience wrapper for using the semaphore
    with the lock_ssh locker.

    <semaphore_path> filesystem path which all semaphore users have write
                     access to.

    <max>  The maximum semaphore count

    lopts (locker options)

    --locker-arg              Specify arg to the ssh locker.  Args may be
                              added by using --locker-args multiple times.

    --grace-seconds <seconds> Specify the grace seconds for the ssh locker.

    --on-check-fail notifier  Specify a notifier to run a command when
                              it is not possible to determine
                              live/staleness.  Args may be added by
                              using --on-check-notifier multiple times.
                              (Default notifier prints warnings to stderr)

                              The notifier should expect the following
                              trailing arguments:
                              <semaphore> <lock> <locking_host> <uid> <reason>

EOF
    [ $# -gt 0 ] && echo "Error - $@" >&2
    exit 10
}

locker_args() { # args...
    while [ $# -gt 0 ] ; do
        LOCKER+=(--locker-arg "$1")
        shift
    done
}

MYPATH=$(readlink -e -- "$0")
MYDIR=$(dirname -- "$MYPATH")
LOCKER=("$MYDIR/lock_ssh.sh")
WRAPPED=("$MYDIR/semaphore.sh")

while [ $# -gt 0 ] ; do
    case "$1" in
        -u|-h|--help) usage ;;
        --on-check-fail) CHECK_FAIL+=("$1" "$2") ; shift ;;
        --locker-arg) locker_args "$2" ; shift ;;
        --grace-seconds) locker_args "$1" "$2" ; shift ;;

        *) break ;;
    esac
    shift
done

action=$1 ; shift
sem=$1 ; shift

if [ -n "$CHECK_FAIL" ] ; then
    locker_args "${CHECK_FAIL[@]}" --on-check-fail "$sem"
fi

"${WRAPPED[@]}" "${LOCKER[@]}" "$action" "$sem" "$@"
