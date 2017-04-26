#!/usr/bin/env bash
#
# Copyright (c) 2013, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

MYPROG=$(readlink -f "$0")
MYDIR=$(dirname "$MYPROG")
source "$MYDIR"/results.sh

out() { OUT=$("$@") ; }
outerr() { OUT=$("$@" 2>&1) ; }

LOCKER=$MYDIR/../fast_lock.sh
OUTDIR=$MYDIR/out
LOCK=$OUTDIR/fast_lock

rm -rf "$LOCK" # cleanup any previous runs

out "$LOCKER" lock "$LOCK" first ; result "Lock by first" "$OUT"

out "$LOCKER" owner "$LOCK"
result_out "Owner should be first" "first" "$OUT"

"$LOCKER" is_mine "$LOCK" first ; result "first is_mine" "$OUT"

! out "$LOCKER" is_mine "$LOCK" second ; result "second ! is_mine" "$OUT"

! outerr "$LOCKER" lock "$LOCK" first ; result "Cannot relock by first" "$OUT"

! outerr "$LOCKER" lock "$LOCK" second ; result "Cannot lock by second" "$OUT"

out "$LOCKER" ids_in_use "$LOCK" ;
result_out "first is ids_in_use" "first" "$OUT"

mkdir -p "$LOCK/markers/second/owner"
out "$LOCKER" ids_in_use "$LOCK" ; OUT=$(echo $OUT)
result_out "second now in ids_in_use" "first second" "$OUT"

"$LOCKER" clean_stale_ids "$LOCK"
out "$LOCKER" ids_in_use "$LOCK" ;
result_out "clean_stale_ids cleaned second" "first" "$OUT"

out "$LOCKER" unlock "$LOCK" first
out "$LOCKER" lock "$LOCK" second
result "Unlock by first($first), lock by second($second)" "$OUT"
out "$LOCKER" unlock "$LOCK" second

rmdir "$OUTDIR"

exit $RESULT
