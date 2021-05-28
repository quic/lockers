#!/usr/bin/env bash
#
# Copyright (c) 2021, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

readlink --canonicalize / &> /dev/null || readlink() { greadlink "$@" ; } # for MacOS
MYPROG=$(readlink -f -- "$0")
MYDIR=$(dirname -- "$MYPROG")
MYNAME=$(basename -- "$MYPROG")
source "$MYDIR"/../../lib/test/results.sh
source "$MYDIR"/lib_k8s.sh

out() { OUT=$("$@") ; }
outerr() { OUT=$("$@" 2>&1) ; }
die() { echo -e "$@" ; exit 1 ; } # error_message

run_test_with_dots() { # cmds...
    echo "WARNING: This test could take upto 5 mins to complete"
    "$@" &
    pid=$!
    while kill -0 $pid 2>"/dev/null" ; do
        echo -n "."
        sleep 5
    done
    echo
    wait $pid
}

usage() { # error_message
    local k8s_msg=$(k8s_usage)
    cat <<-EOF
    Usage:
        $k8s_msg

    Refer to $MYDIR/README.md for more information.

EOF

    [ -n "$1" ] && echo -e '\n'"ERROR: $1"
    exit 1
}

while [ $# -gt 0 ] ; do
    case "$1" in
        -h|--help)    usage ;;
        *)            k8s_parse_arg "$@" ; args=$? ; [ "$args" = 0 ] && usage ; shift $args ;;
    esac
done

K8S_PVC_NAME="lockers-repo"
K8S_YAMLS_DIR=$MYDIR
K8S_DOCKER_CONTEXT="$MYDIR"/../../
K8S_DEPLOYMENT="lockers-lock-k8s-test-$(uuidgen | tr 'A-Z' 'a-z')"
ID_CHECKER="/home/locker_user/lockers/k8s_id.sh"
LOCKER="/home/locker_user/lockers/$MYNAME"
LOCK="/lockers/$K8S_DEPLOYMENT/file"
k8s_check_prerequisite || die "Prerequisite check failed, make sure kubernetes client running"
k8s_setup_test_env || die "Failed to setup the test environment"

# clean up any existing lock
rm -rf "$LOCK"
STABLE_A=$(k8s_stable_process "$POD_A")
STABLE_B=$(k8s_stable_process "$POD_B")

echo "Running Tests...."

! k8s_exec "$POD_B" "env" "-i" "$LOCKER" is_host_compatible
result "negative is_host_compatible check on pod B"

k8s_exec "$POD_B" "$LOCKER" is_host_compatible
result "is_host_compatible check on pod B"

out k8s_exec "$POD_A" "$LOCKER" lock "$LOCK" "$STABLE_A"
result "lock by pod A($STABLE_A)" "$OUT"

uid=$(k8s_exec "$POD_A" "$ID_CHECKER" uid "$STABLE_A")
out k8s_exec "$POD_A" "$LOCKER" owner "$LOCK"
result_out "owner check by pod A" "$uid" "$OUT"

out k8s_exec "$POD_B" "$LOCKER" owner "$LOCK"
result_out "owner check by pod B for lock owned by A" "$uid" "$OUT"

out k8s_exec "$POD_A" "$LOCKER" is_mine "$LOCK" "$STABLE_A"
result "pod A is_mine($STABLE_A)" "$OUT"

k8s_exec "$POD_A" "$LOCKER" unlock "$LOCK" "$STABLE_A" > /dev/null 2>&1

out k8s_exec "$POD_A" "$LOCKER" lock "$LOCK" "$STABLE_A"
result "lock again by pod A($STABLE_A)" "$OUT"

! outerr k8s_exec "$POD_B" "$LOCKER" lock "$LOCK" "$STABLE_B"
result "lock acquire fail by pod B($STABLE_B)" "$OUT"

! outerr k8s_exec "$POD_B" "$LOCKER" lock_check "$LOCK" "$STABLE_B"
result "lock_check acquire fail by pod B($STABLE_B)" "$OUT"

! outerr k8s_exec "$POD_B" "$LOCKER" is_mine "$LOCK" "$STABLE_B"
result "lock is_mine fail by pod B($STABLE_B)" "$OUT"

k8s_exec "$POD_A" "$LOCKER" unlock "$LOCK" "$STABLE_A" > /dev/null 2>&1

out k8s_exec "$POD_B" "$LOCKER" lock "$LOCK" "$STABLE_B"
result "lock by pod B($STABLE_B)" "$OUT"

uid=$(k8s_exec "$POD_B" "$ID_CHECKER" uid "$STABLE_B")
out k8s_exec "$POD_B" "$LOCKER" owner "$LOCK"
result_out "owner check by pod B" "$uid" "$OUT"

k8s_exec "$POD_B" "$LOCKER" unlock "$LOCK" "$STABLE_B" > /dev/null 2>&1

tmp_a_pid=$(k8s_stable_process "$POD_A")
out k8s_exec "$POD_A" "$LOCKER" lock "$LOCK" "$tmp_a_pid"
tmp_a_uid=$(k8s_exec "$POD_A" "$LOCKER" owner "$LOCK")
k8s_exec "$POD_A" kill -9 "$tmp_a_pid" # makes tmp_a_pid stale

out k8s_exec "$POD_B" "$LOCKER" owner "$LOCK"
result_out "owner check by pod B for stale lock of pod A" "$tmp_a_uid" "$OUT"

out k8s_exec "$POD_B" "$LOCKER" lock_check "$LOCK" "$STABLE_B"
result "lock acquired by B($STABLE_B) by recovering stale of pod A($tmp_a_pid)" "$OUT"

out k8s_exec "$POD_B" "$LOCKER" is_mine "$LOCK" "$STABLE_B"
result "is_mine check by B after acquiring stale lock" "$OUT"

k8s_delete_pod "$POD_B" # this should make above lock by B stale
k8s_populate_pods # deployment will generate a new POD meantime
STABLE_B=$(k8s_stable_process "$POD_B")

run_test_with_dots out k8s_exec "$POD_A" "$LOCKER" lock_check "$LOCK" "$STABLE_A"
result "lock by pod A($STABLE_A) by recovering stale lock" "$OUT"

out k8s_exec "$POD_A" "$LOCKER" is_mine "$LOCK" "$STABLE_A"
result "pod A is_mine($STABLE_A)" "$OUT"

k8s_end_test $RESULT
