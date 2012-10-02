#!/usr/bin/env bash
#
# Copyright (c) 2013, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

MYPROG=$(readlink -f "$0")
MYDIR=$(dirname "$MYPROG")
source "$MYDIR"/lib.sh
source "$MYDIR"/results.sh

ID=$MYDIR/../ssh_id.sh

stable_process & opid=$!
myhost=$(hostname --fqdn)


uid=$("$ID" uid $opid)
out=$(echo "$uid" | grep $opid) ; result "original pid($opid) in uid($uid)" "$out"

sshuid=$("$ID" ssh_uid "$myhost" $opid)
[ "$uid" = "$sshuid" ] ; result "ssh_uid($sshuid) == uid($uid)" "$sshuid"

pid=$("$ID" pid "$uid")
[ "$pid" = "$opid" ] ; result "pid($pid) == original pid($opid)" "$pid"

"$ID" is_running "$uid" ; result "is_running live uid($uid)"

host=$("$ID" host "$uid")
[ "$host" = "$myhost" ] ; result "host($uid) == $myhost" "$host"

kill_wait $opid > /dev/null 2>&1

! "$ID" is_running "$uid" ; result "is_running dead uid($uid)"

pid=$("$ID" pid "$uid")
[ -z "$pid" ] ; result "blank pid when dead" "$pid"


exit $RESULT
