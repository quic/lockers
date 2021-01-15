#!/usr/bin/env bash

readlink --canonicalize / &> /dev/null || readlink() { greadlink "$@" ; } # for MacOS
MYDIR=$(dirname -- "$(readlink -f -- "$0")")

die() { echo -e "$@" ; exit 1 ; } # error_message

wait_for() { # timeout [args]...
    local timeout=$1 ; shift
    local remaining_time
    for remaining_time in $(seq "$timeout" -2 1) ; do
        "$@" && return
        echo -n "."
        sleep 2s
    done
    return 1
}

check_prerequisite() {
    minikube version > /dev/null || die "Minikube is not installed"
    local status=$(minikube status -o=json)
    echo "$status" | jq ."Kubelet" | grep -q "Running" \
        || die "Minikube Kubelet is not running"
    echo "$status" | jq ."Host" | grep -q "Running" \
        || die "Minikube Host is not running"
}

use_minikube_docker_deamon() {
    eval $(minikube docker-env) \
        || die "Cannot point to minikube's docker env"
}

minikube_mount_lockers() {
    minikube mount "$MYDIR"/../../../lockers:/lockers > /dev/null &
    MOUNT_PID=$!
    trap "kill -9 $MOUNT_PID" EXIT
    if ! wait_for "$SECONDS_MOUNT_TIMEOUT" minikube ssh '[ -d /lockers ]' &> /dev/null ; then
        die "Mount failed on minikube"
    fi
}

is_pod_in_state() { # pod state
    local status=$(kubectl get pod "$1" -o jsonpath="{.status.phase}")
    [ "$status" == "$2" ]
}

wait_for_pod_to_run() { # pod
    if ! wait_for "$SECONDS_POD_RUN_TIMEOUT" "is_pod_in_state" "$1" "Running" ; then
        kubectl delete pod "$1"
        die "Unable to bring up POD in specified time"
    fi
}

get_manifest() { # pod_name image
    local manifest=$(cat "$MYDIR"/lockers-k8s.json)
    manifest="${manifest//PROJECT_NAME/$1}"
    manifest="${manifest//IMAGE_NAME/$2}"
    echo "$manifest"
}

run_test() {
    local project_name="lockers-minikube-test-$$"
    local image_name="${project_name}_run_tests:latest"
    compose_args=(--project-name "$project_name"
                  -f "$MYDIR"/lockers.yaml)

    use_minikube_docker_deamon
    minikube_mount_lockers
    local ret
    docker-compose "${compose_args[@]}" build ; ret=$?

    if [ $ret -eq 0 ] ; then
        get_manifest "$project_name" "$image_name" | kubectl apply -f  -
        wait_for_pod_to_run "$project_name"

        kubectl exec "$project_name" -- bash -c 'su locker_user -c /start.sh' || ret=$?

        kubectl delete pod "$project_name"
    fi
    return "$ret"
}

SECONDS_MOUNT_TIMEOUT=100
SECONDS_POD_RUN_TIMEOUT=100

check_prerequisite
run_test