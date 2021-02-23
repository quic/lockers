#!/usr/bin/env bash
#
# Copyright (c) 2021, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

usage() { # error_message
    local prog=$(basename -- "$0")
    cat >&2 <<EOF

    usage: $prog [opts] lock <lock_path> <pid>
           $prog [opts] lock_check <lock_path> <pid>
           $prog [opts] unlock <lock_path> <pid|uid>

           $prog [opts] fast_lock <lock_path> <pid>
           $prog [opts] owner <lock_path> > uid
           $prog [opts] is_mine <lock_path> <pid|uid>

    A lock manager designed for cluster use via a shared filesystem with
    K8s run checks.

    --on-check-fail notifier  Specify a notifier to run a command when
                              it is not possible to determine
                              live/staleness.  Args may be added by
                              using --on-check-notifier multiple times.
                              (Default notifier prints warnings to stderr)

                              The notifier should expect the following
                              trailing arguments:
                              <lock> <locking_host> <uid> <reason>

EOF
    [ $# -gt 0 ] && echo "Error - $@" >&2
    exit 10
}

readlink --canonicalize / &> /dev/null || readlink() { greadlink "$@" ; } # for MacOS
MYPATH=$(readlink -e -- "$0")
MYDIR=$(dirname -- "$MYPATH")

"$MYDIR/lib/hostpid_lock.sh" --idhelper "$MYDIR/k8s_id.sh" "$@"