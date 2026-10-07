About
=====

A 2-node active/passive setup with Keepalived for HAProxy, fronting an
OpenShift Compact Cluster.

Supported platforms:

| os_family | Packages via | Firewall via                                |
| --------- | ------------ | -------------------------------------------- |
| RedHat    | `dnf`        | `ansible.posix.firewalld`                    |
| Debian    | `apt`        | `community.general.ufw`, if ufw is active    |

`ansible_os_family` is the pivot for the whole role: it selects the package
manager and the firewall backend. A first-task assert rejects any family
outside `ha_haproxy_supported_os_families` (see `vars/main.yml`).

Role Variables
--------------

See `defaults/main.yml` (caller-facing) and `vars/main.yml` (role-owned: the
per-family package tables, not intended to be overridden).

Requirements
------------

Collections:

- `ansible.posix` — firewalld, seboolean, sysctl
- `community.general` — ufw

SELinux tasks are gated on `ha_haproxy_selinux_enabled`, which is derived from
`ansible_selinux.status`. On the Debian family they are skipped: there is no
SELinux, and rsyslog can write the socket under `/var/lib/haproxy` unconfined.

Example inventory
-----------------

```ini
[g_ha_haproxy]
master1.ocp.example.com
master2.ocp.example.com

[g_ha_haproxy:vars]
ha_haproxy_vip_api=1.2.3.4
ha_haproxy_vip_ingress=1.2.3.5
ha_haproxy_vrrp_pass='dummy'

# Exactly one host must be primary. It becomes VRRP MASTER with priority 101;
# every other host is BACKUP at 100.
master1.ocp.example.com    ha_haproxy_is_primary=true
master2.ocp.example.com    ha_haproxy_is_primary=false
```

Notes
-----

- The `[g_ha_haproxy]` group is required — `keepalived.conf.j2` iterates it to
  build the `unicast_peer` list, so the play fails without it.
- Two VIPs, one per VRRP instance: `ha_haproxy_vip_api` (instance `VI_1`) and
  `ha_haproxy_vip_ingress` (instance `VI_2`).
- VRRP `auth_pass` is capped at 8 characters by the protocol; anything longer is
  silently truncated.
- `ha_haproxy_fw_ports` is a list of `{port, proto}` mappings. VRRP is not
  covered — it is IP protocol 112, not a port.
- `/root/haproxy_stat.sh` queries the HAProxy stats socket over `nc`; run it as
  root.