#!/usr/bin/env bash
#
# Copyright (c) 2013, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

# Top level test entry for the lockers

MYPROG=$(readlink -f -- "$0")
MYDIR=$(dirname -- "$MYPROG")

RESULT=0

test_file() { # test_file
    echo ; echo "---- Testing $1 ----"
    "$MYDIR/$1" || RESULT=$?
}

"$MYDIR"/../lib/test/package.sh
test_file local_id.sh
test_file lock_local.sh
test_file semaphore.sh
test_file ssh_id.sh
test_file lock_ssh.sh
test_file semaphore_ssh.sh

exit $RESULT
