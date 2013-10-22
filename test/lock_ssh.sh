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
OUTDIR=$MYDIR/out
LOCK=$OUTDIR/lock_ssh

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
out "$LOCKER" lock "$LOCK" $first 1 # starts cleanup after lock attempt
sleep 1
out "$LOCKER" lock "$LOCK" $first 1
result "Dead lock by second($second), can lock by first($first)" "$OUT"

out "$LOCKER" unlock "$LOCK" $first
"$LOCKER" lock "$LOCK" $second
sleep 2 # make the second stale
out "$LOCKER" lock_check "$LOCK" $first
result "Dead lock by second($second), can lock_check by first($first)" "$OUT"

out "$LOCKER" unlock "$LOCK" $first


[ $RESULT -eq 0 ] && rm -rf "$LOCK"
rmdir "$OUTDIR"

exit $RESULT
