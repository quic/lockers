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


if ! "$ID" is_host_compatible "$myhost" ; then
    echo "WARNING UNTESTED: host incompatible"
    exit 0
fi

uid=$("$ID" uid $opid)
out=$(echo "$uid" | grep $opid)
result "original pid($opid) in uid($uid)" "$out"

sshuid=$("$ID" ssh_uid "$myhost" $opid) ; [ "$uid" = "$sshuid" ]
result "Internal ssh_uid($sshuid) == uid($uid)" "$sshuid"

pid=$("$ID" pid "$uid") ; [ "$pid" = "$opid" ]
result "pid($pid) == original pid($opid)" "$pid"

! "$ID" is_stale "$uid"
result "Not is_stale live uid($uid)"

boot_uid="$uid"1
"$ID" is_stale "$boot_uid"
result "is_stale altered boot_uid($boot_uid)"

start_uid=$(echo "$uid"|sed -e 's/\(:[0-9]*\)$/1\1/')
"$ID" is_stale "$start_uid"
result "is_stale altered start_uid($start_uid)"

host_uid=$(echo "$uid"|sed -e "s/[^:]*:/$(hostname):/")
! "$ID" is_stale "$host_uid"
result "Not is_stale mismatch(short) host_uid($host_uid)"

if [ "$1" = "--full" ] ; then # not good for automated tests.
    # Takes about 20s to time out,
    uhost_uid=$(echo "$uid"|sed -e 's/[^:]*:/unknown:/')
    ! "$ID" is_stale "$uhost_uid"
    result "Not is_stale altered unknown_uid($uhost_uid)"
fi

host=$("$ID" host "$uid")
[ "$host" = "$myhost" ]
result "host($uid) == $myhost" "$host"

kill_wait $opid > /dev/null 2>&1

"$ID" is_stale "$uid"
result "is_stale dead uid($uid)"


exit $RESULT
