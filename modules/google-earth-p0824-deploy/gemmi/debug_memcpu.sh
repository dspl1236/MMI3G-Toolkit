while [[ 1 -eq 1 ]]; do
    if [[ $(echo $(showmem -P | grep gemmi) | sed -r 's/^([^.]+).*$/\1/; s/^[^0-9]*([0-9]+).*$/\1/') -ge 83886080 ]]; then
        #print Writing DEBUG_MEM_CPU_TRIGGER
        echo DEBUG_MEM_CPU_TRIGGER > /tmp/live_cmds
    fi
    sleep 60
done
