#!/bin/bash

ssh-keygen -t rsa -f "$USER_HOME"/.ssh/id_rsa -q -N ""
cat "$USER_HOME"/.ssh/id_rsa.pub > "$USER_HOME"/.ssh/authorized_keys
chmod 700 -R "$USER_HOME"/.ssh

cp -r /lockers "$USER_HOME"/
"$USER_HOME"/lockers/test/package.sh

exit $?