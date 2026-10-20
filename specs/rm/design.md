# Design: rm

## Overview

`main()` passes `runtime.args()` to `cli.app.run`, which parses the
arguments into `Options`, handles `--help` and `--version`, and calls
`commands.rm.run_rm`. `run_rm` asks `remove_operands` for an `Outcome` (the
-v lines, the error messages, the exit status and whether a usage error
wants the "Try" line) and prints it.

## Modules

| Module | Contents |
|---|---|
| `source/cli/args.loup` | `Options`, `parse_args` (getopt_long rules), `match_long` |
| `source/cli/usage.loup` | `usage()`, `version_line()` |
| `source/cli/app.loup` | `run()`, `wants_try()` |
| `source/commands/safety.loup` | `last_component`, `is_dot_or_dotdot`, `refusal`, `dot_operand_error`: the operand guards, pure |
| `source/commands/rm.loup` | `Outcome`, `Context`, `remove_operands`, `remove_entry`, `remove_tree`, `run_rm` |
| `source/commands/fsinfo.loup` | `entry_present`, `is_real_dir`, `is_root_dir`, `absolute`, `missing_reason`, `sorted_names`, `names_key` |
| `source/commands/quote.loup` | `quote()`: GNU's quoting of names in messages |

### Never following a link

`io.fs` has no `lstat`: `isDir` is true for a link to a directory. So every
entry is first **unlinked** with `io.fs.remove`, which removes a file or a
link of any kind and leaves a real directory alone. Only an entry that is
still there afterwards and is a directory is a directory candidate, and it
is entered only if `is_real_dir` agrees: `dir/..` must list the same names
as the directory holding `dir` (the kernel resolves `link/..` to the parent
of the link's *target*). Anything else that survived unlinking is reported
as `Permission denied` and left alone, so a link in a read-only directory
is never followed.

The one case the `..` test cannot settle is a link to a *sibling* directory
that could not be unlinked (its directory is read-only); see Differences.

### Removing a directory

`io.fs.removeDir` is an `rm -rf` that, in the native build, follows links.
rm calls it only on a directory that `listDir` shows empty, after removing
the entries itself; then it amounts to `rmdir`.

### The root directory

`is_root_dir` is true when the path normalises to `/` (made absolute with
`$PWD`), or when it is a directory that lists like `/` and whose `..` lists
like itself: the root is the only directory that is its own parent. It is
checked for every operand (with -r) and again before descending into any
directory. The e2e tests never run rm on `/`; the guard's rules are unit
tests on `refusal` with the fact passed in, and on `is_root_dir`, which only
looks.

## Differences from GNU rm

- No `-i`, `-I` or `--interactive` (T2: standard input can only be read
  whole), and no prompt for write-protected files; GNU prompts only when
  standard input is a terminal.
- Entries are removed in name order; GNU uses directory order, so -v lines
  can come in a different order.
- `--preserve-root=all` is accepted but acts like `--preserve-root` (devices
  cannot be compared); `--one-file-system` is not supported.
- A link to a sibling directory that cannot be unlinked (its directory is
  read-only) cannot be told from a directory: with -r its target is emptied
  as GNU would empty a real subdirectory there. For `rm -r link/` (a link to
  a sibling) the final message is `Permission denied` instead of `Not a
  directory`.
- `rm -r link` where the link points to `/` is refused as the root
  directory; GNU removes the link.
- Error reasons are inferred, not read from `errno`: `Permission denied`
  whenever something that exists could not be removed.

## Error handling

Every removal is checked by looking for the entry afterwards, because the
native `io.fs` reports nothing, while the Stage0 interpreter used by `make
test` throws `IoError` (caught and treated the same way). Failures are
collected; rm continues with the other entries and operands and exits 1.

## Testing

- `tests/safety_test.loup`: every guard (`.`/`..` spellings, root by name
  and by being its own parent, the --no-preserve-root override),
  `entry_present`.
- `tests/rm_test.loup`: removals under `.temp/rm-unit/`.
- `tests/args_test.loup`, `tests/app_test.loup`: options and exit statuses.
- `tests/e2e.sh`: a fixture under `$TMP` rebuilt for every case, run from
  two levels below `$TMP`, absolute arguments refused by the harness, and
  sentinels above the fixture checked after every case. It covers links
  (dangling, to a sibling, elsewhere, inside a tree, inside a read-only
  directory) whose targets must survive.
