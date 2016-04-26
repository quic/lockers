#!/usr/bin/env bash
#
# Copyright (c) 2016, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

out() { OUT=$("$@") ; }

# Needs SUBJECT, ID and SEM
lib_semaphore_test_primary_api() {

    local first=$$ second
    stable_process & second=$!
    local uidf=$("$ID" uid "$first")
    local uids=$("$ID" uid "$second")

    out "${SUBJECT[@]}" acquire "$SEM" 1 "$first"
    result "Acq by first($first)" "$OUT"

    out "${SUBJECT[@]}" owners "$SEM"
    result_out "Owners should be uid of first($uidf)" "$uidf" "$OUT"

    out "${SUBJECT[@]}" slot "$SEM" "$first"
    result_out "Slot should be 1" "1" "$OUT"

    out "${SUBJECT[@]}" owner "$SEM" 1
    result_out "Owner slot should be uid of first($uidf)" "$uidf" "$OUT"

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

    out "${SUBJECT[@]}" owner "$SEM" 1
    result_out "Owner2 slot should be uid of first($uidf)" "$uidf" "$OUT"
    out "${SUBJECT[@]}" owner "$SEM" 2
    result_out "Owner slot 2 should be uid of second($uids)" "$uids" "$OUT"

    out "${SUBJECT[@]}" release "$SEM" "$first"
    result "Rel again by first($first)" "$OUT"
    out "${SUBJECT[@]}" owner "$SEM" 1
    result_out "Owner slot 1 should be blank" "" "$OUT"


    out "${SUBJECT[@]}" acquire "$SEM" 1 "$first"
    result "Acq3 by first($first)" "$OUT"
    out "${SUBJECT[@]}" owner "$SEM" 1
    result_out "Owner2 slot should be uid of first($uidf)" "$uidf" "$OUT"

    out "${SUBJECT[@]}" release "$SEM" "$first"
    result "Rel again by first($first)" "$OUT"
    out "${SUBJECT[@]}" release "$SEM" "$second"
    result "Rel again by second($second)" "$OUT"
}
