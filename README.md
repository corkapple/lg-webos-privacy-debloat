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
- HbbTV / broadcast tracking-consent flags set to opt out
- Four bundled apps (a VPN app, a news app, and two LG-branded "gaming portal" /
  "sports" apps) permanently removed — not just hidden
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
