# TODO — ha_haproxy Ubuntu 26.04+ support

Status legend: `TODO` | `WIP` | `DONE`

## Tasks

- [ ] TODO 1. OS-conditional package install: `ansible.builtin.apt` when
      `os_family == 'Debian'`, keep `dnf` for RedHat; add `rsyslog` to
      `vars/main.yml` packages (may be missing on minimal Ubuntu).
- [ ] TODO 2. Gate SELinux tasks with
      `when: ansible_selinux.status|default('disabled') == 'enabled'`
      (seboolean + .te/compile/load chain in `tasks/main.yml`).
- [ ] TODO 3. Firewall branch: install/enable firewalld on Debian family,
      or switch to `ufw`.
- [ ] TODO 4. Verify `ssl-default-bind-ciphers PROFILE=SYSTEM` works with
      Ubuntu's OpenSSL 3 build; adjust template if not.
- [ ] TODO 5. Refactor hardcoded `*.ocp.example.com` backends in
      `templates/haproxy.cfg.j2` into role variables (needed for real
      multi-distro testing).
- [ ] TODO 6. Update `meta/main.yml` (platforms, license, author) and
      README (Ubuntu support, fix stale `ha_haproxy_vip` example var).
- [ ] TODO 7. Add Ubuntu test inventory/playbook under `tests/`. The
      current `tests/test.yml` targets `localhost` with no variables set,
      so `ha_haproxy_vip_api` renders empty and `groups['g_ha_haproxy']`
      fails outright.
- [ ] TODO 8. Full verification run: `ansible-lint` + `yamllint` +
      playbook run against RHEL and Ubuntu targets.
- [ ] TODO 16. Autenticate the stats listener on `:1936` (or at minimum
      bind it to the management interface). It is currently opened in
      `public` via `ha_haproxy_fw_ports` with no credentials. Promoted
      from "known gaps" because the firewall exposure makes it reachable
      from anywhere, not just the local host.
- [ ] TODO 17. Resolve the dead `/etc/haproxy/conf.d`: it is created by
      `tasks/main.yml:59-66` but nothing writes into it, and
      `haproxy.cfg.j2` has no `includedir /etc/haproxy/conf.d` line — every
      proxy is hardcoded inline in the one template. Either add
      `includedir` (which makes TODO 5 far cleaner: per-backend drop-ins
      instead of a monolith) or drop the task. Highest-leverage item on
      this list — decide it before the Ubuntu port, since it decides
      whether that port is a patch or a refactor.
- [ ] TODO 18. Fix distro-sensitive absolute paths hardcoded in templates:
      - `haproxy.cfg.j2:9`   `chroot /var/lib/haproxy`
      - `haproxy.cfg.j2:10`  `pidfile /var/run/haproxy.pid` — Debian/Ubuntu
        use `/run/haproxy.pid`; same directory today, but `/var/run` is a
        compat symlink and writing into it is deprecated
      - `keepalived.conf.j2:5` `/usr/bin/killall` — `killall` ships in
        `psmisc` on Debian, not installed by default on minimal Ubuntu
      Promote to role variables so they can differ per `os_family`.
- [x] DONE 19. Settle the `haproxy_stat.sh` destination as a deliberate
      decision. Resolved: `/root/haproxy_stat.sh`, chosen to match the
      existing `/root/rsyslog-haproxy.te` precedent (admin helper, not
      service config) and to keep the script off any PATH since it is
      invoked manually. Runs as root — required to read
      `/var/lib/haproxy/stats`. `nc` dependency now declared in
      `vars/main.yml`.

## Findings from code review (2026-10-07)

- [ ] TODO 9. Fix inconsistent template `src` path in
      `tasks/main.yml:25` (`templates/keepalived.conf.j2`) to match
      `tasks/main.yml:71` (`haproxy.cfg.j2`). Cosmetic only — Ansible's
      `template` module searches both `<role>/templates/` and `<role>/`, so
      both forms resolve to the same file. Correction: an earlier review
      called this fragile, which overstated it. Verified by reading module
      search paths, not by running Ansible (not installed locally).
- [ ] TODO 10. Ensure `/etc/keepalived` exists before deploying
      `keepalived.conf` (add an `ansible.builtin.file` task with
      `state: directory`). Today it only works because the RHEL package
      creates the directory.
- [ ] TODO 11. Decouple VIPs from HAProxy binds: `haproxy.cfg.j2` hardcodes
      `bind lb-vip.ocp.example.com:{6443,22623,80,443}` while
      `ha_haproxy_vip_api` / `ha_haproxy_vip_ingress` are consumed only by
      `keepalived.conf.j2`. Overlaps TODO 5; keep in one place.
- [x] DONE 12. Deploy `files/haproxy_stat.sh` via a `copy` task. Done in
      `bd256f8` — installed to `/root/haproxy_stat.sh`, mode `0755`,
      alongside the haproxy config deploy. `nc` added to
      `ha_haproxy_packages` so the script's `nc -U` call resolves.
- [ ] TODO 13. Add `{% else %}` to the `unicast_peer` loop in
      `keepalived.conf.j2` (lines 32-35 and 63-66) so a
      `ansible_nodename` / inventory-hostname mismatch fails loudly
      instead of emitting blank lines.
- [ ] TODO 14. Fix stale README example: it documents `ha_haproxy_vip`,
      which no longer exists — it was split into `ha_haproxy_vip_api` and
      `ha_haproxy_vip_ingress`. Include the required `[g_ha_haproxy]` group
      and the fact that `ha_haproxy_is_primary` must be true on exactly
      one host (defaults/main.yml:4 comment is truncated mid-sentence).
- [ ] TODO 15. Replace the untouched galaxy scaffold in `meta/main.yml`
      (`author: your name`, `license: license (GPL-2.0-or-later, MIT, etc)`,
      `min_ansible_version: 2.1`) with real values; declare the
      `ansible.posix` collection dependency instead of only documenting it
      in the README.

## Known gaps (out of scope unless requested)

- [ ] Stats page binds `:1936` with no authentication (firewall-opened).
- [ ] Logrotate coverage for custom `ha_haproxy_logfile`.
- [ ] `keepalived` unicast_peer loop has no `else` (blank lines if
      `ansible_nodename` mismatches inventory hostname).

## Execution log

- (none)
