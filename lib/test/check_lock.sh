#!/usr/bin/env bash
#
# Copyright (c) 2013, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

MYPROG=$(readlink -f "$0")
MYDIR=$(dirname "$MYPROG")
MYNAME=$(basename "$MYPROG")
source "$MYDIR"/results.sh

out() { OUT=$("$@") ; }
outerr() { OUT=$("$@" 2>&1) ; }

LOCKER=$MYDIR/../$MYNAME
OUTDIR=$MYDIR/out
LOCK=$OUTDIR/$MYNAME

mkdir -p "$OUTDIR"
rm -rf "$LOCK" # cleanup any previous runs

first=1
second=2

out "$LOCKER" false lock "$LOCK" "$first"
result "Lock by first($first)" "$OUT"


out "$LOCKER" false owner "$LOCK" ; [ "$OUT" =  "$first" ]
result "Owner should be first($first)" "$OUT"

"$LOCKER" is_mine "$LOCK" "$first"
result "first($first) is_mine" "$OUT"

! out "$LOCKER" is_mine "$LOCK" "$second"
result "second($second) ! is_mine" "$OUT"


! outerr "$LOCKER" false lock "$LOCK" first
result "Cannot relock by first($first)" "$OUT"

! outerr "$LOCKER" false lock "$LOCK" "$second"
result "Cannot lock by second($second)" "$OUT"


out "$LOCKER" false unlock "$LOCK" "$first"
result "Unlock by first($first)" "$OUT"


out "$LOCKER" false lock "$LOCK" "$second"
result "Can now lock by second($second)" "$OUT"

out "$LOCKER" false unlock "$LOCK" "$second"
result "Unlock by second($second)" "$OUT"


"$LOCKER" false lock "$LOCK" "$second"
out "$LOCKER" true lock "$LOCK" "$first" 1
result "Dead lock by second($second), can lock by first($first)" "$OUT"


[ $RESULT -eq 0 ] && rm -rf "$LOCK"
rmdir "$OUTDIR"

exit $RESULT
