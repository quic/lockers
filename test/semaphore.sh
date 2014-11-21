#!/usr/bin/env bash
#
# Copyright (c) 2014, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

MYPROG=$(readlink -f "$0")
MYDIR=$(dirname "$MYPROG")
MYNAME=$(basename "$MYPROG")
source "$MYDIR"/lib.sh
source "$MYDIR"/results.sh

out() { OUT=$("$@") ; }
outerr() { OUT=$("$@" 2>&1) ; }

SUBJECT=($MYDIR/../$MYNAME --local)
ID=$MYDIR/../local_id.sh
OUTDIR=$MYDIR/out
SEM=$OUTDIR/$MYNAME

rm -rf "$SEM" # cleanup any previous runs

first=$$
stable_process & second=$!
uidf=$("$ID" uid "$first")
uids=$("$ID" uid "$second")

out "${SUBJECT[@]}" acquire "$SEM" 1 "$first"
result "Acq by first($first)" "$OUT"

out "${SUBJECT[@]}" owners "$SEM"
result_out "Owners should be uid of first($uidf)" "$uidf" "$OUT"

out "${SUBJECT[@]}" slot "$SEM" "$first"
result_out "Slot should be 1" "1" "$OUT"

out "${SUBJECT[@]}" release "$SEM" "$first"
result "Rel by first($first)" "$OUT"


out "${SUBJECT[@]}" acquire "$SEM" 1 "$first"
result "Acq2 by first($first)" "$OUT"
! out "${SUBJECT[@]}" acquire "$SEM" 1 "$second"
result "Max 1 ! Acq by second($second)" "$OUT"
out "${SUBJECT[@]}" acquire "$SEM" 2 "$second"
result "Max 2 Acq by second($second)" "$OUT"

out "${SUBJECT[@]}" owners "$SEM"
OUT=$(echo $OUT)
[ "$OUT" = "$uidf $uids" ] || [ "$OUT" = "$uids $uidf" ]
result "Owners should be uids of first and second($uidf $uids)" "$OUT"

out "${SUBJECT[@]}" slot "$SEM" "$first"
result_out "Slot for first($first) should be 1" "1" "$OUT"
out "${SUBJECT[@]}" slot "$SEM" "$second"
result_out "Slot for second($second) should be 2" "2" "$OUT"

out "${SUBJECT[@]}" release "$SEM" "$first"
result "Rel again by first($first)" "$OUT"

out "${SUBJECT[@]}" acquire "$SEM" 1 "$first"
result "Acq3 by first($first)" "$OUT"

out "${SUBJECT[@]}" release "$SEM" "$first"
result "Rel again by first($first)" "$OUT"
out "${SUBJECT[@]}" release "$SEM" "$second"
result "Rel again by second($second)" "$OUT"


rmdir "$OUTDIR"

exit $RESULT
