#!/usr/bin/env sh

# Install packages and the OpenBSD system configuration files.
# Restart services and reboot the system as necessary according to the changed files.
# Note that packages and system files are not deleted by this configuration.
# Any packages or files removed from the configuration must be manually removed from the system.

dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

if [ ! -f "$dir/etc/snmpd.conf" ]; then
    echo "The file '$dir/etc/snmpd.conf' does not exist." 1>&2
    echo "Copy '$dir/etc/snmpd.conf.template' to '$dir/etc/snmpd.conf' and edit the file appropriately before running this script." 1>&2
    exit 1
fi

pkg_add fish git tailscale vim--no_x11 || exit 1

cmp -s "$dir/etc/defaultdomain" /etc/defaultdomain
defaultdomain_changed=$?

cmp -s "$dir/etc/dhcp6leased.conf" /etc/dhcp6leased.conf
dhcp6leased_conf_changed=$?

cmp -s "$dir/etc/dhcpd.conf" /etc/dhcpd.conf
dhcpd_conf_changed=$?

hostnames=$(cd "$dir/etc" && ls -1 hostname.*)
i=0
for hostname in $hostnames; do
    cmp -s "$dir/etc/hostname.$hostname" "/etc/hostname.$hostname"
    hostname_changed[i]=$?
    i=$((i+1))
done

cmp -s "$dir/etc/mrouted.conf" /etc/mrouted.conf
mrouted_conf_changed=$?

cmp -s "$dir/etc/myname" /etc/myname
myname_changed=$?

cmp -s "$dir/etc/pf.conf" /etc/pf.conf
pf_conf_changed=$?

# Verify pf.conf before installing it.
if [ $pf_conf_changed -ne 0 ]; then
    if ! pfctl -f "$dir/etc/pf.conf"; then
        echo "Failed to load updated pf.conf." 1>&2
        exit 1
    fi
fi

cmp -s "$dir/etc/rc.conf.local" /etc/rc.conf.local
rc_conf_local_changed=$?

cmp -s "$dir/etc/rad.conf" /etc/rad.conf
rad_conf_changed=$?

# Verify the rad configuration before installing it.
if [ $rad_conf_changed -ne 0 ]; then
    if ! rad -f "$dir/etc/rad.conf" -n; then
        echo "Failed to validate the rad config file: $dir/etc/rad.conf" 1>&2
        exit 1
    fi
fi

sshd_conf_changed=0
sshd_config_d_conf_files=$(cd "$dir/etc/ssh/sshd_config.d/" && ls -1 ./*.conf)
if ! cmp -s "$dir/etc/ssh/sshd_config" /etc/ssh/sshd_config; then
    sshd_conf_changed=1
else
    for sshd_config_d_conf_file in $sshd_config_d_conf_files; do
        if ! cmp -s "$dir/etc/ssh/sshd_config.d/$sshd_config_d_conf_file" "/etc/ssh/sshd_config.d/$sshd_config_d_conf_file"; then
            sshd_conf_changed=1
            break
        fi
    done
fi

if [ $sshd_conf_changed -ne 0 ]; then
    # Combine the sshd_config file with all of the sshd_config.d/*.conf files for validation.
    # The sshd_config will always include the *.conf files from the /etc/ssh/sshd_config.d/ directory.
    tmp_sshd_config=$(mktemp)
    cat "$dir/etc/ssh/sshd_config" "$dir"/etc/ssh/sshd_config.d/*.conf | awk '!/Include \/etc\/ssh\/sshd_config.d\/\*.conf/' - > "$tmp_sshd_config"
    if ! sshd -f "$tmp_sshd_config" -G > /dev/null; then
        echo "Failed to validate the sshd config file: $tmp_sshd_config" 1>&2
        exit 1
    else
        rm -f "$tmp_sshd_config"
    fi
fi

snmpd_conf_changed=0
if ! cmp -s "$dir/etc/snmpd.conf" /etc/snmpd.conf || ! cmp -s "$dir/etc/snmpd.users.conf" /etc/snmpd.users.conf; then
    snmpd_conf_changed=1
fi

# Verify the snmpd configuration before installing it.
if [ $snmpd_conf_changed -ne 0 ]; then
    if ! snmpd -f "$dir/etc/snmpd.conf"; then
        echo "Failed to validate the snmpd config file: $dir/etc/snmpd.conf" 1>&2
        exit 1
    fi
fi

cmp -s "$dir/etc/sysctl.conf" /etc/sysctl.conf
sysctl_conf_changed=$?

unbound_conf_changed=0
if ! cmp -s "$dir/var/unbound/etc/unbound.conf" /var/unbound/etc/unbound.conf; then
    unbound_conf_changed=1
fi

# Verify the unbound configuration before installing it.
if [ $unbound_conf_changed -ne 0 ]; then
    if ! unbound-checkconf "$dir/var/unbound/etc/unbound.conf"; then
        echo "Failed to validate the unbound config file: $dir/var/unbound/etc/unbound.conf" 1>&2
        exit 1
    fi
fi

install -d -g wheel -m 0755 -o root /etc
install -d -g wheel -m 0755 -o root /etc/ssh
install -d -g wheel -m 0755 -o root /etc/ssh/ssh_config.d
install -C -g wheel -m 0644 -o root "$dir/etc/ssh/ssh_config" /etc/ssh/ssh_config
install -C -g wheel -m 0644 -o root "$dir"/etc/ssh/ssh_config.d/*.conf /etc/ssh/ssh_config.d/
install -d -g wheel -m 0755 -o root /etc/ssh/sshd_config.d
install -C -g wheel -m 0644 -o root "$dir/etc/ssh/sshd_config" /etc/ssh/sshd_config
install -C -g wheel -m 0644 -o root "$dir"/etc/ssh/sshd_config.d/*.conf /etc/ssh/sshd_config.d/
install -C -g wheel -m 0644 -o root "$dir/etc/defaultdomain" /etc/
install -C -g wheel -m 0644 -o root "$dir/etc/dhcp6leased.conf" /etc/
install -C -g wheel -m 0644 -o root "$dir/etc/dhcpd.conf" /etc/
install -C -g wheel -m 0600 -o root "$dir/etc/doas.conf" /etc/
install -C -g wheel -m 0640 -o root "$dir"/etc/hostname.* /etc/
install -C -g wheel -m 0644 -o root "$dir/etc/hosts" /etc/
install -C -g wheel -m 0644 -o root "$dir/etc/mrouted.conf" /etc/
install -C -g wheel -m 0644 -o root "$dir/etc/myname" /etc/
install -C -g wheel -m 0600 -o root "$dir/etc/pf.conf" /etc/
install -C -g wheel -m 0644 -o root "$dir/etc/rad.conf" /etc/
install -C -g wheel -m 0644 -o root "$dir/etc/rc.conf.local" /etc/
install -C -g wheel -m 0644 -o root "$dir/etc/resolv.conf.tail" /etc/
install -C -g wheel -m 0644 -o root "$dir/etc/shells" /etc/
install -C -g _snmpd -m 0640 -o root "$dir/etc/snmpd.conf" /etc/
install -C -g _snmpd -m 0640 -o root "$dir/etc/snmpd.users.conf" /etc/
install -C -g wheel -m 0644 -o root "$dir/etc/sysctl.conf" /etc/

install -d -g wheel -m 0755 -o root /var
install -d -g wheel -m 0755 -o root /var/unbound
install -d -g wheel -m 0755 -o root /var/unbound/etc
install -C -g wheel -m 0644 -o root "$dir"/var/unbound/etc/*.conf /var/unbound/etc/

i=0
for hostname in $hostnames; do
    if [ "${hostname_changed[$i]}" -ne 0 ]; then
        if ! sh /etc/netstart "$hostname"; then
            echo "Failed to reload network interface $hostname." 1>&2
            exit 1
        fi
    fi
    i=$((i+1))
done

if [ $pf_conf_changed -ne 0 ]; then
    if ! pfctl -f /etc/pf.conf; then
        echo "Failed to reload pf with updated /etc/pf.conf file." 1>&2
        exit 1
    fi
fi

if [ $dhcp6leased_conf_changed -ne 0 ]; then
    if ! rcctl restart dhcp6leased; then
        echo "Failed to restart the dhcp6leased service." 1>&2
        exit 1
    fi
fi

if [ $dhcpd_conf_changed -ne 0 ]; then
    if ! rcctl restart dhcpd; then
        echo "Failed to restart the dhcpd service." 1>&2
        exit 1
    fi
fi

if [ $mrouted_conf_changed -ne 0 ]; then
    if ! rcctl restart mrouted; then
        echo "Failed to restart the mrouted service." 1>&2
        exit 1
    fi
fi

if [ $rad_conf_changed -ne 0 ]; then
    if ! rad -f "/etc/snmpd.conf" -n; then
        echo "Failed to validate the rad config file: /etc/rad.conf" 1>&2
        exit 1
    fi
    if ! rcctl restart rad; then
        echo "Failed to restart the rad service." 1>&2
        exit 1
    fi
fi

if [ $sshd_conf_changed -ne 0 ]; then
    if ! sshd -f "/etc/ssh/sshd_config" -t; then
        echo "Failed to validate the sshd config file: /etc/ssh/sshd_config" 1>&2
        exit 1
    fi
    if ! rcctl restart sshd; then
        echo "Failed to restart the sshd service." 1>&2
        exit 1
    fi
fi

if [ $snmpd_conf_changed -ne 0 ]; then
    if ! snmpd -f /etc/snmpd.conf; then
        echo "Failed to validate the snmpd config file: /etc/snmpd.conf" 1>&2
        exit 1
    fi
    if ! rcctl restart snmpd; then
        echo "Failed to restart the snmpd service." 1>&2
        exit 1
    fi
fi

if [ $unbound_conf_changed -ne 0 ]; then
    if ! unbound-checkconf "/var/unbound/etc/unbound.conf"; then
        echo "Failed to validate the unbound config file: /var/unbound/etc/unbound.conf" 1>&2
        exit 1
    fi
    if ! rcctl restart unbound; then
        echo "Failed to restart the unbound service." 1>&2
        exit 1
    fi
fi

if [ $defaultdomain_changed -ne 0 ] || [ $myname_changed -ne 0 ] || [ $rc_conf_local_changed -ne 0 ] || [ $sysctl_conf_changed -ne 0 ]; then
    echo "The system will reboot now to complete installation." 1>&2
    reboot
fi
