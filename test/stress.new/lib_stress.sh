# Copyright (c) 2014, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

LIB_STRESS_ERR_COUNT_OFF=50

# ---------------- TASKs to call from lib_stress_task ------------------

# A simple counter task which updates 2 counters.
#
# Exit with an error if the counters get out of sync!
#
lib_stress_task_count() { # dir
    local dir=$1
    if ! [ -d "$dir" ] ; then
        mkdir -p "$dir"
        echo "Counting in $dir"
        echo 0 > "$dir/a"
        echo 0 > "$dir/b"
    fi

    local ca=$(< "$dir/a") cb=$(< "$dir/b")
    [ "$ca" == "$cb" ] || exit $LIB_STRESS_ERR_COUNT_OFF
    c=$((ca + 1))
    echo -n " $c"
    echo "$c" > "$dir/a"
    echo "$c" > "$dir/b"
}

# ---------------- Low Level Locking Test Types ------------------

# Requires: LIB_STRESS_LOCK_CMD and LIB_STRESS_UNLOCK_CMD arrays
# Optional: LIB_STRESS_CLEAN array
lib_stress_task() { # count --restart
    local cnt=$1 i=0

    if [ "$2" = "--restart" -a  -n "$LIB_STRESS_CLEAN" ] ; then
        rm -rf "${LIB_STRESS_CLEAN[@]}"
    fi

    while [ "$i" != "$cnt" ] ; do
        i=$((i + 1))
        while ! "${LIB_STRESS_LOCK_CMD[@]}" ; do : ; done
        "${LIB_STRESS_TASK_CMD[@]}"
        "${LIB_STRESS_UNLOCK_CMD[@]}"
    done
}

# Requires: LIB_STRESS_LOCK_CMD
lib_stress_go_stale() {
    while ! "${LIB_STRESS_LOCK_CMD[@]}" ; do : ; done
}


# ---------------- High Level Locking Test Tasks ------------------

# Requires: LIB_STRESS_LOCK
lib_stress_notask() { # count --restart
    LIB_STRESS_TASK_CMD=(echo -n .)
    LIB_STRESS_CLEAN=("$LIB_STRESS_LOCK")
    lib_stress_task "$@"
    echo
}

# Requires: LIB_STRESS_LOCK & LIB_STRESS_COUNTDIR
lib_stress_count() { # count --restart
    LIB_STRESS_TASK_CMD=(lib_stress_task_count "$LIB_STRESS_COUNTDIR")
    LIB_STRESS_CLEAN=("$LIB_STRESS_COUNTDIR" "$LIB_STRESS_LOCK")
    lib_stress_task "$@"
    echo
}

# ---------------- Test Setup ------------------

# Sets up LIB_STRESS_LOCK_CMD & LIB_STRESS_UNLOCK_CMD
#      from LIB_STRESS_LOCKER and LIB_STRESS_LOCK
lib_stress_setup_id_locker() { # ID
   LIB_STRESS_LOCK_CMD=("${LIB_STRESS_LOCKER[@]}" lock "$LIB_STRESS_LOCK" "$1")
   LIB_STRESS_UNLOCK_CMD=("${LIB_STRESS_LOCKER[@]}" unlock "$LIB_STRESS_LOCK" "$1")
}
