#!/usr/bin/env bash
#
# Copyright (c) 2013, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

MYPROG=$(readlink -f "$0")
MYDIR=$(dirname "$MYPROG")
MYNAME=$(basename "$MYPROG")
source "$MYDIR"/lib.sh
source "$MYDIR"/results.sh

ID=$MYDIR/../$MYNAME

MYSSHDEST=$(hostname)
MYHOSTID=$(hostname --fqdn)

if ! "$ID" is_host_compatible "$MYSSHDEST" ; then
    echo "WARNING UNTESTED: host incompatible"
    exit 0
fi

stable_process & opid=$!

uid=$("$ID" uid "$opid")
result "uid of original pid($opid)" "$uid"

out=$(echo "$uid" | grep "$opid")
result "original pid in uid($uid)" "$out"

"$ID" is_valid_uid "$uid"
result "is_valid uid($uid)" "$out"

! "$ID" is_valid_uid "$opid"
result "Not is_valid opid($opid)" "$out"

sshuid=$("$ID" ssh_uid "$MYHOSTID" "$opid")
result_out "Internal ssh_uid" "$uid" "$sshuid"

pid=$("$ID" pid "$uid")
result_out "pid == original pid" "$opid" "$pid"

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

! "$ID" is_stale "malformed"
result "Not is_stale malformed"

if [ "$MYSSHDEST" = "$MYHOSTID" ] ; then
    echo "WARNING UNTESTED: is_stale notifier because hostname = fqdn"
else
    # This test is fast compared to the "full" one below because the
    # host exits and so there is no waiting for a time out.`
    notification=$("$ID" --on-check-fail echo is_stale "$host_uid")
    result_out "is_stale notifier" "$MYHOSTID $host_uid WARNING: host($MYHOSTID)\
 is unable to identify live/staleness for $host_uid: HOSTID Missmatch" "$notification"
fi

if [ "$1" = "--full" ] ; then # not good for automated tests.
    # Can take upwards to 2mins to time out
    uhost_uid=$(echo "$uid"|sed -e 's/[^:]*:/unknown:/')
    ! "$ID" is_stale "$uhost_uid"
    result "Not is_stale altered unknown_uid($uhost_uid)"
fi

hostid=$("$ID" hostid "$uid")
result_out "hostid($uid) == $MYHOSTID" "$MYHOSTID" "$hostid"

sshdest=$("$ID" sshdest "$uid")
result_out "sshdest($uid) == $MYHOSTID" "$MYHOSTID" "$sshdest"

kill_wait $opid > /dev/null 2>&1

"$ID" is_stale "$uid"
result "is_stale dead uid($uid)"

if [ "$MYSSHDEST" = "$MYHOSTID" ] ; then
    echo "WARNING UNTESTED: Not is_stale dead mismatch(short) host_uid because hostname = fqdn"
    echo "WARNING UNTESTED: is_stale dead notifier because hostname = fqdn"
else
    ! "$ID" is_stale "$host_uid"
    result "Not is_stale dead mismatch(short) host_uid($host_uid)"

    notification=$("$ID" --on-check-fail echo is_stale "$host_uid")
    result_out "is_stale dead notifier" "$MYHOSTID $host_uid WARNING: host($MYHOSTID)\
 is unable to identify live/staleness for $host_uid: HOSTID Missmatch" "$notification"
fi

exit $RESULT
