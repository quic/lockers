#!/usr/bin/env bash

readlink --canonicalize / &> /dev/null || readlink() { greadlink "$@" ; } # for MacOS
MYDIR=$(dirname -- "$(readlink -f -- "$0")")
LOCKERS_YAML="$MYDIR/lockers.yaml"

check_prerequisite() {
    local error_msg
    docker --version >> /dev/null || error_msg="\nERROR: docker is not installed"
    docker-compose --version >> /dev/null || \
        error_msg+="\nERROR: docker-compose is not installed"
    if [ -n "$error_msg" ] ; then
        echo -e "$error_msg"
        exit 1
    fi
}

run_lockers_test() {
    local project_name="lockers_test_$$"
    compose_args=(--project-name "$project_name" -f "$LOCKERS_YAML")
    docker-compose "${compose_args[@]}" build ; ret=$?
    if [ 0 -eq $ret ] ; then
        docker-compose "${compose_args[@]}" up -d
        local runtests_container=$(docker ps | grep "$project_name"_run_tests | awk '{print $1}')
        docker exec --user=locker_user "$runtests_container" \
            bash -c '/start.sh' || ret=$?
    fi
    docker-compose "${compose_args[@]}" down -v --rmi all --remove-orphans
    return "$ret"
}

check_prerequisite
run_lockers_test || exit 1
exit 0