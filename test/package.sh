#!/usr/bin/env bash
#
# Copyright (c) 2013, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

# Top level test entry for the lockers

MYPROG=$(readlink -f "$0")
MYDIR=$(dirname "$MYPROG")

RESULT=0

echo ; echo "---- Test fast_lock ----"
"$MYDIR/fast_lock.sh" || RESULT=$?

echo ; echo "---- Test lock_local ----"
"$MYDIR/lock_local.sh" || RESULT=$?

exit $RESULT