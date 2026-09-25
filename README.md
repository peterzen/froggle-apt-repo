# froggle-apt-repo

Sources for the FROGGLE apt packages. GitHub Actions builds them and publishes
a signed apt repository to GitHub Pages.

## Using the repository

```sh
curl -fsSL https://peterzen.github.io/froggle-apt-repo/install.sh | sudo sh
sudo apt install froggle-ca froggle-ws
```

`install.sh` puts the signing key in `/etc/apt/keyrings/froggle.asc` and writes
`/etc/apt/sources.list.d/froggle.sources`, using the machine's Debian codename
as the suite. Supported: `bookworm`, `trixie`. On anything else (e.g. Ubuntu)
pick one explicitly: `curl ... | sudo SUITE=trixie sh`.

## Packages

| package | contents |
|---|---|
| `froggle-ca` | FROGGLE CA certs in `/usr/local/share/ca-certificates/froggle/`; runs `update-ca-certificates` |
| `froggle-certs` | transitional package for hosts that have the old `froggle-certs` 1.5 (use `apt full-upgrade`) |
| `froggle-ws` | system-wide GTK 3/4 `settings.ini`, GNOME dconf defaults, `QT_QPA_PLATFORMTHEME=gtk3` |

## Layout

```
packages/<name>/          one native debhelper source package per directory
  debian/                 control, changelog, rules, maintainer scripts
  ...                     payload (installed via debian/<name>.install)
scripts/build-packages.sh builds packages/* into out/*.deb
scripts/test-install.sh   installs out/*.deb, checks them, purges (CI, per release)
scripts/build-repo.sh     turns out/*.deb into a signed repo in public/
.github/workflows/        build → test on bookworm + trixie → publish to Pages (master only)
```

Files under `/etc` are automatically marked as conffiles, so local edits
survive upgrades. To replace a config file owned by another package (e.g.
Ubuntu's `libgtk-3-0t64` ships `/etc/gtk-3.0/settings.ini`), ship it as
`<path>.froggle` and list it in `debian/<name>.displace`;
[config-package-dev](https://debathena.mit.edu/config-package-dev/) diverts the
original and puts it back on removal.

## Releases

Every package is `Architecture: all` and built once (in `debian:bookworm`), so
all suites share one pool and list the same packages. To add a release, add it
to `CODENAMES` in `scripts/build-repo.sh`, the `case` in `install.sh` and the
test matrix in the workflow. If a package ever needs to differ per release,
build it per release and give each suite its own pool.

## Adding or changing a package

1. Edit files under `packages/<name>/` (for a new package, copy an existing one).
2. Bump the version: `dch -v <new-version> -D stable "what changed"` in the
   package dir (or edit `debian/changelog` by hand). apt only upgrades when the
   version goes up.
3. Commit to `master`. CI builds, tests on every release and publishes.

Local build (Debian/Ubuntu with `debhelper config-package-dev apt-utils`):

```sh
scripts/build-packages.sh            # or: scripts/build-packages.sh froggle-ws
```

Note that Ubuntu's `dpkg-deb` produces zstd-compressed debs, which older
Debian releases can't read. CI builds in `debian:bookworm`, which uses xz.

## One-time setup

1. Create a dedicated signing key (no passphrase, since CI uses it):
   ```sh
   gpg --quick-gen-key "FROGGLE apt repo <peter@froggle.org>" ed25519 sign 5y
   gpg --armor --export-secret-keys <KEYID>   # -> secret APT_SIGNING_KEY
   ```
2. Repo settings → Secrets and variables → Actions: add secret
   `APT_SIGNING_KEY` and variable `APT_SIGNING_KEY_ID`.
3. Repo settings → Pages → Source: **GitHub Actions**.
4. Settings → Environments → `github-pages`: allow deployments from `master`.

The public key is published as `froggle.asc` next to the repo. Rotating the key
means re-running `install.sh` on clients.

## Limitations

- Each deploy rebuilds the repo from the current sources, so only the latest
  version of each package is available (no downgrades via apt).
- Firefox and Chromium use their own NSS stores and ignore the system CA
  bundle unless configured (Firefox: `ImportEnterpriseRoots`/`Certificates`
  policy in `/etc/firefox/policies/policies.json`; or replace `libnssckbi.so`
  with p11-kit's trust module).
- `settings.ini` is ignored when a settings daemon is running (GNOME uses the
  dconf defaults instead; Xfce uses xfconf).
