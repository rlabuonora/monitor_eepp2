# WSL Migration

This repo is intended to run from the Linux filesystem in WSL2, not from `/mnt/c`.

## Checklist

- Clone or move the repo into `~/dev/monitor_empresas_publicas`.
- Keep shell, R, and Makefile sources on LF line endings.
- Use a user-level R library in WSL.
- Run the import with `make import`.
- Run the app with `make run`.

## WSL Clone Or Move

Clone fresh into WSL:

```bash
mkdir -p ~/dev
cd ~/dev
git clone <REMOTE_URL> monitor_empresas_publicas
cd monitor_empresas_publicas
pwd
```

Expected outcome:

- `pwd` prints a path under `/home/<user>/dev/monitor_empresas_publicas`

Move an existing checkout from Windows into WSL:

```bash
mkdir -p ~/dev
cp -a /mnt/c/path/to/monitor_empresas_publicas ~/dev/
cd ~/dev/monitor_empresas_publicas
pwd
```

Expected outcome:

- the repo exists under `/home/<user>/dev/monitor_empresas_publicas`
- future commands run faster than from `/mnt/c/...`

## Git Setup For Cross-Platform Work

Apply a minimal global Git configuration in WSL:

```bash
git config --global core.autocrlf input
git config --global core.eol lf
git config --global core.filemode true
git config --global pull.rebase false
```

Expected outcome:

- `git config --global --get core.autocrlf` prints `input`
- `git config --global --get core.eol` prints `lf`

This repo also includes a root `.gitattributes` file to keep source files on LF and data files binary.

## Script Permissions

The only shell script currently intended to be executed directly is:

- `legacy/eeppImport/scripts/install_package.sh`

Verify:

```bash
stat -c '%A %n' legacy/eeppImport/scripts/install_package.sh
```

Expected outcome:

- the mode starts with `-rwx`

Run it explicitly with:

```bash
legacy/eeppImport/scripts/install_package.sh
```

## Bootstrap In WSL

Verify required tools:

```bash
R --version
make --version
git --version
```

Expected outcome:

- each command prints its version and exits successfully

Verify the WSL R library path:

```bash
Rscript -e 'print(.libPaths())'
```

Expected outcome:

- the first writable library is under your home directory

Run the first migration slice:

```bash
make import
```

Expected outcome:

- `Imported dataset: proyecciones`
- `Wrote: .../monitor/data/processed/proyecciones.rds`

Run the app:

```bash
make run
```

Expected outcome:

- `Listening on http://0.0.0.0:3838`

Open from Windows:

- `http://localhost:3838`
- if Windows localhost forwarding is not working, use the WSL IP shown by `ip -4 addr show eth0`

## Audit Commands

Check for CRLF in runtime-sensitive files:

```bash
rg -nU '\r$' --glob 'Makefile' --glob '*.sh' --glob '*.bash' --glob '*.R' --glob 'Dockerfile*' .
```

Expected outcome:

- no output

Check for Windows-native paths that may need review:

```bash
rg -n '([A-Za-z]:\\\\|/mnt/c/|\\\\\\\\[^\\\\])' .
```

Expected outcome:

- ideally no runtime-critical matches
