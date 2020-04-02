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

LOCKER=$MYDIR/../grace_lock.sh
OUTDIR=$MYDIR/out
LOCK=$OUTDIR/grace_lock

mkdir -p "$OUTDIR"
rm -rf "$LOCK" # cleanup any previous runs

first=1
second=2

out "$LOCKER" false lock "$LOCK" "$first"
result "lock by first($first)" "$OUT"

out "$LOCKER" owner "$LOCK"
result_out "owner" "$first" "$OUT"

"$LOCKER" is_mine "$LOCK" "$first"
result "is_mine first" "$OUT"

! out "$LOCKER" is_mine "$LOCK" "$second"
result "NOT is_mine second($second)" "$OUT"

! outerr "$LOCKER" false lock "$LOCK" "$first"
result "Cannot relock by first" "$OUT"

! outerr "$LOCKER" false lock "$LOCK" "$second"
result "Cannot lock by second" "$OUT"

out "$LOCKER" false unlock "$LOCK" "$first"
out "$LOCKER" false lock "$LOCK" "$second"
result "unlock by first, lock by second" "$OUT"
out "$LOCKER" false unlock "$LOCK" "$second"


# Stale locks
checker_eq_first=(test --checker-arg "$first" --checker-arg -eq)
checker_eq_second=(test --checker-arg "$second" --checker-arg -eq)

"$LOCKER" false lock "$LOCK" "$second"
sleep 2 # make the second stale
# start cleanup after lock attempt
out "$LOCKER" --grace-seconds 1 "${checker_eq_second[@]}" lock "$LOCK" "$first"
sleep 1
out "$LOCKER" --grace-seconds 1 false lock "$LOCK" "$first"
result "Stale second, can lock by first" "$OUT"

out "$LOCKER" false unlock "$LOCK" "$first"
"$LOCKER" false lock "$LOCK" "$second"
sleep 2 # make the second stale
out "$LOCKER" "${checker_eq_second[@]}" lock_check "$LOCK" "$first"
result "Stale second, can lock_check by first" "$OUT"
out "$LOCKER" false unlock "$LOCK" "$first"

out "$LOCKER" --grace-seconds 1 false lock "$LOCK" "$first"
sleep 2 # make first stale
out "$LOCKER" --grace-seconds 1 "${checker_eq_first[@]}" lock "$LOCK" "$second"
sleep 2 # allow cleanup
OUT=$(ls "$LOCK" 2> /dev/null)
! [ -e "$LOCK" ]
result "Stale lock cleaned up by lock attempt by another" "$OUT"

out "$LOCKER" false lock "$LOCK" "$first"
out "$LOCKER" "${checker_eq_first[@]}" lock "$LOCK" "$second"
sleep 1 # allow cleanup
OUT=$(ls "$LOCK" 2> /dev/null)
! [ -e "$LOCK" ]
result "Stale lock (no secs) cleaned up by lock attempt by another" "$OUT"


if [ "$1" != "--keep" ] || [ $RESULT -eq 0 ] ; then
    rm -rf "$LOCK"
fi
rmdir "$OUTDIR"

exit $RESULT
