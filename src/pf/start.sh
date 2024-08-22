#!/bin/bash

cd /home/pf

# stop services created by runsv and propagate SIGINT, SIGTERM to child jobs
sv_stop() {
    echo "$(date -uIns) - Stopping all runsv services"
    for s in $(ls -d ./runit/*); do
        sv stop $s
    done
}

# register SIGINT, SIGTERM handler
trap sv_stop SIGINT SIGTERM

# start services in background and wait all child jobs
runsvdir ./runit &
wait
