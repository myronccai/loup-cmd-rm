# Tasks: rm

- [x] 1. Parse GNU options: `-f -r -R -d -v`, `--preserve-root[=all]`,
      `--no-preserve-root`, long prefixes, `--`, permutation
  - _Requirements: 4.2, 4.3_
- [x] 2. Guards as pure functions: `.`/`..`, the root directory, dot
      operands without -r
  - _Requirements: 3.1, 3.2, 3.4_
- [x] 3. Remove files and links by unlinking; missing operands and -f
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_
- [x] 4. Directories: -d, -r depth first, never entering links, root check
      before descending, removeDir only on empty directories
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 3.3_
- [x] 5. -v lines and exit statuses
  - _Requirements: 4.1, 4.4_
- [x] 6. Unit tests and end-to-end tests of the native binary, confined to
      `$TMP`
  - _Requirements: all_
