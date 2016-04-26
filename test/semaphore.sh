#!/usr/bin/env bash
#
# Copyright (c) 2014, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

MYPROG=$(readlink -f "$0")
MYDIR=$(dirname "$MYPROG")
MYNAME=$(basename "$MYPROG")
source "$MYDIR"/lib.sh
source "$MYDIR"/results.sh
source "$MYDIR"/lib_semaphore.sh

mylocker() {
    MYLOCKER=($MYDIR/../lock_local.sh)
    "${MYLOCKER[@]}" "$@"
}

MYSUBJECT=$MYDIR/../$MYNAME
SUBJECT=("$MYSUBJECT" --local)
ID=$MYDIR/../local_id.sh
OUTDIR=$MYDIR/out
SEM=$OUTDIR/$MYNAME

[ "$1" = "--mylocker" ] && { shift ; mylocker "$@" ; exit ; }

rm -rf "$SEM" # cleanup any previous runs

lib_semaphore_test_primary_api


first=$$
out "${MYSUBJECT[@]}" "$0" --locker-arg --mylocker acquire "$SEM" 1 "$first"
result "MyLocker Acq by first($first)" "$OUT"
out "${MYSUBJECT[@]}" "$0" --locker-arg --mylocker release "$SEM" "$first"
result "MyLocker Rel by first($first)" "$OUT"


rmdir "$OUTDIR"

exit $RESULT
