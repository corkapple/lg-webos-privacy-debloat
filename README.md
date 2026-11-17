# LG webOS Privacy Debloat Notes

> [!CAUTION]
> **This can brick your TV.** Rooting a consumer device voids your warranty, can
> permanently damage the panel if something goes wrong, and at minimum can leave you
> stuck in a reboot loop you have to recover from manually. The author tried this on
> one television they were willing to lose. You are responsible for yours.
>
> **Realistically, you will need an AI coding assistant (Claude, Gemini, ChatGPT, etc.)
> sitting alongside you with shell access to the TV.** This is not a copy-paste
> tutorial. Firmware versions, board names, and service layouts differ between
> models and even between firmware updates on the *same* model, several of the steps
> below only make sense once you've inspected your own TV's filesystem, and more than
> one step in this writeup only became clear after something broke and had to be
> diagnosed live. An AI that can read command output, explain what broke, and adjust
> the next command is doing most of the real work here — this document is a map of
> the territory, not a script you run blind.

## What this actually gets you

On one LG OLED TV (webOS 5.6.2, 2020 model year), starting from stock firmware with
zero prior modification, this process achieved, confirmed by direct inspection of the
TV's own settings database and filesystem — not just toggling a menu and hoping:

- Root shell access (SSH) that survives a reboot, with no dependency on LG's own
  "Developer Mode" app being installed
- Live Plus (LG's actual ACR / "what's on your screen" fingerprinting feature) off,
  confirmed in the real settings store and surviving multiple reboots
- Home-screen promotional ad carousel off
- The `channelplus` setting off, which stops a recurring LG-Channels ad banner and
  "now available" popup on the home screen
- The `watchedListCollection` setting off (cross-app "most watched" content
  aggregation on the home screen, which can promote services you don't even
  subscribe to)
- A 203-domain hosts-level block covering LG's ads, ACR (including the
  third-party `alphonso.tv` vendor LG uses for it), telemetry, recommendations,
  ThinQ/IoT, and LG Channels infrastructure -- because the home screen's promo
  carousel turned out to rotate through *multiple* independent promotional
  messages, not one fixed banner, and no single local setting controls all of
  them (see "The promo carousel has no single setting" below)
- HbbTV / broadcast tracking-consent flags set to opt out
- Five bundled apps (a VPN app, a news app, LG's own "LG Channels" free ad-supported
  TV app, and two LG-branded "gaming portal" / "sports" apps) permanently removed —
  not just hidden, and not just once (see "The reappearing apps" below)
- LG's diagnostics/crash-report uploader (`rdxd`, which defaults to
  `AutoUpload=true`) stopped, with that staying stopped on every boot
- A short, logged network-connection trace covering real usage (Live TV, apps, the
  remote's voice button) showing no unexpected outbound connections, as actual
  evidence rather than a guess

**What it does *not* get you:** ad-free streaming apps (YouTube, free ad-supported
channels — those ads come from the app/service, not from LG), or removal of LG's
Ad Overlay / "Mainos" system apps, which are baked into the read-only firmware image
and can't be deleted without rebuilding the firmware itself. Expect "meaningfully
reduced," not "ad-free."

## Will this work on a different webOS version or model?

Partially, and it's worth being specific about which parts, rather than assuming
it's plug-and-play. This was done once, on webOS 5.6.2 (2020, board `K6HP`).

**Likely to transfer as-is:**
- The root exploit path itself — [slopbro](https://github.com/throwaway96/slopbro)
  claims support for webOS 4 through 11, and Homebrew Channel supports a similarly
  wide range. Always check [cani.rootmy.tv](https://cani.rootmy.tv) for your exact
  model and firmware first, regardless of version.
- Homebrew Channel's bundled `dropbear` SSH and its `init.d` persistence mechanism —
  these belong to Homebrew Channel itself, not to any particular webOS version.
- The Developer Mode reboot-wipe behavior — this is Developer Mode's own design, not
  firmware-version-specific, though not independently verified past 5.6.2.
- The *technique* in "The reappearing apps" (`grep NL_APP_INSTALLED
  /var/log/messages`, then an early tmpfs mount) — general, regardless of which
  specific apps your TV happens to restore.
- Most of the hosts-level ad/telemetry domain list — LG's ad infrastructure isn't
  tied to one firmware version, though it does shift over time as LG retires and
  stands up new domains.

**Will need adapting, every time:**
- Exact settings key names (`livePlus`, `channelplus`, `watchedListCollection`, …).
  webOS's settings schema has changed across major versions; dump your own TV's
  `option` category (step 6 below) and look for the equivalent rather than assuming
  these exact names exist.
- The specific bundled app IDs hardcoded in `75-remove-lg-apps` — that's this one
  TV's region/model-specific bloat. Someone else's TV will have different junk;
  find it the same way (`ssap://com.webos.applicationManager/listApps`,
  cross-referenced with what visibly reappears after a reboot).
- Exact filesystem paths, if your webOS major version is far from 5.x. They held
  up fine across the testing done here, but weren't verified against anything else.

If something here doesn't match what you find on your own TV, that's expected, not
a sign the whole approach is wrong — adapt the specific piece and move on. This is
exactly the kind of model-to-model variance the warning at the top of this file is
about: it's why an AI assistant that can read your TV's actual output and adjust is
doing more of the real work than this document is.

## Before you touch anything

1. **Check your exact firmware is actually vulnerable.** Go to
   [cani.rootmy.tv](https://cani.rootmy.tv) and search your model number plus
   firmware version (Settings → About). If nothing there shows as rootable for your
   firmware, stop — running an exploit against a patched firmware is very unlikely to
   work and not worth the risk.
2. **Know your model's exact board/platform.** Settings → Support → Info shows the
   webOS version and a software string like `jhericurl-jimna` — that's your platform
   codename, and it matters for which exploit applies.
3. Read the actual projects this leans on, linked below. Their own README/safety docs
   are more authoritative than this summary.

## The process, roughly, in order

1. **Pair a basic remote-control connection to the TV** (the same protocol official
   "LG TV Plus"-style remote apps use — WebSocket on port 3001, requires accepting a
   pairing prompt on the TV once). This alone lets you list/launch apps and read a
   *subset* of settings — no root needed yet, and it's reversible (revoke from the
   TV's connected-devices settings any time).
2. **Find the actual root exploit for your firmware.** For webOS 5.x in the
   04.3x–04.6x firmware range, the live options are maintained at
   [webosbrew/webos-homebrew-channel](https://github.com/webosbrew/webos-homebrew-channel)'s
   rooting page. On this TV, the viable exploit was
   [throwaway96/slopbro](https://github.com/throwaway96/slopbro) — it runs entirely
   over that same remote-control connection, with **no need to enable LG's own
   Developer Mode app first.** `python3 slopbro.py <TV IP>`, accept the pairing
   prompt, done.
3. **Homebrew Channel gets installed but shows "Root status: unelevated."** This is
   normal for this exploit chain. Open Homebrew Channel on the TV → the
   "Root Configuration" screen → select **System Reboot** from inside that screen
   specifically (not just any TV reboot). Root elevates after that.
4. **The real "make it permanent" problem, and the fix:** LG's own "Developer Mode"
   app ships a startup script (`start-devmode.sh`) that wipes the entire
   `/media/developer` partition — which is where root and Homebrew Channel live — on
   every single boot, *by design*, as long as that app is installed and its signature
   verifies. If you ever installed Developer Mode (to get its SSH access, or because a
   guide told you to), **this is why root keeps vanishing after every reboot.**
   The fix: uninstall the Developer Mode app entirely. You almost certainly don't
   need it — see the next point.
5. **Homebrew Channel ships its own SSH server, independent of Developer Mode.** Its
   "SSH Server" toggle (Root Configuration screen) starts a bundled `dropbear` binary
   that lives at
   `.../org.webosbrew.hbchannel.service/bin/dropbear`, started from Homebrew's own
   `startup.sh` — nothing to do with LG's Developer Mode app at all. Default login is
   `root` / `alpine`. **This is the access method that actually survives reboots once
   Developer Mode is gone.** (A `systemd` unit for a *different*, system-level
   dropbear also exists on this firmware and is permanently broken — missing binary,
   exit code 203 — don't chase that one; it's a red herring.)
6. **Changing settings for real.** The settings menu's values are cosmetic unless you
   write through the actual service: `luna-send -n 1 -i
   luna://com.webos.service.settings/setSystemSettings
   '{"category":"option","settings":{"livePlus":"off", ...}}'` (run as root, over
   SSH). Reading the same settings over the *remote-control* connection from step 1
   (not SSH) will often refuse to even show you the current value for anything
   privacy-sensitive (`acrEnabled`, `voiceRecognitionEnabled`, `micEnabled` all come
   back "not allowed for the request") — that restriction is specifically about the
   unprivileged remote protocol, not the setting itself, so check from the root shell
   instead.
7. **Removing bundled apps for real.** The polite API
   (`luna://com.webos.appInstallService/dev/remove`) reports success and does
   nothing for apps that came with the firmware — it's scoped to sideloaded apps.
   What actually works, as root: find every directory/manifest/service-registration
   file referencing the app's ID under `/media/cryptofs/apps/usr/palm/{applications,
   services,packages}/` and the various `luna-service2/*.d/` directories across
   `/mnt/lg/cmn_data`, `/mnt/lg/user`, and `/var`, and delete them directly. Don't do
   this for anything backed by a `squashfs` mount (check `mount | grep squashfs` for
   the app's name first) — those are core apps (Netflix, YouTube were squashfs-backed
   on this TV) and deleting isn't the same operation; leave them alone unless you
   actually mean to touch the firmware image.
8. **Stopping always-on daemons (telemetry, etc.) persistently.** Homebrew Channel's
   own `startup.sh` runs `run-parts /var/lib/webosbrew/init.d/` on every boot — that
   directory is *the* sanctioned extension point. Drop an executable script there
   (see `scripts/70-stop-telemetry` in this repo) and it runs on every future boot,
   with zero risk to anything else: it's a pure addition, not a modification of any
   existing file, and `rm`-ing it later fully undoes it.
9. **Verify, don't assume.** Reboot after each change that's supposed to be
   persistent, and actually check — `ps aux`, `systemctl status <service>`,
   `luna-send ... getSystemSettings` — rather than trusting that a setting screen or a
   command's "success" response reflects reality. More than one step above returned
   `returnValue: true` while doing nothing at all.

## The reappearing apps

A handful of LG's *own* bundled apps (in this case: its free ad-supported channel
app, and two LG-branded "gaming portal"/"sports" apps) came back from the dead after
being deleted — not from the devmode wipe mechanism above, something else. The
`/var/log/messages` system log explains it directly:

```
appinstalld [] AppInstallD NL_APP_INSTALLED {"app_id":"lgchannels.eu","caller":"com.webos.applicationManager"}
```

**`com.webos.applicationManager` itself re-installs a baked-in set of default apps
on every boot**, independent of anything Homebrew Channel, Developer Mode, or any
setting does. The two sideloaded/partner apps (a VPN app, a news app) that were
removed earlier in this process never came back; only LG's own first-party apps
did — consistent with those being the ones on whatever internal "required defaults"
list `applicationManager` consults.

Deleting them once isn't enough; they have to be re-deleted on every boot. The fix
is `scripts/75-remove-lg-apps` in this repo, but **timing matters**: `grep
NL_APP_INSTALLED /var/log/messages` after a reboot shows `applicationManager`
restoring these apps roughly 60 seconds in, which is *after* Homebrew Channel's own
`init.d` pass (closer to 35-45 seconds, per the uptime-seconds bracket in its own log
lines). A script that just deletes inline, unbackgrounded, in `init.d` runs too
early and finds nothing to delete. The apps show up a few seconds later anyway.
`75-remove-lg-apps` backgrounds itself and sleeps past that window first.

## The promo carousel has no single setting

After fixing the apps above, the home screen kept showing *different*
promotional banners on a rotation -- one for a bundled TV-channel service, then
one pushing a streaming service's "most watched" content despite no
subscription to it, then one about a remote-control gaming feature. Each
looked, at first, like a one-off thing with its own setting. It wasn't: this
is a whole promotional content system with many independent messages, and
turning off the two or three settings that sound related
(`livePromotion`, `webOSPromotionVideo`, `watchedListCollection`) does not
stop all of them, because at least some of this content is fetched live from
an LG server rather than gated by anything stored on the device.

Chasing each banner's specific setting is a losing game. What actually works
is blocking the whole category of LG ad/recommendation/ACR infrastructure at
the network level -- see `scripts/80-block-lg-ads` and the much larger,
community-maintained domain list it's built from
([github.com/furkan-bayrak/lg-tv-blocklist](https://github.com/furkan-bayrak/lg-tv-blocklist)),
rather than a short hand-picked list of the few domains one happens to spot.

## A real bug hit while building the hosts block, worth knowing about

`/etc/hosts` is read-only on this firmware, so blocking anything at that level
means bind-mounting a custom file over it. The obvious way to build that file
-- read the current `/etc/hosts`, append new entries, write the result back --
is dangerous once a bind-mount is already active: at that point, *both* paths
(`/etc/hosts` and whatever it's bind-mounted from) are the same underlying
file. A command like `cat /etc/hosts > /path/to/the-mounted-source` opens the
destination for writing (truncating it to empty) essentially simultaneously
with reading the source -- and since they're the same file, the read can
return next to nothing. The result: the file applies with the new entries,
"succeeds" with no error, and silently drops everything that was there before,
*including the `localhost` entries* -- which several things on the TV actually
need resolved.

The fix is to never read from the live mounted file after the first time: back
it up once, to a separate path, before any bind-mount is active, and rebuild
from that untouched backup on every later boot -- never from `/etc/hosts`
itself. `scripts/80-block-lg-ads` does this (a `[ ! -f backup ]` guard makes
the backup step idempotent). If you're scripting around any bind-mounted file
on an embedded system, not just this one, that's the general lesson: writing
to a file is never safe while something else is reading from the same file
through a different mount path.

## What can go wrong (all observed first-hand)

- **Signing out and back into Developer Mode can wipe `/media/developer`** even
  without a reboot — not just the startup-script mechanism above, something about
  the re-authentication flow itself.
- **A heavy recursive filesystem scan (`find / ...` with no path restriction) can
  bring the whole TV's UI to a crawl or a non-responsive state** on a device with
  limited RAM and very little free storage — scope your `find` commands to specific
  directories, always.
- **SSH key exchange with webOS's devmode SSH server fails against a modern OpenSSH
  client** unless you explicitly re-enable legacy algorithms (`HostKeyAlgorithms=
  +ssh-rsa`, `KexAlgorithms=+diffie-hellman-group14-sha1`) — this is an old embedded
  SSH server, and current `ssh` refuses it by default.
- **An app's own luna-service directories being deleted while the app is the
  foreground app on screen can leave the TV showing a broken/stuck screen** that
  looks like a crash. It generally isn't one — back out to Home, or power-cycle.

## Files in this repo

- `scripts/70-stop-telemetry` — drop into `/var/lib/webosbrew/init.d/` as root,
  `chmod +x` it, and LG's `rdxd` diagnostics-upload daemon stays stopped on every
  boot from then on. Fully reversible: delete the file.
- `scripts/netmon.sh` — a dependency-free connection logger for when you want to
  verify "is anything calling home" with actual evidence instead of inference (this
  firmware has no `tcpdump`; this polls `netstat` every few seconds instead).
- `scripts/75-remove-lg-apps` — same install location as the telemetry script,
  keeps a set of LG-bundled apps removed on every boot (see "The reappearing apps").
  Edit the app-ID list to match what you actually want gone on your TV.
- `scripts/80-block-lg-ads` + `scripts/lg-ads-blocklist.txt` — blocks 203 LG
  ad/ACR/telemetry/recommendation/IoT hostnames by bind-mounting a custom `/etc/hosts`
  over the real one. The list is sourced from
  [furkan-bayrak/lg-tv-blocklist](https://github.com/furkan-bayrak/lg-tv-blocklist)'s
  STRICT tier, with firmware-update domains removed so security patches still work.
  The script itself is written carefully to avoid a real bug -- see "A real bug hit
  while building the hosts block" below before adapting it.

## Credit, and where the real tools live

This repo only documents a process; it doesn't reimplement anyone else's work.
Everything that actually does the rooting/debloating comes from:

- [throwaway96/slopbro](https://github.com/throwaway96/slopbro) — the root exploit used here
- [webosbrew/webos-homebrew-channel](https://github.com/webosbrew/webos-homebrew-channel) — the homebrew app store / root tooling it installs
- [cani.rootmy.tv](https://cani.rootmy.tv) / [webosbrew.org/rooting](https://www.webosbrew.org/rooting/) — the compatibility database, check this first, always
- Related community projects worth knowing about for further debloating:
  [sojufx/unspy](https://github.com/sojufx/unspy),
  [lasharor/cleanyourtv-WebOS](https://github.com/lasharor/cleanyourtv-WebOS),
  [rorygallagher2024/glasshouse](https://github.com/rorygallagher2024/glasshouse)

Go read their actual docs before doing anything. This file is a map, not a manual.

## License

MIT. See [LICENSE](LICENSE) for the text covering the contents of *this* repository.
It does not and cannot license the third-party tools linked above — check their own
licenses (mostly AGPL-3.0) before redistributing or modifying them.
