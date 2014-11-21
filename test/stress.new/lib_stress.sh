# Copyright (c) 2014, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause

LIB_STRESS_ERR_COUNT_OFF=50

# ---------------- TASKs to call from lib_stress_task ------------------

# A simple counter task which updates 2 counters.
#
# Exit with an error if the counters get out of sync!
#
# Optional: LIB_STRESS_COUNT_SLEEP
lib_stress_task_count() { # dir [subdir]
    local dir=$1/$2 slot=$2
    [ -n "$slot" ] && slot=${slot}:
    if ! [ -d "$dir" ] ; then
        mkdir -p "$dir"
        echo "Counting in $dir"
        echo 0 > "$dir/a"
        echo 0 > "$dir/b"
    fi

    local ca=$(< "$dir/a")
    [ -n "$LIB_STRESS_COUNT_SLEEP" ] && sleep "$LIB_STRESS_COUNT_SLEEP"
    local cb=$(< "$dir/b")

    [ "$ca" == "$cb" ] || exit $LIB_STRESS_ERR_COUNT_OFF
    c=$((ca + 1))
    echo -n " $slot$c"

    # By reversing the write order, we accentuate the sleep skew
    echo "$c" > "$dir/b"
    [ -n "$LIB_STRESS_COUNT_SLEEP" ] && sleep "$LIB_STRESS_COUNT_SLEEP"
    echo "$c" > "$dir/a"
}

# ---------------- Low Level Locking Test Types ------------------

# Requires: LIB_STRESS_LOCK_CMD and LIB_STRESS_UNLOCK_CMD arrays
# Optional: LIB_STRESS_CLEAN array
lib_stress_lock_task() { # count --restart
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
lib_stress_lock_go_stale() {
    while ! "${LIB_STRESS_LOCK_CMD[@]}" ; do : ; done
}

# ---------------- Low Level Sempahore Test Types ------------------

# Requires: LIB_STRESS_ACQUIRE_CMD, LIB_STRESS_SLOT_CMD,
#  and LIB_STRESS_RELEASE_CMD arrays
# Optional: LIB_STRESS_CLEAN array
lib_stress_semaphore_task() { # count --restart
    local cnt=$1 i=0 slot

    if [ "$2" = "--restart" -a  -n "$LIB_STRESS_CLEAN" ] ; then
        rm -rf "${LIB_STRESS_CLEAN[@]}"
    fi

    while [ "$i" != "$cnt" ] ; do
        i=$((i + 1))
        while ! "${LIB_STRESS_ACQUIRE_CMD[@]}" ; do : ; done
        slot=$("${LIB_STRESS_SLOT_CMD[@]}")
        "${LIB_STRESS_TASK_CMD[@]}" "$slot"
        "${LIB_STRESS_RELEASE_CMD[@]}"
    done
}

# Requires: LIB_STRESS_ACQUIRE_CMD
lib_stress_semaphore_go_stale() {
    while ! "${LIB_STRESS_ACQUIRE_CMD[@]}" ; do : ; done
}

# ---------------- High Level Locking Test Tasks ------------------

# Requires: LIB_STRESS_TYPE, LIB_STRESS_LOCK
lib_stress_notask() { # count --restart
    LIB_STRESS_TASK_CMD=(echo -n .)
    LIB_STRESS_CLEAN=("$LIB_STRESS_LOCK")
    lib_stress_${LIB_STRESS_TYPE}_task "$@"
    echo
}

# Requires: LIB_STRESS_TYPE, LIB_STRESS_LOCK, and LIB_STRESS_COUNTDIR
lib_stress_count() { # count --restart
    LIB_STRESS_TASK_CMD=(lib_stress_task_count "$LIB_STRESS_COUNTDIR")
    LIB_STRESS_CLEAN=("$LIB_STRESS_COUNTDIR" "$LIB_STRESS_LOCK")
    lib_stress_${LIB_STRESS_TYPE}_task "$@"
    echo
}

# ---------------- Test Setup ------------------

# Sets up LIB_STRESS_LOCK_CMD & LIB_STRESS_UNLOCK_CMD
#      from LIB_STRESS_LOCKER and LIB_STRESS_LOCK
lib_stress_setup_id_locker() { # ID
   LIB_STRESS_LOCK_CMD=("${LIB_STRESS_LOCKER[@]}" lock "$LIB_STRESS_LOCK" "$1")
   LIB_STRESS_UNLOCK_CMD=("${LIB_STRESS_LOCKER[@]}" unlock "$LIB_STRESS_LOCK" "$1")
   LIB_STRESS_TYPE=lock
}

# Sets up LIB_STRESS_ACQUIRE_CMD, LIB_STRESS_SLOT_CMD, and LIB_STRESS_RELEASE_CMD
#      from LIB_STRESS_SEMAPHORE and LIB_STRESS_LOCK
lib_stress_setup_id_semaphore() { # MAX ID
   local max=$1 id=$2
   LIB_STRESS_ACQUIRE_CMD=("${LIB_STRESS_SEMAPHORE[@]}" acquire "$LIB_STRESS_LOCK" "$max" "$id")
   LIB_STRESS_SLOT_CMD=("${LIB_STRESS_SEMAPHORE[@]}" slot "$LIB_STRESS_LOCK" "$id")
   LIB_STRESS_RELEASE_CMD=("${LIB_STRESS_SEMAPHORE[@]}" release "$LIB_STRESS_LOCK" "$id")
   LIB_STRESS_TYPE=semaphore
}
