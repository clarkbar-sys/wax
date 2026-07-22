#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

### Stamp the wax version/commit so the running system is self-describing.
# WAX_GIT_SHA is passed in from the Containerfile (set by the `build` recipe).
# Without it (e.g. a bare `podman build`), fall back to "unknown".
WAX_GIT_SHA="${WAX_GIT_SHA:-unknown}"
WAX_BUILD_DATE="$(date -u +%Y-%m-%d)"

# A dedicated, easy-to-read marker file.
cat >/usr/lib/wax-release <<EOF
WAX_GIT_COMMIT=${WAX_GIT_SHA}
WAX_BUILD_DATE=${WAX_BUILD_DATE}
EOF

# Also surface it in os-release, where users (and `bootc status`) look. Only
# append custom fields; never touch the base NAME/ID/VERSION identity. Strip any
# prior wax lines first so this stays idempotent across rebuilds.
if [[ -f /usr/lib/os-release ]]; then
    sed -i '/^IMAGE_VERSION=/d;/^WAX_GIT_COMMIT=/d;/^WAX_BUILD_DATE=/d' /usr/lib/os-release
    cat >>/usr/lib/os-release <<EOF
IMAGE_VERSION=${WAX_GIT_SHA}
WAX_GIT_COMMIT=${WAX_GIT_SHA}
WAX_BUILD_DATE=${WAX_BUILD_DATE}
EOF
fi

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
dnf5 install -y tmux

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket
