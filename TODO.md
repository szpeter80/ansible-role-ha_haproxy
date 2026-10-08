# TODO — ha_haproxy Ubuntu 26.04+ support

Status legend: `TODO` | `WIP` | `DONE`

Items are grouped by status, unsolved first. An item keeps its original number
so it stays traceable to wherever it was raised.

## Unsolved

- [ ] TODO 5. Refactor hardcoded `*.ocp.example.com` backends in `templates/haproxy.cfg.j2` into role variables (needed
      for real multi-distro testing). Overlaps TODO 11 — keep in one place.

- [ ] TODO 23. `.gitignore` is tracked but empty, so the untracked `.ansible/` ansible-lint cache created in the role
      root on every lint run pollutes `git status`.


- [ ] TODO 7. Add Ubuntu test inventory/playbook under `tests/`. The current `tests/test.yml` targets `localhost` with
      no variables set, so `ha_haproxy_vip_api` renders empty and `groups['g_ha_haproxy']` fails outright.

- [ ] TODO 99. Full verification run: `ansible-lint` + `yamllint` + playbook run against RHEL and Ubuntu targets.

- [ ] TODO 11. Decouple VIPs from HAProxy binds: `haproxy.cfg.j2` hardcodes `bind
      lb-vip.ocp.example.com:{6443,22623,80,443}` while `ha_haproxy_vip_api` / `ha_haproxy_vip_ingress` are consumed
      only by `keepalived.conf.j2`.

- [ ] TODO 16. Autenticate the stats listener on `:1936` (or at minimum bind it to the management interface). It is
      currently opened in `public` via `ha_haproxy_fw_ports` with no credentials, so reachable from anywhere, not just
      the local host.

## Done

- [x] DONE 22. Group the five SELinux tasks into `tasks/selinux.yml` (`9d3c0c1`) — `seboolean`, the `.te` copy,
      `checkmodule`, `semodule_package` and `semodule` moved out of `main.yml` into `tasks/selinux.yml`, which
      `main.yml` includes under `when: ha_haproxy_selinux_enabled | bool`. The include's `when` is inherited by
      every task in the file, so the per-task family gates dropped; the three command tasks keep their
      `rsyslogd_selinux_policy.changed` gate, which is a different concern (only recompile when the `.te` changed).
      The register `rsyslogd_selinux_policy` is set and consumed entirely inside the new file, so no cross-file
      dependency. Behaviour-identical on RedHat: same tasks, same relative order; the `seboolean` just runs after
      the rsyslog config instead of before the conf.d task, which is neutral because its effect only takes hold on
      the haproxy restart handler. On Debian the five `skipped` lines collapse into one skipped include.

- [x] DONE 4. `ssl-default-bind-ciphers PROFILE=SYSTEM` on the Debian family (`c4d8bd3`) — the two
      `global` lines are now inside `{% if ansible_os_family == 'RedHat' %}`. `PROFILE=SYSTEM` is a Red Hat downstream
      patch, not upstream HAProxy: zero mentions of `PROFILE`/`crypto-policies` in the HAProxy 3.2 configuration
      reference, and a reported failure of `[ALERT] (111301): unable to set SSL cipher list to 'PROFILE=SYSTEM'`.
      Ubuntu's equivalent is to not set a cipher list in haproxy at all and let OpenSSL defaults apply, tuned via
      `/etc/ssl/openssl.cnf` (`system_default_sect`, `CipherString = DEFAULT:@SECLEVEL=2`). Correction to an earlier
      note: the `crypto-policies` package IS available on Ubuntu 26.04 (resolute/universe) — installing it would not
      help, since upstream haproxy does not implement the sentinel. Verified by rendering the template for both
      families: RedHat emits both lines, Debian emits none. Ubuntu ships haproxy 3.2.9-1ubuntu2.2, not the 3.0.5 named
      in the template header comment — that comment is now stale. Still UNVERIFIED against a running haproxy.

- [x] DONE 18. `killall` dependency and pidfile path (`bb1d7b1`) — `psmisc` added to both per-family package tables,
      not just Debian: `killall` ships in `psmisc` on both, so the `chk_haproxy` track script was relying on a minimal
      image happening to have it on RedHat too. Making it explicit removes the silent-failure mode. Also changed
      `haproxy.cfg.j2` pidfile from `/var/run/haproxy.pid` to the FHS-correct `/run/haproxy.pid` — same directory on any
      current system, so no behaviour change, but the config no longer encodes a legacy path. Scope narrowed during the
      work: `chroot /var/lib/haproxy`, the stats socket and `/etc/haproxy/conf.d` are identical on both families and
      were dropped from this item. Rejected the `pgrep -x haproxy` alternative in favour of keeping the dependency.

- [x] DONE 21. Open VRRP in the firewall (`ce8381f`) — one task per firewall file, not a variable: VRRP is structural
      to the role, so a variable would imply it could be turned off. Keepalived does not open this itself
      (`vrrp_iptables`/`vrrp_nftables` only cover `no_accept` and VMAC IGMP). Both backends turned out to accept a
      protocol as a first-class parameter, so no rich rule is needed after all: `ansible.posix.firewalld` has a
      `protocol:` key, and `community.general.ufw` has `proto: vrrp` (since community.general 10.3.0; 13.4.0
      installed).
      Confirmed by reading both installed module sources — this corrects an earlier note that said firewalld required a
      rich rule and that the ufw side was unverified. Zone-wide, not restricted to peer addresses. The Debian task is
      gated on `ha_haproxy_ufw_usable` like its port task. Still UNVERIFIED against a live host.

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
