#!/usr/bin/env bash
#
# Copyright (c) 2013, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

MYPROG=$(readlink -f "$0")
MYDIR=$(dirname "$MYPROG")

RESULT=0
result() { # test output
    local result=$?
    if [ $result -eq 0 ] ; then
        echo "PASSED - $1 test"
    else
        echo "*** FAILED *** - $1 test"
        RESULT=$result
        [ $# -gt 1 ] && echo "$2"
    fi
}

out() { OUT=$("$@") ; }
outerr() { OUT=$("$@" 2>&1) ; }

LOCKER=$MYDIR/../fast_lock.sh
OUTDIR=$MYDIR/out
LOCK=$OUTDIR/fast_lock

rm -rf "$LOCK" # cleanup any previous runs

out "$LOCKER" lock "$LOCK" first ; result "Lock by first" "$OUT"

out "$LOCKER" owner "$LOCK"
[ "$OUT" =  "first" ] ; result "Owner should be first" "$OUT"

"$LOCKER" is_mine "$LOCK" first ; result "first is_mine" "$OUT"

! out "$LOCKER" is_mine "$LOCK" second ; result "second ! is_mine" "$OUT"

! outerr "$LOCKER" lock "$LOCK" first ; result "Cannot relock by first" "$OUT"

! outerr "$LOCKER" lock "$LOCK" second ; result "Cannot lock by second" "$OUT"

out "$LOCKER" ids_in_use "$LOCK" ;
[ "$OUT" =  "first" ] ; result "first is ids_in_use" "$OUT"

mkdir -p "$LOCK/markers/second/owner"
out "$LOCKER" ids_in_use "$LOCK" ; OUT=$(echo $OUT)
[ "$OUT" =  "first second" ] ; result "second now in ids_in_use" "$OUT"

"$LOCKER" stale_ids "$LOCK"
out "$LOCKER" ids_in_use "$LOCK" ;
[ "$OUT" =  "first" ] ; result "stale_ids cleaned second" "$OUT"

out "$LOCKER" unlock "$LOCK" first ; result "Unlock by first" "$OUT"

out "$LOCKER" lock "$LOCK" second ; result "Can now lock by second" "$OUT"

out "$LOCKER" unlock "$LOCK" second ; result "Unlock by second" "$OUT"

rmdir "$OUTDIR"

exit $RESULT
