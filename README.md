About
=====

A 2-node active/passive setup with Keepalived for HAProxy

Supported OS: RHEL 10, Ubuntu 26.04

Requirements
------------

Collections:

- `ansible.utils` - template check for ip address
- `ansible.posix` - firewalld, seboolean, sysctl
- `community.general` - ufw


Example inventory
-----------------

```ini
[g_ha_haproxy]
mylb01.example.com
mylb02.example.com
```

Example playbook
----------------

The role takes one structured variable, `ha_haproxy_cfg`,
passed as a role var. Every entry defines one VIP (one VRRP instance)
with the HAProxy listen blocks served from it.

```yaml
- hosts: g_ha_haproxy
  vars_files:
    - "vault.yml"
  roles:
    - role: ha_haproxy
      vars:
        ha_haproxy_cfg:
          # description of this ip/domain
          - name: OpenShift Kubernetes API + Machine Config Server
            vip_ip: 192.168.1.1
            vip_domain: api.mycluster.example.com
            # keepalived auth is 8 chars max
            vrrp_password: "{{ my_lb_vip1_vrrp_pw }}"
            # inventory hostname of the host that gets VRRP MASTER
            keepalived_primary_host: mylb01.example.com
            haproxy_listen:
              - name: ocp_kubernetes_api
                use_template: openshift_kubernetes_api.j2
                bind_to_ip: false
                listen_port: 6443
                backend_server_pool_members: [
                  { enabled: true, name: bootstrap, host: bootstrap.ocp.example.com, port: 6443 },
                  { enabled: true, name: master1,   host: master1.ocp.example.com,   port: 6443 },
                  { enabled: true, name: master2,   host: master2.ocp.example.com,   port: 6443 },
                  { enabled: true, name: master3,   host: master3.ocp.example.com,   port: 6443 }
                ]
              - name: ocp_machine_config_server
                use_template: openshift_machine_config_server.j2
                bind_to_ip: false
                listen_port: 22623
                backend_server_pool_members: [
                  { enabled: true, name: bootstrap, host: bootstrap.ocp.example.com, port: 22623 },
                  { enabled: true, name: master1,   host: master1.ocp.example.com,   port: 22623 },
                  { enabled: true, name: master2,   host: master2.ocp.example.com,   port: 22623 },
                  { enabled: true, name: master3,   host: master3.ocp.example.com,   port: 22623 }
                ]
          - name: OpenShift Ingress (HTTP/S)
            vip_ip: 192.168.1.2
            vip_domain: lb-vip-ingress.mycluster.example.com
            vrrp_password:  "{{ my_lb_vip2_vrrp_pw }}"
            keepalived_primary_host: mylb01.example.com
            haproxy_listen:
              - name: ocp_http_ingress
                use_template: openshift_http_ingress.j2
                bind_to_ip: false
                listen_port: 80
                backend_server_pool_members: [
                  { enabled: true, name: bootstrap, host: bootstrap.ocp.example.com, port: 80 },
                  { enabled: true, name: master1,   host: master1.ocp.example.com,   port: 80 },
                  { enabled: true, name: master2,   host: master2.ocp.example.com,   port: 80 },
                  { enabled: true, name: master3,   host: master3.ocp.example.com,   port: 80 }
                ]
              - name: ocp_https_ingress
                use_template: openshift_https_ingress.j2
                bind_to_ip: false
                listen_port: 443
                backend_server_pool_members: [
                  { enabled: true, name: bootstrap, host: bootstrap.ocp.example.com, port: 443 },
                  { enabled: true, name: master1,   host: master1.ocp.example.com,   port: 443 },
                  { enabled: true, name: master2,   host: master2.ocp.example.com,   port: 443 },
                  { enabled: true, name: master3,   host: master3.ocp.example.com,   port: 443 }
                ]
        # stats UI
        # To bind to all interfaces, set address to "", and set a password
        ha_haproxy_stat_bind_address: 127.0.0.1
        ha_haproxy_stat_port: 1936
        ha_haproxy_stat_uri: /stats
        ha_haproxy_stat_user: stats
        # empty (default) leaves the stats UI unauthenticated;
        # set it to enable HTTP Basic auth
        ha_haproxy_stat_password: "{{ my_lb_stats_pw }}"
```

Put a secret password to  `vault_pass.txt`, then create your vault
with `ansible-vault create --vault-pass-file ./vault_pass.txt vault.yml`

```yaml
my_lb_vip1_vrrp_pw: "secret1"
my_lb_vip2_vrrp_pw: "secret2"
my_lb_stats_pw: "secret3"
```


Notes
-----

- **General config**
  - `ha_haproxy_cfg` is required; the play fails its validation asserts without it
- The `[g_ha_haproxy]` inventory host group is required - `keepalived.conf.j2` iterates it to
  build the `unicast_peer` list, so the play fails without it.
- **KeepaLiveD settings**
  - `keepalived_primary_host` must be a member of `[g_ha_haproxy]`
  - `vrrp_password` must be non-empty, and set for every VIP entry
- **HAProxy settings**
  - `use_template` picks the rendering template from `templates/conf.d/`
  - `bind_to_ip: false` binds the HAProxy FRONTEND listen to `vip_domain`, `true` to `vip_ip`
  - any BACKEND member, whose `host` is a domain gets `resolvers haproxy_dns init-addr none` automatically;
    the resolver will be the DNS servers set on the host running HAProxy
  - `/root/haproxy_stat.sh` queries the HAProxy stats socket over `nc`; run it as
  root.
  - stats UI on `:1936`: set `ha_haproxy_stat_password` to enable HTTP Basic
    auth (user from `ha_haproxy_stat_user`, default `stats`); empty (default)
    leaves it unauthenticated. When set, `haproxy.cfg` deploys as `0600`
    instead of `0644`, since it then carries the password in plain text.
