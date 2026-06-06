About
=====

A 2-node active/passive setup with KeepaliveD for haproxy on RHEL10 (and compatibles)

Role Variables
--------------

See defaults/main.yml, vars/main.yml

Dependencies
------------

- `ansible.posix` collection

Example inventory
-----------------

```ini
ha_haproxy_is_primary=false
ha_haproxy_vip=1.2.3.4
ha_haproxy_vrrp_pass='dummy'

[g_ha_haproxy]
master1.ocp.example.com    ha_haproxy_is_primary=true
master2.ocp.example.com    ha_haproxy_is_primary=false
```
