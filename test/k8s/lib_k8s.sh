#!/usr/bin/env bash
#
# Copyright (c) 2021, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

source "$(dirname -- "$0")/lib_minikube.sh"

K8S_USE_MINIKUBE=false
K8S_NAMESPACE=default
K8S_SERVICE_ACCOUNT=default
K8S_CREATE_ROLE=false
K8S_CREATE_PVC=false

k8s_die() { echo "$1" >&2 ; kill $$ ; exit 1 ; } # error_message

k8s_usage() {
    echo "
        -h|--help                     Usage/help
        -m|--minikube                 tests will be run on minikube cluster
        -d|--docker-registry          Docker registry from where k8s server will pull images
        -n|--namespace                Namespace where the pod should be created
        -s|--service-account          Service account with enough roles to run the tests
                                      (create on pods/exec and get on pods and nodes)
        --create-role                 Create the role specified by ./role.yaml
        --create-pvc                  create the pvc specified by ./pvc.yaml
        -p|--pvc-name                 Name of existing PersistentVolumeClaim to be used for tests
    "
}

k8s_parse_arg() { # args # returns args consumed
    case "$1" in
        -m|--minikube)        K8S_USE_MINIKUBE=true ; return 1 ;;
        -d|--docker-registry) shift ; K8S_DOCKER_REGISTRY=$1 ; return 2 ;;
        -n|--namespace)       shift ; K8S_NAMESPACE=$1 ; return 2 ;;
        -s|--service-account) shift ; K8S_SERVICE_ACCOUNT=$1 ; return 2 ;;
        --create-role)        K8S_CREATE_ROLE=true ; return 1 ;;
        --create-pvc)         K8S_CREATE_PVC=true ; return 1 ;;
        -p|--pvc-name)        shift ; K8S_PVC_NAME=$1 ; return 2 ;;
    esac
    return 0
}

k8s_check_prerequisite() {
    kubectl version --client=true > /dev/null 2>&1 || k8s_die "kubectl client not installed"
    [ "$K8S_USE_MINIKUBE" = "true" ] || return 0
    minikube_check_prerequisite
}

k8s_get_manifest() { # pod_name image
    local manifest=$(cat "$K8S_YAMLS_DIR"/lockers-k8s.yaml)
    manifest="${manifest//PROJECT_NAME/$1}"
    manifest="${manifest//IMAGE_NAME/$2}"
    manifest="${manifest//NAMESPACE_NAME/$K8S_NAMESPACE}"
    manifest="${manifest//SERVICE_ACCOUNT_NAME/$K8S_SERVICE_ACCOUNT}"
    if [ "$K8S_USE_MINIKUBE" = "true" ] ; then
        manifest="${manifest//IMAGE_PULL_POLICY/Never}"
    else
        manifest="${manifest//IMAGE_PULL_POLICY/Always}"
    fi
    echo "$manifest"
}

k8s_end_test() { # exit_code
    kubectl --namespace="$K8S_NAMESPACE" delete deployment "$K8S_DEPLOYMENT"
    exit $1
}

k8s_populate_pods() {
    local pods="$(kubectl --namespace="$K8S_NAMESPACE" get pods --sort-by=.status.startTime | awk '{print $1}' | grep "$K8S_DEPLOYMENT")"
    POD_A="$(echo "$pods" | sed -n 1p)"
    POD_B="$(echo "$pods" | sed -n 2p)"
}

k8s_exec() { # pod cmds...
    local pod=$1 ; shift
    kubectl --namespace="$K8S_NAMESPACE" exec "$pod" -- "$@"
}

k8s_stable_process() { # pod
    k8s_exec "$1" bash -c "sleep infinity & echo \$!"
}

k8s_setup_test_env() {
    [ -z "$K8S_DEPLOYMENT" ] && k8s_die "set K8S_DEPLOYMENT"
    [ -z "$K8S_DOCKER_CONTEXT" ] && k8s_die "set K8S_DOCKER_CONTEXT"
    [ -z "$K8S_YAMLS_DIR" ] &&  k8s_die "set K8S_YAMLS_DIR"

    local image_name="${K8S_DEPLOYMENT}"

    if [ "$K8S_USE_MINIKUBE" = "true" ] ; then
        minikube_docker_deamon || k8s_die "Failed shifting to minikube docker"
    else
        [ -z "$K8S_DOCKER_REGISTRY" ] &&  k8s_die "set K8S_DOCKER_REGISTRY"
        image_name="${K8S_DOCKER_REGISTRY}:${image_name}"
    fi
    docker build --quiet -t "$image_name"  -f "$K8S_YAMLS_DIR"/Dockerfile $K8S_DOCKER_CONTEXT
    local ret=$?

    [ "$K8S_USE_MINIKUBE" = "true" ] || docker push "$image_name"

    if [ $ret -eq 0 ] ; then
        [ "$K8S_CREATE_ROLE" = "true" ] && kubectl --namespace="$K8S_NAMESPACE" apply -f "$K8S_YAMLS_DIR"/role.yaml
        [ "$K8S_CREATE_PVC" = "true" ] && kubectl --namespace="$K8S_NAMESPACE" apply -f "$K8S_YAMLS_DIR"/pvc.yaml
        k8s_get_manifest "$K8S_DEPLOYMENT" "$image_name" | kubectl --namespace="$K8S_NAMESPACE" apply -f -

        echo "Waiting for deployment to be ready"
        kubectl --namespace="$K8S_NAMESPACE" rollout status deployment "$K8S_DEPLOYMENT" > /dev/null
    else
        k8s_end_test $ret
    fi

    k8s_populate_pods
}

k8s_delete_pod() { # pod
    kubectl --namespace="$K8S_NAMESPACE" delete pod "$POD_B"
}