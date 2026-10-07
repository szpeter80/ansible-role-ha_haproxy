# TODO — ha_haproxy Ubuntu 26.04+ support

Status legend: `TODO` | `WIP` | `DONE`

Items are grouped by status, unsolved first. A DONE entry keeps its original
number so it stays traceable to the review that raised it.

## Unsolved

### Ubuntu porting

- [ ] TODO 1. OS-conditional package install. Partly done — the install now
      branches per `os_family` via `include_tasks` on
      `pkg-install-<Family>.yml` (`af05dd3`), with per-family package tables
      in `vars/main.yml`. Still to verify against a real Debian target:
      `netcat-openbsd` naming, and `keepalived` postinst behaviour.
- [ ] TODO 3. Firewall branch: install/enable firewalld on Debian family,
      or switch to `ufw`. Now the first RHEL-only task in the play after
      package install.
- [ ] TODO 4. Verify `ssl-default-bind-ciphers PROFILE=SYSTEM` works with
      Ubuntu's OpenSSL 3 build; adjust template if not.
- [ ] TODO 5. Refactor hardcoded `*.ocp.example.com` backends in
      `templates/haproxy.cfg.j2` into role variables (needed for real
      multi-distro testing). Overlaps TODO 11 — keep in one place.
- [ ] TODO 6. Update README for Ubuntu support. (`meta/main.yml` side of this
      item is done under TODO 15.)
- [ ] TODO 7. Add Ubuntu test inventory/playbook under `tests/`. The
      current `tests/test.yml` targets `localhost` with no variables set,
      so `ha_haproxy_vip_api` renders empty and `groups['g_ha_haproxy']`
      fails outright.
- [ ] TODO 8. Full verification run: `ansible-lint` + `yamllint` +
      playbook run against RHEL and Ubuntu targets.

### Findings from code review (2026-10-07)

- [ ] TODO 9. Fix inconsistent template `src` path in `tasks/main.yml`
      (`templates/keepalived.conf.j2`) to match `haproxy.cfg.j2`. Cosmetic
      only — Ansible's `template` module searches both `<role>/templates/`
      and `<role>/`, so both forms resolve to the same file. An earlier
      review called this fragile, which overstated it.
- [ ] TODO 10. Ensure `/etc/keepalived` exists before deploying
      `keepalived.conf` (add an `ansible.builtin.file` task with
      `state: directory`). Today it only works because the RHEL package
      creates the directory.
- [ ] TODO 11. Decouple VIPs from HAProxy binds: `haproxy.cfg.j2` hardcodes
      `bind lb-vip.ocp.example.com:{6443,22623,80,443}` while
      `ha_haproxy_vip_api` / `ha_haproxy_vip_ingress` are consumed only by
      `keepalived.conf.j2`.
- [ ] TODO 13. Add `{% else %}` to the `unicast_peer` loop in
      `keepalived.conf.j2` so a `ansible_nodename` / inventory-hostname
      mismatch fails loudly instead of emitting blank lines.
- [ ] TODO 14. Fix stale README example: it documents `ha_haproxy_vip`,
      which no longer exists — it was split into `ha_haproxy_vip_api` and
      `ha_haproxy_vip_ingress`. Include the required `[g_ha_haproxy]` group
      and the fact that `ha_haproxy_is_primary` must be true on exactly
      one host (defaults/main.yml comment is truncated mid-sentence).
- [ ] TODO 15. Partial: `meta/main.yml` scaffold replaced in `6115206`
      (author, MIT, min_ansible_version "2.15", platforms, galaxy_tags) —
      all 14 lint `schema`/`meta-incorrect` findings cleared. Still open:
      declare the `ansible.posix` collection dependency instead of only
      documenting it in the README (needs a decision: `dependencies:` vs
      `collections/requirements.yml`).
- [ ] TODO 16. Autenticate the stats listener on `:1936` (or at minimum
      bind it to the management interface). It is currently opened in
      `public` via `ha_haproxy_fw_ports` with no credentials, so reachable
      from anywhere, not just the local host.
- [ ] TODO 17. Resolve the dead `/etc/haproxy/conf.d`: it is created by
      `tasks/main.yml` but nothing writes into it, and `haproxy.cfg.j2` has
      no `includedir /etc/haproxy/conf.d` line — every proxy is hardcoded
      inline in the one template. Either add `includedir` (which makes TODO
      5 far cleaner: per-backend drop-ins instead of a monolith) or drop
      the task. Highest-leverage item on this list — decide it before the
      Ubuntu port, since it decides whether that port is a patch or a
      refactor.
- [ ] TODO 18. Fix distro-sensitive absolute paths hardcoded in templates:
      - `haproxy.cfg.j2:9`   `chroot /var/lib/haproxy`
      - `haproxy.cfg.j2:10`  `pidfile /var/run/haproxy.pid` — Debian/Ubuntu
        use `/run/haproxy.pid`; same directory today, but `/var/run` is a
        compat symlink and writing into it is deprecated
      - `keepalived.conf.j2:5` `/usr/bin/killall` — `killall` ships in
        `psmisc` on Debian, not installed by default on minimal Ubuntu.
        This one fails silently: VRRP priority stops adjusting and failover
        degrades with no error. Promote to role variables so they can
        differ per `os_family`.

## Done

- [x] DONE 2. Gate SELinux tasks (`a534357`) — added derived var
      `ha_haproxy_selinux_enabled` in `defaults/main.yml`
      (`ansible_selinux is defined and ansible_selinux.status == 'enabled'`)
      and applied it to all five tasks (seboolean, .te, checkmodule,
      semodule_package, semodule). The three compile/load tasks needed that
      condition added on top of their existing
      `rsyslogd_selinux_policy.changed`, since that register is undefined
      when the copy is skipped. Debian is a true skip, not an alternative
      path. UNVERIFIED against a Debian target.
- [x] DONE 12. Deploy `files/haproxy_stat.sh` (`bd256f8`) — installed to
      `/root/haproxy_stat.sh`, mode `0755`, alongside the haproxy config
      deploy.
- [x] DONE 19. Settle the `haproxy_stat.sh` destination — `/root`, chosen
      to match the existing `/root/rsyslog-haproxy.te` precedent (admin
      helper, not service config) and to keep it off any PATH. Runs as root,
      required to read `/var/lib/haproxy/stats`. `nc` declared in
      `vars/main.yml`.
- [x] RETRACTED 20. ~~Create the `haproxy` user/group in the role~~ — NOT
      NEEDED. An earlier review claimed Ubuntu's haproxy package does not
      create the account, leaving `haproxy.cfg.j2` without one. That was
      wrong. Verified: Debian/Ubuntu `haproxy.postinst` runs
      `addgroup --gid 99 --system haproxy` + `adduser --uid 99 --home
      /var/lib/haproxy`, creates `/var/lib/haproxy`, and chowns it to
      `haproxy:haproxy`. Same account name on both distros. Residual risk
      only: uid/gid 99 is pinned, so the package fails to configure if 99 is
      taken (Debian bug #939470). Not a role defect.

## Known gaps (out of scope unless requested)

- [ ] Logrotate coverage for custom `ha_haproxy_logfile`.
- [ ] VRRP `auth_pass` is capped at 8 characters by the protocol, so
      `ha_haproxy_vrrp_pass` is silently truncated above that.
- [ ] Keepalived `unicast_peer` loop has no `else` (tracked as TODO 13).

## Execution log

- (none)