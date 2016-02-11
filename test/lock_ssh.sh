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


LOCKER=$MYDIR/../lock_ssh.sh
FAST_LOCK=$MYDIR/../fast_lock.sh
OUTDIR=$MYDIR/out
LOCK=$OUTDIR/lock_ssh

NFILE=$LOCK.notified
[ "$1" = "--notify" ] && { shift ; echo "$@" > "$NFILE" ; exit ; }

mkdir -p "$OUTDIR"
rm -rf "$LOCK" # cleanup any previous runs

myhost=$(hostname --fqdn)
if ! "$LOCKER" is_host_compatible "$myhost" ; then
    echo "WARNING UNTESTED: host incompatible"
    exit 0
fi

first=$$
stable_process & second=$!

out "$LOCKER" lock "$LOCK" $first
result "Lock by first($first)" "$OUT"

uid=$("$MYDIR"/../ssh_id.sh uid $first)
out "$LOCKER" owner "$LOCK" ; [ "$OUT" =  "$uid" ]
result "Owner should be ssh_id($uid)" "$OUT"

out "$LOCKER" owner_pid "$LOCK" ; [ "$OUT" =  "$first" ]
result "Owner_pid should be first($first)" "$OUT"

out "$LOCKER" owner_host "$LOCK" ; [ "$OUT" =  "$myhost" ]
result "Owner_host should be myhost($myhost)" "$OUT"

"$LOCKER" is_mine "$LOCK" $first
result "first($first) is_mine" "$OUT"

! out "$LOCKER" is_mine "$LOCK" $second
result "second($second) ! is_mine" "$OUT"

! outerr "$LOCKER" lock "$LOCK" first
result "Cannot relock by first($first)" "$OUT"

! outerr "$LOCKER" lock "$LOCK" $second
result "Cannot lock by second($second)" "$OUT"

out "$LOCKER" unlock "$LOCK" $first
result "Unlock by first($first)" "$OUT"

out "$LOCKER" lock "$LOCK" $second
result "Can now lock by second($second)" "$OUT"

out "$LOCKER" unlock "$LOCK" $second
result "Unlock by second($second)" "$OUT"


"$LOCKER" lock "$LOCK" $second
kill_wait $second > /dev/null 2>&1
sleep 2 # make the second stale
 # starts cleanup after lock attempt
out "$LOCKER" --grace-seconds 1 lock "$LOCK" $first
sleep 1
out "$LOCKER" --grace-seconds 1 lock "$LOCK" $first
result "Dead lock by second($second), can lock by first($first)" "$OUT"

out "$LOCKER" unlock "$LOCK" $first
"$LOCKER" lock "$LOCK" $second
sleep 2 # make the second stale
out "$LOCKER" lock_check "$LOCK" $first
result "Dead lock by second($second), can lock_check by first($first)" "$OUT"

out "$LOCKER" unlock "$LOCK" $first


BAD_ID=BADID.$$
"$FAST_LOCK" lock "$LOCK" "$BAD_ID"
CHECKER_ARGS=(--on-check-fail "$MYPROG" --on-check-fail --notify)
"$LOCKER" "${CHECKER_ARGS[@]}" lock_check "$LOCK" $$ 1
OUT=$(< "$NFILE")
result_out "Notify on stale" "$LOCK $HOSTNAME $BAD_ID WARNING: host($HOSTNAME) \
is unable to identify live/staleness for $BAD_ID: Malformed UID" "$OUT"


[ $RESULT -eq 0 ] && rm -rf "$LOCK" "$NFILE"
rmdir "$OUTDIR"

exit $RESULT
