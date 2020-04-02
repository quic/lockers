#!/usr/bin/env bash
#
# Copyright (c) 2013, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

MYPROG=$(readlink -f "$0")
MYDIR=$(dirname "$MYPROG")
MYNAME=$(basename "$MYPROG")
source "$MYDIR"/lib.sh
source "$MYDIR"/results.sh

ID=$MYDIR/../$MYNAME

stable_process & opid=$!

uid=$("$ID" uid "$opid")
result "uid of opid($opid)" "$uid"

out=$(echo "$uid" | grep "$opid")
result "orignal pid in uid($uid)" "$out"

pid=$("$ID" pid "$uid")
result_out "pid of uid" "$opid" "$pid"

! "$ID" is_stale "$uid"
result "is_stale live uid($uid)"

kill_wait "$opid" > /dev/null 2>&1

"$ID" is_stale "$uid"
result "is_stale stale uid($uid)"

pid=$("$ID" pid "$uid")
result_out "blank pid when stale" "" "$pid"

exit $RESULT
