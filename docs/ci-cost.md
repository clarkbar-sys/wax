# CI cost: build cache & runner strategy

This note records the decisions behind how `wax` builds in CI, so the
cost tradeoffs are documented rather than rediscovered. It closes
[#8](https://github.com/clarkbar-sys/wax/issues/8).

## Where the cost actually is

Every CI build runs on a fresh, ephemeral GitHub-hosted runner. The
dominant per-run cost is pulling and layering the multi-GB
`ghcr.io/ublue-os/bazzite:stable` base, then rechunking and pushing the
result. The `--mount=type=cache` dirs in the `Containerfile`
(`/var/cache`, `/var/log`) live only for the duration of a single runner,
so nothing is reused run-to-run.

The customization layer itself — the `RUN /ctx/build.sh` step — is
currently cheap (it copies `system_files/` and installs a couple of
packages). The base pull, rechunk, and push dominate; the layer we
actually author does not.

## What we changed

**Reduced the scheduled cadence from daily to 3×/week (Mon/Wed/Fri).**
See `.github/workflows/build.yml`. The scheduled build's only job is to
pick up upstream Bazzite base updates. Those do not ship daily, so a daily
cron spent CI minutes reproducing an unchanged image most mornings.
Mon/Wed/Fri still tracks base updates within ~2–3 days while cutting
scheduled builds from ~30/month to ~13/month.

Pushes to `main` and pull requests continue to build on **every** change —
this only changes the unattended base-refresh cadence, not
change-triggered builds.

## What we evaluated and deferred

These were considered and intentionally **not** done now, with reasons:

- **Registry build cache** (`podman build --cache-to / --cache-from`
  against a GHCR OCI cache repo). This caches intermediate build layers —
  in practice, the `RUN /ctx/build.sh` layer. That layer is trivial today,
  and the base image arrives via `FROM` (pinned by digest) which is pulled
  regardless of build cache, so caching would not touch the dominant cost.
  Revisit once [#4](https://github.com/clarkbar-sys/wax/issues/4) makes the
  customization layer expensive (many packages, COPRs, large file copies) —
  at that point cache-to/cache-from starts paying for itself.

- **Larger or self-hosted runner.** This trades billed minutes for
  wall-clock (or vice versa) and depends on the build host referenced in
  [#4](https://github.com/clarkbar-sys/wax/issues/4). It's an
  infrastructure decision, not a workflow tweak, so it's out of scope here.

- **Caching payoff after the two-base matrix.** Once
  [#3](https://github.com/clarkbar-sys/wax/issues/3) lands `wax-deck` +
  `wax-nvidia`, every push becomes 2× full builds and the case for a
  registry cache roughly doubles. Worth doing alongside or just after #3,
  not before.

## Out of scope

Dev-iteration speed. The fast loop for that is local `podman build` +
`podman run -it`, not CI. This note is specifically about CI cost.
