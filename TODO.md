# TODO — ha_haproxy Ubuntu 26.04+ support

Status legend: `TODO` | `WIP` | `DONE`

Items are grouped by status, unsolved first. An item keeps its original number
so it stays traceable to wherever it was raised.

## Unsolved

- [ ] TODO 4. Verify `ssl-default-bind-ciphers PROFILE=SYSTEM` works with Ubuntu's OpenSSL 3 build; adjust template if
      not.

- [ ] TODO 5. Refactor hardcoded `*.ocp.example.com` backends in `templates/haproxy.cfg.j2` into role variables (needed
      for real multi-distro testing). Overlaps TODO 11 — keep in one place.

- [ ] TODO 7. Add Ubuntu test inventory/playbook under `tests/`. The current `tests/test.yml` targets `localhost` with
      no variables set, so `ha_haproxy_vip_api` renders empty and `groups['g_ha_haproxy']` fails outright.

- [ ] TODO 99. Full verification run: `ansible-lint` + `yamllint` + playbook run against RHEL and Ubuntu targets.

- [ ] TODO 11. Decouple VIPs from HAProxy binds: `haproxy.cfg.j2` hardcodes `bind
      lb-vip.ocp.example.com:{6443,22623,80,443}` while `ha_haproxy_vip_api` / `ha_haproxy_vip_ingress` are consumed
      only by `keepalived.conf.j2`.

- [ ] TODO 16. Autenticate the stats listener on `:1936` (or at minimum bind it to the management interface). It is
      currently opened in `public` via `ha_haproxy_fw_ports` with no credentials, so reachable from anywhere, not just
      the local host.

- [ ] TODO 18. Fix distro-sensitive absolute paths hardcoded in templates:

      - `haproxy.cfg.j2:9` `chroot /var/lib/haproxy`
      - `haproxy.cfg.j2:10` `pidfile /var/run/haproxy.pid` — Debian/Ubuntu use `/run/haproxy.pid`; same directory today,
        but `/var/run` is a compat symlink and writing into it is deprecated
      - `keepalived.conf.j2:5` `/usr/bin/killall` — `killall` ships in `psmisc` on Debian, not installed by default on
        minimal Ubuntu. This one fails silently: VRRP priority stops adjusting and failover degrades with no error.
        Promote to role variables so they can differ per `os_family`.

- [ ] TODO 21. Open VRRP in the firewall. Keepalived does not do this itself — `vrrp_iptables`/`vrrp_nftables` exist
      only for `no_accept` mode and VMAC IGMP handling, nothing opens a hole for VRRP itself. VRRP is IP protocol 112,
      not a port, so `ha_haproxy_fw_ports` (a list of `{port, proto}`) cannot carry it and the two backends need
      different
      syntax: firewalld wants a rich rule `rule protocol value="vrrp" accept`, while `community.general.ufw` accepts
      `proto: vrrp` (supported since community.general 10.3.0; 13.4.0 installed here, but the emitted rule is
      unverified). Failure mode is silent: adverts are dropped, no keepalived error, and failover quietly does not
      work. Same class as the `killall` problem in TODO 18. Consider a separate `ha_haproxy_fw_protocols` variable
      handled per family in the two firewall files.

## Done

- [x] DONE 9. Consistent template `src` paths (`34ee72f`) — both template tasks now use the `templates/` prefix. The
      direction was chosen deliberately: the explicit `templates/haproxy.cfg.j2` form was kept and the bare
      `haproxy.cfg.j2` updated to match it, so the filename stays visible in the task. Zero behaviour change —
      `template` searches both `<role>/templates/` and `<role>/`, so both forms resolve to the same file. An earlier
      review called the inconsistency fragile, which overstated it.

- [x] DONE 13. Fix the `unicast_peer` loop in `keepalived.conf.j2` (`4c4a443`) — peers are now matched by comparing
      `hostvars[host]['ansible_default_ipv4']['address']` against this host's `ansible_default_ipv4.address`, so
      `ansible_nodename` and inventory naming are out of the picture and a naming mismatch cannot produce blank lines.
      Chose IP matching over the `{% else %}` fail-loud variant: the "fault" was only a naming quirk, not a real error.
      Verified by rendering the template against three scenarios (nodename mismatched, nodename matching, single node);
      self is excluded in all three. Kept the stray blank line from the Jinja comment rather than fight whitespace
      control that conflicts across the tags.

- [x] DONE 10. Guard the keepalived config dir (`9d55918`) — a `stat` plus `assert` before the template task, failing
      with "does not exist" rather than a raw template error. Checked, not created: the role does not paper over a
      broken package install.

- [x] DONE 17. Wire up the dead `/etc/haproxy/conf.d` (`01040ee`) — `haproxy.cfg.j2` now ends with
      `includedir /etc/haproxy/conf.d` (after `defaults`, since includedir expands in place) and the four inline proxies
      moved to `templates/conf.d/{10-k8s-api,20-machine-config,30-http-ingress,40-https-ingress}.j2`, deployed in a
      loop over the new `ha_haproxy_confd` list. Co-existence model by decision: the role writes only its own files and
      leaves anything else in that directory alone, because content is expected to land there outside Ansible. Verified
      the old inline proxy text and the new drop-ins are line-for-line identical apart from one rewrapped comment, so
      the rendered config is functionally unchanged. CAVEAT: this is a breaking change on redeploy — if the drop-ins
      land while `haproxy.cfg` still holds the old inline definitions, HAProxy sees duplicate frontends and refuses to
      start. Run with `--check` on a live node first.

- [x] DONE 15. Galaxy metadata and collection declaration — `meta/main.yml` scaffold replaced in `6115206` (author,
      MIT, `min_ansible_version "2.15"` quoted since unquoted 2.1 parsed as a float, platforms, galaxy_tags), clearing
      all 14 lint `schema`/`meta-incorrect` findings. Collection declaration added in `52a92e2`:
      `collections/requirements.yml` listing `ansible.posix` and `community.general`, chosen over
      `meta/main.yml` `dependencies:` because a role dependency triggers a Galaxy fetch during the play, which fails
      on an air-gapped controller. Verified the declared set matches actual FQCN usage in `tasks/` and
      `handlers/` exactly, in both directions. `dependencies: []` kept with a comment explaining why.

- [x] DONE 6 + 14. README rewrite (`2bd5113`) — documented `ansible_os_family` as the pivot with a per-family
      support table (packages and firewall backend), replaced the stale `ha_haproxy_vip` example with
      `ha_haproxy_vip_api` / `ha_haproxy_vip_ingress` under `[g_ha_haproxy:vars]`, documented that
      `ha_haproxy_is_primary` is true on exactly one host, added `community.general` to the collection list, and added
      notes on the mandatory `[g_ha_haproxy]` group, the two VRRP instances, the 8-char `auth_pass` cap, and that VRRP
      is not covered by `ha_haproxy_fw_ports`. Verified every var named in the README exists in `defaults/` or `vars/`.
      These two items overlapped and were closed together.

- [x] DONE 3. Firewall branch (`78b5b1b`) — the single `ansible.posix.firewalld` task is now
      `include_tasks: "firewall-{{ ansible_os_family }}.yml"`. RedHat keeps firewalld; Debian never installs it, and
      uses `community.general.ufw` only when `ufw.service` is present and running/enabled (via `service_facts`),
      otherwise reports the skip. `ha_haproxy_fw_ports` became structured `{port, proto}` so neither backend parses a
      protocol out of a string — firewalld rejoins them as `{{ item.port }}/{{ item.proto }}`. No VRRP rule; that is
      TODO 21. UNVERIFIED against any host.

- [x] DONE 1. OS-conditional package install (`af05dd3`) — the install branches per `os_family` via
      `include_tasks` on `pkg-install-<Family>.yml`, with per-family package tables in `vars/main.yml` (`nc` on RedHat,
      `netcat-openbsd` on Debian, both adding `rsyslog`), plus a first-task assert that the family is in
      `ha_haproxy_supported_os_families`. Closed as code-complete: no Debian target is available to verify against.
      Target-side checks (`netcat-openbsd` naming, `keepalived` postinst) are carried by TODO 99.

- [x] DONE 2. Gate SELinux tasks (`a534357`) — added derived var `ha_haproxy_selinux_enabled` in `defaults/main.yml`
      (`ansible_selinux is defined and ansible_selinux.status == 'enabled'`) and applied it to all five tasks
      (seboolean, .te, checkmodule, semodule_package, semodule). The three compile/load tasks needed that condition
      added on top of their existing `rsyslogd_selinux_policy.changed`, since that register is undefined when the copy
      is skipped. Debian is a true skip, not an alternative path. UNVERIFIED against a Debian target.

- [x] DONE 12. Deploy `files/haproxy_stat.sh` (`bd256f8`) — installed to `/root/haproxy_stat.sh`, mode `0755`, alongside
      the haproxy config deploy.

- [x] DONE 19. Settle the `haproxy_stat.sh` destination — `/root`, chosen to match the existing
      `/root/rsyslog-haproxy.te` precedent (admin helper, not service config) and to keep it off any PATH. Runs as root,
      required to read `/var/lib/haproxy/stats`. `nc` declared in `vars/main.yml`.

- [x] RETRACTED 20. ~~Create the `haproxy` user/group in the role~~ — NOT NEEDED. An earlier review claimed Ubuntu's
      haproxy package does not create the account, leaving `haproxy.cfg.j2` without one. That was wrong. Verified:
      Debian/Ubuntu `haproxy.postinst` runs `addgroup --gid 99 --system haproxy` + `adduser --uid 99 --home
      /var/lib/haproxy`, creates `/var/lib/haproxy`, and chowns it to `haproxy:haproxy`. Same account name on both
      distros. Residual risk only: uid/gid 99 is pinned, so the package fails to configure if 99 is taken (Debian bug
      #939470). Not a role defect.

## Known gaps (out of scope unless requested)

- [ ] Logrotate coverage for custom `ha_haproxy_logfile`.

- [ ] VRRP `auth_pass` is capped at 8 characters by the protocol, so `ha_haproxy_vrrp_pass` is silently truncated above
      that.

## Execution log

- (none)
