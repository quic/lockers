#!/usr/bin/env bash
#
# Copyright (c) 2013, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

MYPROG=$(readlink -f "$0")
MYDIR=$(dirname "$MYPROG")
source "$MYDIR"/lib.sh
source "$MYDIR"/results.sh

out() { OUT=$("$@") ; }
outerr() { OUT=$("$@" 2>&1) ; }

LOCKER=$MYDIR/../lock_local.sh
OUTDIR=$MYDIR/out
LOCK=$OUTDIR/lock_local

rm -rf "$LOCK" # cleanup any previous runs

first=$$
stable_process & second=$!

out "$LOCKER" lock "$LOCK" $first ; result "Lock by first($first)" "$OUT"

out "$LOCKER" owner "$LOCK"
result_out "Owner should be first($first)" "$first" "$OUT"

"$LOCKER" is_mine "$LOCK" $first ; result "first($first) is_mine" "$OUT"

! out "$LOCKER" is_mine "$LOCK" $second ; result "second($second) ! is_mine" "$OUT"

! outerr "$LOCKER" lock "$LOCK" first ; result "Cannot relock by first($first)" "$OUT"

! outerr "$LOCKER" lock "$LOCK" $second ; result "Cannot lock by second($second)" "$OUT"

out "$LOCKER" unlock "$LOCK" $first ; result "Unlock by first($first)" "$OUT"

out "$LOCKER" lock "$LOCK" $second ; result "Can now lock by second($second)" "$OUT"

out "$LOCKER" unlock "$LOCK" $second ; result "Unlock by second($second)" "$OUT"

"$LOCKER" lock "$LOCK" $second
kill_wait $second > /dev/null 2>&1
out "$LOCKER" lock "$LOCK" $first ; result "Dead lock by second($second), can lock by first($first)" "$OUT"

"$LOCKER" unlock "$LOCK" $first
! out "$LOCKER" lock "$LOCK" $second ; result "Cannot lock by dead second($second)" "$OUT"


[ $RESULT -eq 0 ] && rm -rf "$LOCK"
rmdir "$OUTDIR"

exit $RESULT
