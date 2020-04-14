#!/usr/bin/env bash
#
# Copyright (c) 2013, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

MYPROG=$(readlink -f -- "$0")
MYDIR=$(dirname -- "$MYPROG")
MYNAME=$(basename -- "$MYPROG")
source "$MYDIR"/results.sh

out() { OUT=$("$@") ; }
outerr() { OUT=$("$@" 2>&1) ; }

LOCKER=$MYDIR/../$MYNAME
BASE_OUT=$MYDIR/out
OUTDIR=$BASE_OUT/$(basename -- "$MYNAME" .sh)
LOCK="--help lock"

rm -rf -- "$OUTDIR/$LOCK" # cleanup any previous runs
mkdir -p -- "$OUTDIR"
cd -- "$OUTDIR"

out "$LOCKER" lock "$LOCK" first
result "lock by first" "$OUT"

out "$LOCKER" owner "$LOCK"
result_out "owner should be first" "first" "$OUT"

"$LOCKER" is_mine "$LOCK" first
result "is_mine first" "$OUT"

! out "$LOCKER" is_mine "$LOCK" second
result "NOT is_mine second" "$OUT"

! outerr "$LOCKER" lock "$LOCK" first
result "Cannot relock by first" "$OUT"

! outerr "$LOCKER" lock "$LOCK" second
result "Cannot lock by second" "$OUT"

out "$LOCKER" ids_in_use "$LOCK" ;
result_out "ids_in_use is first" "first" "$OUT"

mkdir -p -- "$LOCK/build/second/owner"
out "$LOCKER" ids_in_use "$LOCK" ; OUT=$(echo $OUT)
result_out "ids_in_use now also second" "first second" "$OUT"

"$LOCKER" clean_stale_ids "$LOCK" second
out "$LOCKER" ids_in_use "$LOCK" ;
result_out "clean_stale_ids cleaned second" "first" "$OUT"

out "$LOCKER" unlock "$LOCK" first
out "$LOCKER" lock "$LOCK" second
result "unlock by first, lock by second" "$OUT"
out "$LOCKER" unlock "$LOCK" second

rmdir -p -- "$OUTDIR" "$BASE_OUT" 2>/dev/null

exit $RESULT
