# Copyright (c) 2013, Qualcomm Innovation Center, Inc. All rights reserved.
# SPDX-License-Identifier: BSD-3-Clause
#
# A bash library of locker debugging
#

q() { "$@" 2>/dev/null ; } # execute a cmd and quiet the stderr

debug_date() { # > date | nothing
   [ "$DEBUG" = "DEBUG" -o "$DEBUG" = "INFO" ] && echo "$(date +'%F %T %N') "
}
debug_stderr() { echo "$(debug_date)$@" >&2 ; } # message >&2 [date] message

debug() { [ "$DEBUG" = "DEBUG" ] && debug_stderr "$@" ; }
info() { debug "$@" ; [ "$DEBUG" = "INFO" ] && debug_stderr "$@" ; }
error() { debug_stderr "Error - $1" ; exit $2 ; }

args() { # action needed optional [args]...
    local func=$1 needed=$2 optional=$3 n s min=0 supplied=0 ; shift 3
    for n in $needed ; do  min=$((min+1)) ;  done
    for s in "$@" ; do supplied=$((supplied +1)) ; done

    [ $supplied -ge $min ] && return
    usage "'$func' takes <$needed> [$optional], given ($*)"
}
