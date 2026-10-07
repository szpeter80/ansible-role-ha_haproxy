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

- [ ] TODO 8. Full verification run: `ansible-lint` + `yamllint` + playbook run against RHEL and Ubuntu targets.

- [ ] TODO 9. Fix inconsistent template `src` path in `tasks/main.yml` (`templates/keepalived.conf.j2`) to match
      `haproxy.cfg.j2`. Cosmetic only — Ansible's `template` module searches both `<role>/templates/` and `<role>/`, so
      both forms resolve to the same file. An earlier review called this fragile, which overstated it.

- [ ] TODO 10. Ensure `/etc/keepalived` exists before deploying `keepalived.conf` (add an `ansible.builtin.file` task
      with `state: directory`). Today it only works because the RHEL package creates the directory.

- [ ] TODO 11. Decouple VIPs from HAProxy binds: `haproxy.cfg.j2` hardcodes `bind
      lb-vip.ocp.example.com:{6443,22623,80,443}` while `ha_haproxy_vip_api` / `ha_haproxy_vip_ingress` are consumed
      only by `keepalived.conf.j2`.

- [ ] TODO 13. Add `{% else %}` to the `unicast_peer` loop in `keepalived.conf.j2` so a `ansible_nodename` /
      inventory-hostname mismatch fails loudly instead of emitting blank lines.

- [ ] TODO 16. Autenticate the stats listener on `:1936` (or at minimum bind it to the management interface). It is
      currently opened in `public` via `ha_haproxy_fw_ports` with no credentials, so reachable from anywhere, not just
      the local host.

- [ ] TODO 17. Resolve the dead `/etc/haproxy/conf.d`: it is created by `tasks/main.yml` but nothing writes into it, and
      `haproxy.cfg.j2` has no `includedir /etc/haproxy/conf.d` line — every proxy is hardcoded inline in the one
      template. Either add `includedir` (which makes TODO 5 far cleaner: per-backend drop-ins instead of a monolith) or
      drop the task. Highest-leverage item on this list — decide it before the Ubuntu port, since it decides whether
      that port is a patch or a refactor.

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
      Target-side checks (`netcat-openbsd` naming, `keepalived` postinst) are carried by TODO 8.

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

- [ ] Keepalived `unicast_peer` loop has no `else` (tracked as TODO 13).

## Execution log

- (none)
