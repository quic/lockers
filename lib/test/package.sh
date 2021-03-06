#!/usr/bin/env bash
#
# Copyright (c) 2020, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

# Top level test entry for the lockers

MYPROG=$(readlink -f -- "$0")
MYDIR=$(dirname -- "$MYPROG")

RESULT=0

test_file() { # test_file
    echo ; echo "---- Testing $1 ----"
    "$MYDIR/$1" || RESULT=$?
}

test_file fast_lock.sh
test_file check_lock.sh
test_file grace_lock.sh

exit $RESULT
