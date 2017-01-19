#!/usr/bin/env bash
#
# Copyright (c) 2013, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

usage() { # error_message
    local prog=$(basename "$0")
    cat <<EOF

    usage: $prog test_one <dir> <id>
           $prog test_one_fast <dir> <id>
           $prog test_git_task <dir> <id>

    Example:

          $prog -d test_one local \$\$ > \$\$.out 2> \$\$.err

EOF
    [ $# -gt 0 ] && echo "Error - $@" >&2
    exit 10
}

myprog=$(basename "$0")
mypath=$(readlink -e "$0")
mydir=$(dirname "$mypath")
locker_dir=$(dirname "$mydir")

LOCKER=("$locker_dir/$myprog")
while [ $# -gt 0 ] ; do
    case "$1" in
        -d*|--info|--debug) LOCKER=("${LOCKER[@]}" "$1") ;;
        *) break ;;
    esac
    shift
done
TESTER=("$mydir"/fast_lock.sh -l "${LOCKER[@]}")

[ $# -eq 0 ] && usage

"${TESTER[@]}" "$@"
