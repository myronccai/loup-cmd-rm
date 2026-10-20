# Requirements: rm

## Introduction

`rm` removes files, and with options directories. This repository recreates
GNU coreutils `rm` in Loup: `-r`/`-R`, `-d`, `-f`, `-v`, the root-directory
failsafe (`--preserve-root`, the default, and `--no-preserve-root`) and the
refusal to remove `.` and `..`. The interactive options `-i` and `-I` are
deferred: Loup 1.26.0 can only read standard input whole (T2). The safety
rules are explicit checks with their own tests.

## Requirements

### Requirement 1: Files and missing operands

**User Story:** As a shell user, I want to remove files and be told about the
ones that are not there.

#### Acceptance Criteria

1. THE program SHALL remove each operand that is a file or a symbolic link
   (of any kind, including dangling), never following the link.
2. WHEN an operand does not exist, THE program SHALL print `rm: cannot
   remove 'X': No such file or directory` (`Not a directory` when a component
   is a file, as in `file/`), continue with the others, and exit with 1.
3. WHEN -f is given, THE program SHALL say nothing about missing operands,
   and SHALL succeed with no operands at all.
4. WHEN there are no operands and no -f, THE program SHALL print `missing
   operand` and the "Try" line and exit with 1.
5. WHEN an entry cannot be removed (its directory is read-only), THE program
   SHALL print `cannot remove 'X': Permission denied`.

### Requirement 2: Directories

**User Story:** As a shell user, I want directories removed only when I ask.

#### Acceptance Criteria

1. WHEN an operand is a directory and neither -r nor -d is given, THE program
   SHALL print `cannot remove 'X': Is a directory` and keep it.
2. WHEN -d is given, THE program SHALL remove an empty directory and report
   `Directory not empty` for any other.
3. WHEN -r is given, THE program SHALL remove the directory's entries depth
   first, then the directory; if any entry cannot be removed, the directory
   SHALL be kept without a further message.
4. Inside a tree, THE program SHALL remove symbolic links themselves and
   SHALL NOT descend into the directories they point to.
5. WHEN a directory operand is named with a trailing slash and is a link to a
   directory, THE program SHALL follow it like GNU rm (emptying the target
   with -r) and report that the link itself cannot be removed as a directory.

### Requirement 3: Safety guards

**User Story:** As a shell user, I want rm to refuse the mistakes that cannot
be undone.

#### Acceptance Criteria

1. WHEN -r is given and an operand's last component is `.` or `..` (`.`,
   `d/..`, `./`), THE program SHALL print `refusing to remove '.' or '..'
   directory: skipping 'X'` and remove nothing of it.
2. WHEN -r is given without --no-preserve-root and an operand is the root
   directory (by name, such as `/`, `//`, `/tmp/..`, or by being its own
   parent and listing like `/`), THE program SHALL print `it is dangerous to
   operate recursively on '/'` (or `on 'X' (same as '/')`) and `use
   --no-preserve-root to override this failsafe`, and skip it.
3. THE program SHALL check for the root directory again before descending
   into any directory.
4. WHEN a `.` or `..` operand is given without -r, THE program SHALL never
   remove it (`Is a directory`, or with -d `Directory not empty` /
   `Invalid argument`).

### Requirement 4: Reporting and options

**User Story:** As a script author, I want GNU's output and option syntax.

#### Acceptance Criteria

1. WHEN -v is given, THE program SHALL print `removed 'X'` for each file or
   link and `removed directory 'X'` for each directory.
2. THE program SHALL accept options anywhere among the operands, combined
   short options, `--` to end options, and the long options `--force`,
   `--recursive`, `--dir`, `--verbose`, `--preserve-root[=all]`,
   `--no-preserve-root`, `--help` and `--version`, abbreviated to any
   unambiguous prefix.
3. WHEN an option is unknown (including `-i` and `-I`), THE program SHALL
   print GNU's message and the "Try" line and exit with 1; a bad
   `--preserve-root` argument SHALL print `unrecognized --preserve-root
   argument: 'X'` without it.
4. THE program SHALL exit with 0 when everything was removed (or skipped by
   -f) and 1 otherwise.
