# AGENTS.md

This repository recreates GNU `rm` in the Loup programming language, as part
of the loup-cmd series of example applications. The program is `host.dual`
Loup built as a native executable.

## Skills

| Skill | Location | Use it when |
|-------|----------|-------------|
| `loup-programmer` | [skills/loup-programmer/SKILL.md](skills/loup-programmer/SKILL.md) | Writing, reviewing, debugging or explaining Loup code: `.lpscr`, `.loup`, `.lphc`, `.lpweb` or `.lpfree` source files, `.lppkg` manifests, `@mode(...)` directives, or the `loup` / `loup-bootstrap` commands. |

Read `skills/loup-programmer/SKILL.md` before writing or changing any Loup code
in this repository. It links to detailed references under
`skills/loup-programmer/references/` for syntax, types and ownership, execution
modes and projects, errors and diagnostics, the standard library, and common
mistakes. Load those only as needed.

## Code layout

```text
.
├── package.lppkg                # Loup manifest: name, version, toolchain, [build] entry, [test] pattern
├── Makefile                     # run, check, test, build, e2e, ci, clean
├── source/                      # all Loup code; modules import each other by path from here
│   ├── main.loup                # entry point: func main() calls run(runtime.args())
│   ├── appinfo.loup             # APP_NAME, APP_VERSION, APP_SUMMARY, exit statuses
│   ├── cli/
│   │   ├── args.loup            # struct Options, parse_args(): GNU getopt_long rules
│   │   ├── usage.loup           # usage(), version_line()
│   │   └── app.loup             # run(): parse, --help/--version, run_rm, exit status
│   └── commands/
│       ├── safety.loup          # refusal(), dot_operand_error(): the guards, pure
│       ├── rm.loup              # remove_operands(), remove_entry(), remove_tree(), run_rm()
│       ├── fsinfo.loup          # entry_present(), is_real_dir(), is_root_dir(): without lstat()
│       └── quote.loup           # quote(): names in messages
├── tests/
│   ├── *_test.loup              # unit tests: func test_*(): void (rm_test writes under .temp/)
│   └── e2e.sh                   # end-to-end tests of the native binary, confined to $TMP
├── specs/rm/                    # requirements.md, design.md, tasks.md
├── skills/loup-programmer/      # the Loup skill and its references
├── .github/workflows/ci.yml     # installs Loup and runs `make ci`
└── build/                       # build output (git-ignored)
```

## Build, run and test

Prerequisites: Loup 1.26.0 (`loup` and `loup-bootstrap` on `PATH`), `make`,
and `clang` 17 or later for native builds.

Loup Lite comes from <https://github.com/code-craft-ai-company/loup-releases>;
[README.md](README.md#installing-loup-lite) has the install commands.

| Task | Command | Notes |
|------|---------|-------|
| Run from source | `make run ARGS="-rv build/scratch"` | `loup run source/main.loup -- ARGS` |
| Type-check | `make check` | checks `source/main.loup` and every module it imports; tests are not checked |
| Run all tests | `make test` | every `tests/*_test.loup` |
| Run matching tests | `make test TEST_ARGS="--filter value"` | tests whose name contains `value` |
| Run one test file | `make test TEST_ARGS="--file tests/args_test.loup"` | |
| Build | `make build` | native binary at `build/rm` |
| Run the binary | `build/rm --help` | |
| End-to-end tests | `make e2e` | runs `tests/e2e.sh build/rm`: output compared byte for byte |
| Everything CI runs | `make ci` | check, test, build, e2e, then `build/rm --version` |
| Clean | `make clean` | removes `build/` and `.temp/` |

Run `make ci` before reporting a change as done. `loup run` and the native
build do not support the same things, so a change can pass `make test` and
still fail `make build`.

Do not call `loup test` or `loup check` directly on Linux x86-64. There `loup`
is the self-hosted driver: it refuses `check`, and its test runner cannot
resolve this project's imports. The Makefile uses `loup-bootstrap` (Stage0) for
both, and sets `LOUPPATH=source` for tests.

## Making a change

1. Update the spec in `specs/rm/` (see [specs/README.md](specs/README.md)).
2. Change the code under `source/`.
3. Add or update unit tests in `tests/` and cases in `tests/e2e.sh`.
4. Run `make ci`.
5. Tick the finished tasks in `specs/rm/tasks.md`.

Keep behaviour in functions that return values (`refusal` returns the
messages, `remove_operands` an `Outcome` with the -v lines, messages and
exit status) so unit tests can check it; only `run_rm` prints.

## Safety rules for this repository

- Never follow a symbolic link: unlink an entry first, and enter a directory
  only if it survived unlinking and `is_real_dir` agrees (README: "How it
  stays safe"). Do not replace this with `isDir` alone.
- Never call `io.fs.removeDir` on a directory that is not empty: in the
  native build it is an `rm -rf` that follows links.
- Tests may only name paths under `$TMP` (e2e) or `.temp/rm-unit/` (unit
  tests). Never run the binary on `/` or on an absolute path in a test; the
  root guard is tested through `refusal` and `is_root_dir`, which do not
  delete anything.

## Conventions

- Every source file is `@mode(host.dual)` with the `.loup` extension. Only
  `source/main.loup` has a `main()`.
- Modules import each other by path from `source/`:
  `from cli.args import (Options);`. Tests import them the same way. Do not
  use relative imports (`from .args import ...`): the self-hosted `loup run`
  on Linux x86-64 fails on them.
- Struct fields read from another module must be `pub`.
- The native build supports less than `loup run` does. For example,
  `list.is_empty()` fails native codegen (`E-CODEGEN-UNHANDLED-METHOD`); use
  `len() == 0`.
- Keep `APP_VERSION` in `source/appinfo.loup` equal to `version` in
  `package.lppkg`.
- The native `io.fs` never throws (`remove` and `removeDir` fail silently),
  so every removal is verified by looking for the entry afterwards; the
  Stage0 interpreter used by `make test` throws `IoError`, so calls are
  wrapped in `try`.
- Do not name a function after a libc function the runtime calls (`unlink`,
  `rename`, `open`, `stat`, ...): natively it captures the runtime's call (a
  helper named `unlink` made every removal segfault). Do not import `rename`
  from `io.fs` for the same reason.
- Under the self-hosted `loup run` (`make run`), `io.fs.remove` runs the
  system `rm`, which prints its own message when it meets a directory.
- Read the environment with the prelude `env("NAME")`; `system.env.get` and
  the `system.text` functions do not link natively.
- The skill's examples use the `loup init` layout (`src/`, `tests/`, and
  `from ..src.x import` in tests). This project uses `source/` and
  `tests/` with plain imports; follow this file.
- The skill documents toolchain 1.25.1; this template targets 1.26.0. When
  they disagree, trust the toolchain's behaviour.
