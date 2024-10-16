#!/usr/bin/env sh

# Validate config files.

dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

if [ ! -f "$dir/etc/snmpd.conf" ]; then
    echo "The file '$dir/etc/snmpd.conf' does not exist." 1>&2
    echo "Copy '$dir/etc/snmpd.conf.template' to '$dir/etc/snmpd.conf' and edit the file appropriately before running this script." 1>&2
    exit 1
fi

if ! pfctl -f "$dir/etc/pf.conf"; then
    echo "Failed to load updated pf.conf." 1>&2
    exit 1
fi

if ! rad -f "$dir/etc/rad.conf" -n; then
    echo "Failed to validate the rad config file: $dir/etc/rad.conf" 1>&2
    exit 1
fi

# Combine the sshd_config file with all of the sshd_config.d/*.conf files for validation.
# The sshd_config will always include the *.conf files from the /etc/ssh/sshd_config.d/ directory.
tmp_sshd_config=$(mktemp)
cat "$dir/etc/ssh/sshd_config" "$dir"/etc/ssh/sshd_config.d/*.conf | awk '!/Include \/etc\/ssh\/sshd_config.d\/\*.conf/' > "$tmp_sshd_config"
if ! sshd -f "$tmp_sshd_config" -G > /dev/null; then
    echo "Failed to validate the sshd config file: $tmp_sshd_config" 1>&2
    exit 1
else
    rm -f "$tmp_sshd_config"
fi

if ! snmpd -f "$dir/etc/snmpd.conf"; then
    echo "Failed to validate the snmpd config file: $dir/etc/snmpd.conf" 1>&2
    exit 1
fi

if ! unbound-checkconf "$dir/var/unbound/etc/unbound.conf"; then
    echo "Failed to validate the unbound config file: $dir/var/unbound/etc/unbound.conf" 1>&2
    exit 1
fi
