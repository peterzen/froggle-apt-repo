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
| `froggle-ws` | system-wide dark mode: GTK 3/4, GNOME/libadwaita, Xfce, Qt 5/6 (see below) |

### froggle-ws: dark mode

| toolkit / desktop | how | file |
|---|---|---|
| GTK 3 | `Adwaita-dark` + prefer-dark (no settings daemon) | `/etc/gtk-3.0/settings.ini` (diverted) |
| GTK 4 | prefer-dark (built-in theme's dark variant) | `/etc/gtk-4.0/settings.ini` (diverted) |
| GNOME, libadwaita, portal | `color-scheme='prefer-dark'`, `gtk-theme='Adwaita-dark'` | `/usr/share/glib-2.0/schemas/60_froggle-ws.gschema.override` |
| Xfce | `Net/ThemeName=Adwaita-dark` (Debian's defaults otherwise) | `/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml` (diverted) |
| xfwm4 | `Greybird-dark` window borders | `/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml` |
| Qt 5 / Qt 6 | `QT_QPA_PLATFORMTHEME=qt5ct` (outside Plasma); Fusion + qt5ct/qt6ct `darker` palette, GTK file dialogs | `/etc/profile.d/froggle-qt.sh`, `/etc/xdg/qt5ct/qt5ct.conf`, `/etc/xdg/qt6ct/qt6ct.conf` |

Why Qt needs extra packages: Qt only follows a desktop's colours through a
*platform theme* plugin, and on anything but Plasma none is installed by
default, so Qt apps fall back to a light Fusion palette. The gtk3 plugin
(`qt6-gtk-platformtheme`) copies GTK's colours only from Qt 6.5 on (trixie has
6.8, bookworm 6.4), and Qt 5's never does. qt5ct/qt6ct work on both releases
and for Qt 5 and 6, so froggle-ws depends on `qt5ct`, `qt6ct` and
`qt5-gtk-platformtheme`/`qt6-gtk-platformtheme` (for GTK file dialogs).

The Xfce and Qt setup follows what Kali's
[kali-themes](https://gitlab.com/kalilinux/packages/kali-themes) package does.

These are defaults: settings a user has already changed in Xfce, GNOME or
qt5ct/qt6ct win. qt5ct/qt6ct copy the system file into `~/.config` only when a
user has no config yet.

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

Run the key steps on a trusted machine. A throwaway `GNUPGHOME` keeps the CI
key out of your personal keyring.

1. Create a dedicated signing key. It has no passphrase because CI has to use
   it unattended; the GitHub secret is what protects it.
   ```sh
   export GNUPGHOME=$(mktemp -d)
   gpg --batch --passphrase '' --quick-gen-key \
       "FROGGLE apt repository <peter@froggle.org>" ed25519 sign 5y
   FPR=$(gpg --list-keys --with-colons | awk -F: '/^fpr/{print $10; exit}')
   echo "$FPR"
   ```
2. Store it in GitHub: repo **Settings → Secrets and variables → Actions**.
   - **Secrets** tab → *New repository secret*: name `APT_SIGNING_KEY`, value
     the output of `gpg --armor --export-secret-keys "$FPR"` (the whole block,
     including the `-----BEGIN/END PGP PRIVATE KEY BLOCK-----` lines).
   - **Variables** tab → *New repository variable*: name
     `APT_SIGNING_KEY_ID`, value `$FPR`.
3. Back up the key offline (password manager or encrypted drive), then delete
   the local copy:
   ```sh
   gpg --armor --export-secret-keys "$FPR" > froggle-apt-signing-key.asc
   cp "$GNUPGHOME/openpgp-revocs.d/$FPR.rev" .   # revocation certificate
   rm -rf "$GNUPGHOME"
   ```
4. **Settings → Pages → Build and deployment → Source: GitHub Actions.**
5. Run the workflow: **Actions → apt repo → Run workflow** (or push to
   `master`). The `github-pages` environment is created on the first deploy
   and allows `master` by default.
6. Check: `https://peterzen.github.io/froggle-apt-repo/froggle.asc` should
   serve the public key, then run the install command above on a client.

The public key is published as `froggle.asc` next to the repo. The key expires
after 5 years; to extend it, import the backup, run
`gpg --quick-set-expire "$FPR" 5y`, update the secret and redeploy; clients
pick up the new expiry on their next `install.sh` run (or fetch `froggle.asc`
into `/etc/apt/keyrings/`). A new key means re-running `install.sh` on every
client.

## Limitations

- Each deploy rebuilds the repo from the current sources, so only the latest
  version of each package is available (no downgrades via apt).
- Firefox and Chromium use their own NSS stores and ignore the system CA
  bundle unless configured (Firefox: `ImportEnterpriseRoots`/`Certificates`
  policy in `/etc/firefox/policies/policies.json`; or replace `libnssckbi.so`
  with p11-kit's trust module).
- `settings.ini` is ignored when a settings daemon is running (GNOME uses the
  dconf defaults instead; Xfce uses xfconf).
