#!/bin/bash

if [[ -z $1 ]]; then
    echo "Requires one command line argument."
    exit
fi

source /etc/os-release

case "$ID" in
    debian)
        dpkg -S "$(command -v $1)"
    ;;
    fedora)
        rpm -qf "$(command -v $1)"
    ;;
    arch)
        pacman -Qo "$(command -v $1)"
    ;;
esac