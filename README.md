# LG webOS Privacy Debloat Notes

> [!CAUTION]
> **This can brick your TV.** Rooting voids your warranty and can leave you stuck
> in a reboot loop or worse. Tested on one TV the author was willing to lose.
>
> **You'll need an AI assistant (Claude, Gemini, etc.) with shell access to the
> TV, not a copy-paste script.** Models/firmware differ, and several steps here
> only made sense after something broke and got diagnosed live. At every step,
> have the AI **check the real system state and say OK or NOT OK** — don't trust
> a command's own "success" message. Several below returned success while doing
> nothing.

## What this gets you

Confirmed by direct inspection, not just toggling a menu — on one webOS 5.6.2 TV:

- Root SSH that survives reboot, independent of LG's "Developer Mode" app
- Live Plus (ACR) off, plus `channelplus` and `watchedListCollection` off —
  these killed a rotating set of home-screen promo banners
- A 203-domain hosts-level block (ads/ACR/telemetry/recommendations), since the
  promo carousel turned out to have no single controlling setting
- Five bundled apps permanently gone, including some that silently got
  auto-restored by `applicationManager` itself
- LG's diagnostics uploader (`rdxd`) stopped, persistently
- **Not included:** ads inside streaming apps (YouTube etc.), or LG's Ad
  Overlay system apps — both are outside what root access reaches here

## Portability

- **Likely to transfer:** the root exploit path (check
  [cani.rootmy.tv](https://cani.rootmy.tv) for your model/firmware first,
  always), Homebrew Channel's SSH + persistence mechanism, the Developer Mode
  wipe issue, the *technique* for finding reappearing apps and blocking ads.
- **Won't transfer as-is:** exact settings key names, the specific bundled app
  IDs, and filesystem paths on very different webOS versions. Find your own
  equivalents the same way this repo found these.

## The process

1. **Pair a remote-control connection** (port 3001, same protocol as official
   remote apps) — accept one pairing prompt on the TV. No root needed yet.
2. **Find your root exploit.** Check [cani.rootmy.tv](https://cani.rootmy.tv),
   then [webosbrew.org/rooting](https://www.webosbrew.org/rooting/). Here it was
   [slopbro](https://github.com/throwaway96/slopbro) — runs entirely over the
   connection from step 1, **no Developer Mode app needed.**
3. Homebrew Channel installs but shows "unelevated." Open it on the TV →
   Root Configuration → select **System Reboot** from inside that screen.
4. **The reboot-wipe problem:** if LG's Developer Mode app is installed, its
   `start-devmode.sh` wipes `/media/developer` (root, Homebrew) on *every*
   boot, by design. Fix: uninstall Developer Mode. You don't need it —
5. — because Homebrew Channel ships its **own SSH server** (`dropbear`,
   default `root`/`alpine`), started by Homebrew's own boot script,
   independent of Developer Mode entirely. This is what survives reboots.
6. **Settings only stick if written for real:** `luna-send -n 1 -i
   luna://com.webos.service.settings/setSystemSettings '{"category":"option",
   "settings":{"livePlus":"off"}}'` as root over SSH. The *remote-control*
   connection from step 1 often refuses to even show privacy-sensitive
   settings — check from the root shell instead.
7. **Removing bundled apps for real:** the polite API
   (`.../dev/remove`) reports success and does nothing for apps that came
   with the firmware. What works: delete the app's folders directly under
   `/media/cryptofs/apps/usr/palm/{applications,services,packages}/` and the
   matching `luna-service2/*.d/` entries across `/mnt/lg/{cmn_data,user}` and
   `/var`. Skip anything backed by a `squashfs` mount (`mount | grep squashfs`)
   — that's a core app (Netflix, YouTube here), not bloat.
8. **Persisting changes:** Homebrew's `startup.sh` runs
   `run-parts /var/lib/webosbrew/init.d/` every boot. Drop a script there —
   pure addition, fully reversible by deleting it.
9. **Check everything, every time** — see the warning above. This is the step
   that actually matters.

## Two things that bit us

- **Apps that come back.** Some bundled apps get silently re-installed by
  `com.webos.applicationManager` itself on every boot — unrelated to root,
  Homebrew, or Developer Mode. Find yours: `grep NL_APP_INSTALLED
  /var/log/messages` after a reboot. Deleting after the fact isn't enough
  (timing: it restores ~60s in, our init.d scripts ran at ~35-45s, so a late
  delete still let it exist long enough to get promoted on the home screen).
  Fix: bind-mount an empty, read-only `tmpfs` over the app's path *before*
  that window, so it never has real content — see `scripts/75-remove-lg-apps`.
- **Never read-and-rewrite the same bind-mounted file in one command.**
  `/etc/hosts` is read-only here, so blocking domains means bind-mounting a
  custom file over it. Doing that by piping the *live* `/etc/hosts` into its
  own backing file truncates the source mid-read — we silently lost the
  `localhost` entries this way. Back the original up once, rebuild from that
  backup every time, never from the live file. See `scripts/80-block-lg-ads`.

## Files

- `scripts/70-stop-telemetry` — stops LG's `rdxd` diagnostics uploader, persistently
- `scripts/75-remove-lg-apps` — blocks reappearing bundled apps via early tmpfs mount
- `scripts/80-block-lg-ads` + `lg-ads-blocklist.txt` — 203-domain hosts block, sourced
  from [furkan-bayrak/lg-tv-blocklist](https://github.com/furkan-bayrak/lg-tv-blocklist)
  (firmware-update domains excluded so updates still work)
- `scripts/netmon.sh` — connection logger for TVs with no `tcpdump`, to verify
  nothing's phoning home with actual evidence

Each script's own header has the full install command and reasoning.

## Credit

This documents a process; the actual tools are:
[slopbro](https://github.com/throwaway96/slopbro),
[webos-homebrew-channel](https://github.com/webosbrew/webos-homebrew-channel),
[cani.rootmy.tv](https://cani.rootmy.tv),
[lg-tv-blocklist](https://github.com/furkan-bayrak/lg-tv-blocklist). Also worth
knowing: [unspy](https://github.com/sojufx/unspy),
[cleanyourtv-WebOS](https://github.com/lasharor/cleanyourtv-WebOS),
[glasshouse](https://github.com/rorygallagher2024/glasshouse) — more complete
debloat/launcher-replacement toolkits, for a different model/TV each, so expect
the same adapting this repo needed.

## License

MIT for this write-up (see [LICENSE](LICENSE)). Doesn't cover the third-party
tools linked above — check their own licenses (mostly AGPL-3.0).
