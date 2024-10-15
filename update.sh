#!/usr/bin/env sh

if syspatch -c | read -r REPLY; then
    syspatch || exit 1
fi

pkg_add -u || exit 1
sysupgrade || exit 1
