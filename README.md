About
=====

A 2-node active/passive setup with Keepalived for HAProxy

Supported OS: RHEL 10, Ubuntu 26.04

Requirements
------------

Collections:

- `ansible.posix` - firewalld, seboolean, sysctl
- `community.general` - ufw

Example inventory
-----------------

```ini
[g_ha_haproxy]
lb01.ocp.example.com
lb02.ocp.example.com

[g_ha_haproxy:vars]
ha_haproxy_vip_api=1.2.3.4
ha_haproxy_vip_ingress=1.2.3.5
ha_haproxy_vrrp_pass='dummy'

# Exactly one host must be primary. It becomes VRRP MASTER with priority 101;
# every other host is BACKUP at 100.
lb01.ocp.example.com    ha_haproxy_is_primary=true
lb02.ocp.example.com    ha_haproxy_is_primary=false
```

Notes
-----

- The `[g_ha_haproxy]` group is required — `keepalived.conf.j2` iterates it to
  build the `unicast_peer` list, so the play fails without it.
- `/root/haproxy_stat.sh` queries the HAProxy stats socket over `nc`; run it as
  root.