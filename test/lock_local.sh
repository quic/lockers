#!/usr/bin/env bash
#
# Copyright (c) 2013, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

MYPROG=$(readlink -f "$0")
MYDIR=$(dirname "$MYPROG")
MYNAME=$(basename "$MYPROG")
source "$MYDIR"/lib.sh
source "$MYDIR"/results.sh

out() { OUT=$("$@") ; }
outerr() { OUT=$("$@" 2>&1) ; }

LOCKER=$MYDIR/../$MYNAME
OUTDIR=$MYDIR/out
LOCK=$OUTDIR/$MYNAME
ID=$MYDIR/../local_id.sh

rm -rf "$LOCK" # cleanup any previous runs

first=$$
stable_process & second=$!

out "$LOCKER" lock "$LOCK" "$first"
result "lock by first($first)" "$OUT"

uid=$("$ID" uid "$first")
result "uid of first" "$uid"

out "$LOCKER" owner "$LOCK"
result_out "owner should be uid of first($uid)" "$uid" "$OUT"

out "$LOCKER" owner_pid "$LOCK"
result_out "owner_pid should be first($first)" "$first" "$OUT"

"$LOCKER" is_mine "$LOCK" "$first"
result "is_mine first" "$OUT"

! out "$LOCKER" is_mine "$LOCK" "$second"
result "NOT is_mine second($second)" "$OUT"

! outerr "$LOCKER" lock "$LOCK" "$first"
result "Cannot relock by first" "$OUT"

! outerr "$LOCKER" lock "$LOCK" "$second"
result "Cannot lock by second" "$OUT"

out "$LOCKER" unlock "$LOCK" "$first"
out "$LOCKER" lock "$LOCK" "$second"
result "unlock by first, lock by second" "$OUT"
out "$LOCKER" unlock "$LOCK" "$second"

"$LOCKER" lock "$LOCK" "$second"
kill_wait "$second" > /dev/null 2>&1
out "$LOCKER" lock "$LOCK" "$first"
result "Stale second, can lock by first" "$OUT"

"$LOCKER" unlock "$LOCK" "$first"
! outerr "$LOCKER" lock "$LOCK" "$second"
result "Cannot lock by dead second" "$OUT"


[ $RESULT -eq 0 ] && rm -rf "$LOCK"
rmdir "$OUTDIR"

exit $RESULT
