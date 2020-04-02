#!/usr/bin/env bash
#
# Copyright (c) 2013, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

MYPROG=$(readlink -f "$0")
MYDIR=$(dirname "$MYPROG")
MYNAME=$(basename "$MYPROG")
source "$MYDIR"/../lib/test/lib.sh
source "$MYDIR"/../lib/test/results.sh

out() { OUT=$("$@") ; }
outerr() { OUT=$("$@" 2>&1) ; }


LOCKER=$MYDIR/../$MYNAME
FAST_LOCK=$MYDIR/../lib/fast_lock.sh
OUTDIR=$MYDIR/out
LOCK=$OUTDIR/$MYNAME

NFILE=$LOCK.notified
[ "$1" = "--notify" ] && { shift ; echo "$@" > "$NFILE" ; exit ; }

mkdir -p "$OUTDIR"
rm -rf "$LOCK" # cleanup any previous runs

MYSSHDEST=$(hostname --fqdn)
MYHOSTID=$(hostname --fqdn)
if ! "$LOCKER" is_host_compatible "$MYSSHDEST" ; then
    echo "WARNING UNTESTED: host incompatible"
    exit 0
fi

first=$$
stable_process & second=$!

out "$LOCKER" lock "$LOCK" "$first"
result "lock first($first)" "$OUT"

uid=$("$MYDIR"/../ssh_id.sh uid "$first")
out "$LOCKER" owner "$LOCK"
result_out "owner" "$uid" "$OUT"

out "$LOCKER" owner_pid "$LOCK"
result "owner_pid" "$first" "$OUT"

out "$LOCKER" owner_hostid "$LOCK"
result_out "owner_hostid" "$MYHOSTID" "$OUT"

"$LOCKER" is_mine "$LOCK" "$first"
result "is_mine first" "$OUT"

! out "$LOCKER" is_mine "$LOCK" "$second"
result "! is_mine second($second)" "$OUT"

! outerr "$LOCKER" lock "$LOCK" first
result "Cannot relock by first" "$OUT"

! outerr "$LOCKER" lock "$LOCK" "$second"
result "Cannot lock by second, locked by first" "$OUT"

out "$LOCKER" unlock "$LOCK" "$first"
out "$LOCKER" lock "$LOCK" "$second"
result "unlock by first, lock by second" "$OUT"
out "$LOCKER" unlock "$LOCK" "$second"


"$LOCKER" lock "$LOCK" "$second"
kill_wait "$second" > /dev/null 2>&1
sleep 2 # make the second stale
 # starts cleanup after lock attempt
out "$LOCKER" --grace-seconds 1 lock "$LOCK" "$first"
sleep 1
out "$LOCKER" --grace-seconds 1 lock "$LOCK" "$first"
result "stale second, can lock by first" "$OUT"

out "$LOCKER" unlock "$LOCK" "$first"
stable_process & second=$!
"$LOCKER" lock "$LOCK" "$second"
kill_wait "$second" > /dev/null 2>&1
sleep 2 # make the second stale
out "$LOCKER" lock_check "$LOCK" "$first"
result "stale second, can lock_check by first" "$OUT"

out "$LOCKER" unlock "$LOCK" "$first"
! outerr "$LOCKER" lock "$LOCK" "$second"
result "Cannot lock by stale second" "$OUT"


BAD_ID=BADID.$$
"$FAST_LOCK" lock "$LOCK" "$BAD_ID"
CHECKER_ARGS=(--on-check-fail "$MYPROG" --on-check-fail --notify)
"$LOCKER" "${CHECKER_ARGS[@]}" lock_check "$LOCK" $$ 1
OUT=$(< "$NFILE")
result_out "notify on stale" "$LOCK $MYSSHDEST $BAD_ID WARNING: host($MYSSHDEST) \
is unable to identify live/staleness for $BAD_ID: Malformed UID" "$OUT"


[ $RESULT -eq 0 ] && rm -rf "$LOCK" "$NFILE"
rmdir "$OUTDIR"

exit $RESULT
