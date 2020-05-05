#!/usr/bin/env bash
#
# Copyright (c) 2016, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

MYPROG=$(readlink -f -- "$0")
MYDIR=$(dirname -- "$MYPROG")
MYNAME=$(basename -- "$MYPROG")
source "$MYDIR"/../lib/test/lib.sh
source "$MYDIR"/../lib/test/results.sh
source "$MYDIR"/lib_semaphore.sh

SUBJECT=$MYDIR/../$MYNAME
ID=$MYDIR/../ssh_id.sh
OUTDIR=$MYDIR/out/$(basename -- "$MYNAME" .sh)
SEM=$MYNAME
MYHOST=$(hostname --fqdn)

FAST_LOCK=$MYDIR/../lib/fast_lock.sh
NLOCK=$SEM/1
NFILE=$SEM.notified
[ "$1" = "--notify" ] && { shift ; echo "$@" > "$NFILE" ; exit ; }

mkdir -p -- "$OUTDIR"
cd -- "$OUTDIR" || exit
rm -rf -- "$SEM" # cleanup any previous runs

lib_semaphore_test_primary_api


BAD_ID=BADID.$$
"$FAST_LOCK" lock "$NLOCK" "$BAD_ID"
CHECKER_ARGS=(--on-check-fail "$MYPROG" --on-check-fail --notify)
ARGS=("${CHECKER_ARGS[@]}" --grace-seconds 1)
"$SUBJECT" "${ARGS[@]}" acquire "$SEM" 1 $$
spinner 2 "lock to go stale"
"$SUBJECT" "${ARGS[@]}" acquire "$SEM" 1 $$
spinner 2 "stale_checker to run"
OUT=$(< "$NFILE")
result_out "Notify on stale" "$SEM $NLOCK $MYHOST $BAD_ID WARNING: host($MYHOST) \
is unable to identify live/staleness for $BAD_ID: Malformed UID" "$OUT"



if [ "$1" != "--keep" ] || [ $RESULT -eq 0 ] ; then
    rm -rf -- "$SEM" "$NFILE"
fi
rmdir -p -- "$OUTDIR" 2>/dev/null

exit $RESULT
