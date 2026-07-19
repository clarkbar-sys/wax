# wax

A custom [bootc](https://bootc.dev) OS image built on top of [Bazzite](https://bazzite.gg/),
the gaming-focused Fedora Atomic desktop. `wax` is meant to run on the Steam Deck and
other gaming PCs — a single, reproducible image you build once and deploy everywhere.

- **Base image:** `ghcr.io/ublue-os/bazzite:stable`
- **Published to:** `ghcr.io/clarkbar-sys/wax`
- **Status:** `v0.1` — scaffolded, building, and container-dogfoodable.

> **Note on "installing" a bootc image.** A bootc image is a whole operating system
> packaged as an OCI container. You can `podman`/`docker run` it to poke around its
> userspace (great for dogfooding), or boot a QCOW2 built from it in a local VM for a
> closer test, but to actually *use* it as your OS you either boot an installer ISO or
> `bootc switch` an existing bootc host onto it. Plain SteamOS (Valve's) is **not** a
> bootc host, so on the Deck today you dogfood in a container or a local VM.

## Roadmap

- **Now — dogfood on the Steam Deck (stock SteamOS), in a container or a local VM.**
  Pull the image and run a shell inside it, or build and boot a QCOW2 VM, to test the
  packages and config baked into `wax`.
- **Later — deploy for real on a gaming PC.** Install from an ISO, or rebase an existing
  Bazzite / Fedora Atomic machine onto `wax` with `bootc switch`.

## Dogfooding in a container (Steam Deck / stock SteamOS)

Both `podman` (preinstalled on SteamOS) and `docker` work. Pull the published image and
open a shell:

```bash
# podman (recommended on the Deck)
podman pull ghcr.io/clarkbar-sys/wax:latest
podman run --rm -it ghcr.io/clarkbar-sys/wax:latest bash

# ...or docker
docker pull ghcr.io/clarkbar-sys/wax:latest
docker run --rm -it ghcr.io/clarkbar-sys/wax:latest bash
```

From that shell you can confirm the customizations landed, e.g.:

```bash
tmux -V             # a package wax installs
rpm -q tmux         # verify via rpm
cat /etc/os-release # confirm the Bazzite base
```

This exercises the image's *userspace* — packages, files under `system_files/`, and
anything `build_files/build.sh` sets up. It does **not** boot the OS or run its systemd
services; that's what the VM (below) or the install path further down are for.

## Dogfooding as a local VM (Steam Deck / stock SteamOS)

For a closer test than the container shell — one that actually boots systemd and runs
services — build a bootable QCOW2 image and run it in a VM, right on the Deck.

Requires [`just`](https://just.systems) and `podman`. This also needs KVM: check with
`ls -l /dev/kvm` in Desktop Mode first. Steam Deck's APU supports hardware virtualization,
so it should just be there.

```bash
just build-qcow2      # build the container image, then a bootable QCOW2 from it
just run-vm-qcow2     # boot the QCOW2 in a containerized QEMU (qemux/qemu-docker)
```

`run-vm-qcow2` prints a `localhost:<port>` URL (starting at 8006) and opens it in your
browser automatically — that's a noVNC console into the running VM, no extra client
needed. Unlike the container shell, this boots the real image end to end: systemd,
enabled services, `/etc` as laid out by `system_files/`, all of it.

A few things worth knowing before you dive in:

- **Building needs `sudo`.** `bootc-image-builder` runs as a privileged, rootful podman
  container, so `just build-qcow2` invokes `sudo` for you as part of the build.
- **Resource sizing is fixed in the Justfile.** The VM boots with 4 CPUs, 8G RAM, and a
  64G disk (see the `--env` lines in the `_run-vm` recipe) — edit those directly if you
  want to change them.
- **Iterating on changes:** edit `build_files/build.sh` or `system_files/`, then run
  `just rebuild-qcow2` (rebuilds the container image *and* the QCOW2) before
  `just run-vm-qcow2` again. `run-vm-qcow2` only builds automatically when no QCOW2
  exists yet, so a stale one won't pick up your edits on its own.
- **Nothing you do live inside the booted VM writes back to this repo.** Treat the VM as
  a test harness: find the change you want, encode it in `build_files/build.sh` or
  `system_files/`, rebuild to confirm, and open a PR with that source change.

## Installing on a gaming PC (the "for real" path)

Two options once you're ready to move off dogfooding:

1. **Rebase an existing bootc host** (Bazzite, Bluefin, Aurora, Fedora Atomic):

   ```bash
   sudo bootc switch ghcr.io/clarkbar-sys/wax:latest
   sudo systemctl reboot
   ```

2. **Install from an ISO** built by the `Build disk images` workflow (or locally with
   `just build-iso`), using `disk_config/iso.toml`. The kickstart in that file rebases
   the freshly installed system onto `ghcr.io/clarkbar-sys/wax:latest` automatically.

## Building locally

Requires [`just`](https://just.systems) and `podman`.

```bash
just build            # build ghcr-equivalent image as wax:latest
just build-qcow2      # build a QCOW2 VM image (via bootc-image-builder)
just build-iso        # build an installer ISO
just run-vm-qcow2     # boot the QCOW2 image in a VM to test for real
```

Run `just` with no arguments to list every recipe.

## Customizing wax

- **`build_files/build.sh`** — install packages (`dnf5 install -y ...`), enable systemd
  units, and make system changes. This is the main place to shape the image.
- **`system_files/`** — files copied verbatim into the image root (`system_files/etc/...`
  → `/etc/...`).
- **`Containerfile`** — change the `FROM` line to pick a different base image.

## Image signing (optional)

Publishing is set up to cosign-sign images, but signing is **skipped automatically** until
you add a `SIGNING_SECRET` repository secret, so the image builds and pushes without it.
To enable signing later:

```bash
COSIGN_PASSWORD="" cosign generate-key-pair
# add cosign.key as the SIGNING_SECRET repo secret; commit cosign.pub
```

> Never commit `cosign.key`. It's already covered by `.gitignore`.

## Credits

Built from the Universal Blue [image-template](https://github.com/ublue-os/image-template).
See the [Universal Blue](https://universal-blue.org/) and [bootc](https://bootc.dev) projects
for the tooling that makes this possible.
