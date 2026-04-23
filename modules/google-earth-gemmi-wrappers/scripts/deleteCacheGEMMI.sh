#!/bin/ksh

if [ -d /mnt/img-cache/gemmi ]; then
    echo "Delete Cache GEMMI"
    rm -rf /mnt/img-cache/gemmi
    echo "done."
else
    echo "Cache does not exist!"
    echo "doing nothing."
fi
