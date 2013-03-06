#!/usr/bin/env bash

adb devices 2>/dev/null | while read line; do
    if [[ -n $line ]] && [[ $(echo $line | awk '{print $2}') == device ]]; then
        device=$(echo $line | awk '{print $1}')
        echo -n "$device "
    fi
done

