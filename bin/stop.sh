#!/bin/zsh

[[ -d /web/stormy ]] && cd /web/stormy

if [[ -r pid ]]; then

    PID=$(cat pid)
    RETRIES=3

    while [[ $RETRIES -gt 0 ]] && ps ax | grep "${PID}[ ]" >/dev/null; do
    	kill $PID
    	sleep 1
    	RETRIES=$((RETRIES - 1))
    done

    if ps ax | grep "${PID}[ ]" >/dev/null; then
        kill -9 $PID
        sleep 1
    fi

    rm pid
fi
