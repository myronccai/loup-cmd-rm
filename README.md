# loup-cmd-rm

GNU `rm` recreated in [Loup](https://code-craft.ai/references/loup): remove
files and directories with `-r`, `-d`, `-f` and `-v`, with GNU's safety
guards (`--preserve-root`, refusing `.` and `..`) written as explicit,
tested checks, and symbolic links removed but never followed.

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is `host.dual` Loup built as a native binary.

## Requirements

- [Loup Lite](https://github.com/code-craft-ai-company/loup-releases) 1.26.0
  or later; see [Installing Loup Lite](#installing-loup-lite).
- `make`, and `clang` 17 or later for the native build.

## Installing Loup Lite

This example is built and tested with **Loup Lite**, the free public build of
the Loup toolchain from [Code Craft AI](https://code-craft.ai), meant for
education and training. Code Craft AI publishes the official builds,
installers and signed checksums at
**<https://github.com/code-craft-ai-company/loup-releases>**, for Linux
(x86-64, arm64), macOS (Apple silicon, Intel) and Windows (x86-64).

Linux and macOS:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.ps1 | iex
```

The installer picks the archive for your machine, checks it against the
release's `SHA256SUMS`, unpacks it into `~/.loup`
(`%LOCALAPPDATA%\Programs\Loup` on Windows) and puts its `bin` directory on
your `PATH`; it needs no administrator rights. You get `loup`, the Stage0
compiler `loup-bootstrap` and the Wasm runtime `loup-launcher`. Open a new
shell and check:

```sh
loup --version             # loup 1.26.0 or later
```

CI installs the exact version it tests with, 1.26.0. To do the same:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/download/v1.26.0/loup-install.sh | sh -s -- --version 1.26.0
```

To install by hand, download your platform's archive from the
[releases page](https://github.com/code-craft-ai-company/loup-releases/releases),
check it against `SHA256SUMS`, unpack it anywhere and add its `bin` directory to
`PATH`. The [loup-releases README](https://github.com/code-craft-ai-company/loup-releases#verify-a-download)
explains how to verify the Sigstore signature on `SHA256SUMS`.

Loup Lite leaves out Loup's cryptography library and the full set of Loup
packages; this example needs neither. The full release is at
<https://code-craft.ai/loup/download>, and commercial use of Loup needs a
license: <https://code-craft.ai/loup/license>.

## Usage

```sh
make build                       # native binary: build/rm
make ci                          # check, unit tests, build, end-to-end tests
make run ARGS="-rv build/scratch"  # run from source with loup run
```

In a directory holding `notes.txt`, an empty `docs/`, `shared/data` and
`build/` (with `app`, `obj/main.o` and a link `data -> ../shared`):

```text
$ build/rm -v notes.txt; echo $?
removed 'notes.txt'
0
$ build/rm build; echo $?
rm: cannot remove 'build': Is a directory
1
$ build/rm -rv build; echo $?
removed 'build/app'
removed 'build/data'
removed 'build/obj/main.o'
removed directory 'build/obj'
removed directory 'build'
0
$ build/rm -dv docs; echo $?
removed directory 'docs'
0
$ build/rm -f missing.txt; echo $?
0
$ build/rm missing.txt; echo $?
rm: cannot remove 'missing.txt': No such file or directory
1
$ build/rm -r .; echo $?
rm: refusing to remove '.' or '..' directory: skipping '.'
1
$ ls shared
data
```

The link `build/data` was removed; `shared/`, which it pointed to, was not
touched.

| Option | Meaning |
|---|---|
| `-f`, `--force` | ignore missing operands; succeed even with no operands |
| `-r`, `-R`, `--recursive` | remove directories and their contents |
| `-d`, `--dir` | remove empty directories |
| `-v`, `--verbose` | print `removed 'X'` / `removed directory 'X'` |
| `--preserve-root[=all]` | refuse to work recursively on `/` (the default) |
| `--no-preserve-root` | allow it |
| `--help`, `--version` | print help or the version and exit |

Options may appear anywhere and combine (`-rfv`); long options may be
abbreviated (`--rec`); `--` ends the options (`rm -- -f` removes a file
named `-f`).

Exit status: `0` if everything was removed (or skipped by `-f`), `1`
otherwise, usage errors included. rm reports a failure and carries on with
the rest.

## How it stays safe

Loup 1.26.0's `io.fs` has no `lstat()`, so a symbolic link to a directory
looks like the directory, and in the native build `io.fs.removeDir` is an
`rm -rf` that follows links. This program therefore:

- **unlinks every entry first.** That removes a file or a link of any kind
  without following it; only a real directory survives.
- **enters a directory only if `dir/..` lists the same names as the
  directory holding it.** The kernel resolves `link/..` to the parent of the
  link's target, so a link that survived unlinking (in a read-only
  directory) fails this test and is reported instead of followed.
- **calls `removeDir` only on a directory that lists empty**, after removing
  its entries itself.
- **refuses the root directory** by name (`/`, `//`, `/tmp/..`, made
  absolute with `$PWD`) and by nature (a directory that is its own parent
  and lists like `/`), for every operand and again before descending into
  any directory; and refuses `.` and `..` in any spelling (`d/..`, `./`).

These rules are pure functions with unit tests. The end-to-end tests build
their trees under `$TMP`, run two levels below it with relative names only,
and check sentinel files above the tree after every case; they never run rm
on `/`.

## Differences from GNU rm

- **No `-i`, `-I` or `--interactive`** (standard input can only be read
  whole in Loup 1.26.0), and no prompt for write-protected files (GNU
  prompts only when standard input is a terminal).
- Entries are removed in name order (GNU uses directory order), so `-v`
  lines can come in a different order.
- `--preserve-root=all` acts like `--preserve-root`: devices cannot be
  compared. No `--one-file-system`.
- A link to a *sibling* directory that cannot be unlinked (because its
  directory is read-only) cannot be told from a directory; with `-r` its
  target is emptied, as GNU would empty a real subdirectory there.
  `rm -r link/` on such a link ends with `Permission denied` rather than
  `Not a directory`.
- `rm -r link` where the link points to `/` is refused as the root; GNU
  removes the link.
- Error reasons are inferred, not read from the system: `Permission denied`
  whenever something that exists could not be removed.

## Layout

```text
source/main.loup              # entry point
source/appinfo.loup           # name, version, exit statuses
source/cli/args.loup          # GNU getopt_long-style option parsing
source/cli/usage.loup         # --help and --version text
source/cli/app.loup           # run(): parse, dispatch, exit status
source/commands/safety.loup   # the guards: . and .., the root directory (pure)
source/commands/rm.loup       # unlink first, trees, -d, -v, error collection
source/commands/fsinfo.loup   # entries, real directories and the root without lstat()
source/commands/quote.loup    # GNU-style quoting of names in messages
tests/*_test.loup             # unit tests (make test)
tests/e2e.sh                  # end-to-end tests of build/rm, confined to $TMP (make e2e)
specs/rm/                     # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.

## License

[MIT](LICENSE), copyright 2026 Code Craft AI LLC. The Loup skill in
[`skills/loup-programmer/`](skills/loup-programmer/) is copied from the Loup
project and is not covered by this license; it keeps the Loup project's terms.
