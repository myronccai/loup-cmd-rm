#!/usr/bin/env bash
# End-to-end tests: run the built binary on a fresh fixture tree for every
# case, and compare its standard output (byte for byte), standard error,
# exit status and the files left behind with the expected ones.
#
# Safety: everything happens under $TMP (a new mktemp directory). The cases
# run in $TMP/w/top, every operand is a relative name (run_case refuses an
# argument that starts with `/`), so even `..` stays inside $TMP. Sentinel
# files in $TMP and $TMP/w are checked at the end. The root-directory guard
# (--preserve-root) is covered by the unit tests, never by running rm on `/`.
#
# usage: tests/e2e.sh BINARY

set -u
BIN=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
TMP=$(mktemp -d)
trap 'chmod -R u+w "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT
TOP=$TMP/w/top
pass=0
fail=0
echo keep > "$TMP/sentinel"

# The fixture, rebuilt before every case, in $TOP:
#   a b            files
#   d/  x .h sub/y a directory to remove
#   e/             an empty directory
#   target/  t inner/i       the target of lnk
#   lnk -> target            a link to a sibling directory
#   outside/keep/k           the target of the links below
#   far -> outside/keep      a link to a directory elsewhere (`far/..` is outside)
#   nest/  n  tl -> ../target  far -> ../outside/keep
#   ro/f           in a read-only directory
#   roln/far -> ../outside/keep   a link in a read-only directory
#   dang -> nowhere
setup() {
    chmod -R u+w "$TMP/w" 2>/dev/null
    rm -rf "$TMP/w"
    mkdir -p "$TOP"
    echo keep > "$TMP/w/sentinel"
    cd "$TOP" || exit 1
    mkdir -p d/sub e target/inner outside/keep nest ro roln
    echo A > a
    echo B > b
    echo X > d/x
    echo H > d/.h
    echo Y > d/sub/y
    echo T > target/t
    echo I > target/inner/i
    echo K > outside/keep/k
    ln -s target lnk
    ln -s outside/keep far
    echo N > nest/n
    ln -s ../target nest/tl
    ln -s ../outside/keep nest/far
    echo F > ro/f
    chmod 555 ro
    ln -s ../outside/keep roln/far
    chmod 555 roln
    ln -s nowhere dang
}

# The files under PATHS... (relative to $TOP), one per line: `dir/`,
# `file: content` or `link -> target`.
snap() {
    (cd "$TOP" && find "$@" 2>/dev/null | LC_ALL=C sort | while IFS= read -r f; do
        if [ -L "$f" ]; then
            printf '%s -> %s\n' "$f" "$(readlink "$f")"
        elif [ -d "$f" ]; then
            printf '%s/\n' "$f"
        else
            printf '%s: %s\n' "$f" "$(cat "$f")"
        fi
    done)
}

# Whether the files above $TOP are still there.
sentinels_kept() {
    [ "$(cat "$TMP/sentinel" 2>/dev/null)" = keep ] && [ "$(cat "$TMP/w/sentinel" 2>/dev/null)" = keep ]
}

# run_case NAME STATUS EXPECTED_STDOUT EXPECTED_STDERR [ARGS...]
# Rebuilds the fixture, runs BINARY ARGS... in $TOP, and compares standard
# output, standard error (without its final newline) and the exit status.
run_case() {
    local name=$1 want_status=$2 want_out=$3 want_err=$4
    shift 4
    local arg
    for arg in "$@"; do
        case $arg in
            /*) echo "e2e.sh: refusing absolute argument '$arg' in '$name'"; exit 1 ;;
        esac
    done
    setup
    "$BIN" "$@" < /dev/null > "$TMP/out" 2> "$TMP/err"
    local status=$?
    printf '%s' "$want_out" > "$TMP/want"
    if ! sentinels_kept; then
        fail=$((fail + 1))
        echo "FAIL: $name removed a sentinel above the fixture"
    elif [ "$status" -eq "$want_status" ] && cmp -s "$TMP/want" "$TMP/out" \
        && [ "$(cat "$TMP/err")" = "$want_err" ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff "$TMP/want" "$TMP/out" | sed 's/^/    stdout /' | head -10
        [ "$(cat "$TMP/err")" = "$want_err" ] || {
            echo "    expected stderr: $want_err"
            sed 's/^/    actual stderr:   /' "$TMP/err" | head -5
        }
    fi
}

# tree_is NAME EXPECTED PATHS...
# Checks the files left by the last run_case.
tree_is() {
    local name=$1 want=$2
    shift 2
    local got
    got=$(snap "$@")
    if [ "$got" = "$want" ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (files)"
        diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /' | head -10
    fi
}

TARGET=$'target/\ntarget/inner/\ntarget/inner/i: I\ntarget/t: T'
OUTSIDE=$'outside/\noutside/keep/\noutside/keep/k: K'

# Files
run_case "one file"            0 '' '' a
tree_is  "one file"            'b: B' a b
run_case "-v"                  0 $'removed \'a\'\nremoved \'b\'\n' '' -v a b
run_case "missing"             1 '' "rm: cannot remove 'nope': No such file or directory" nope
run_case "-f missing"          0 '' '' -f nope
run_case "-f continues"        0 $'removed \'a\'\n' '' -fv nope a
run_case "missing continues"   1 $'removed \'a\'\n' "rm: cannot remove 'nope': No such file or directory" -v nope a
run_case "file with a slash"   1 '' "rm: cannot remove 'a/': Not a directory" a/
run_case "file in the path"    1 '' "rm: cannot remove 'a/x': Not a directory" a/x
run_case "empty name"          1 '' "rm: cannot remove '': No such file or directory" ''
run_case "-- ends options"     1 '' "rm: cannot remove '-f': No such file or directory" -- -f
run_case "read-only directory" 1 '' "rm: cannot remove 'ro/f': Permission denied" ro/f
tree_is  "read-only directory" 'ro/f: F' ro/f

# Directories
run_case "directory"           1 '' "rm: cannot remove 'd': Is a directory" d
tree_is  "directory kept"      $'d/\nd/.h: H\nd/sub/\nd/sub/y: Y\nd/x: X' d
run_case "-d not empty"        1 '' "rm: cannot remove 'd': Directory not empty" -d d
run_case "-d empty"            0 $'removed directory \'e\'\n' '' -dv e
tree_is  "-d empty"            '' e
run_case "-r"                  0 '' '' -r d
tree_is  "-r"                  '' d
run_case "-rv" 0 $'removed \'d/.h\'\nremoved \'d/sub/y\'\nremoved directory \'d/sub\'\nremoved \'d/x\'\nremoved directory \'d\'\n' '' -rv d
run_case "-R slash" 0 $'removed \'d/.h\'\nremoved \'d/sub/y\'\nremoved directory \'d/sub\'\nremoved \'d/x\'\nremoved directory \'d/\'\n' '' -Rv d/
run_case "-r mixed" 1 $'removed \'a\'\nremoved \'d/.h\'\nremoved \'d/sub/y\'\nremoved directory \'d/sub\'\nremoved \'d/x\'\nremoved directory \'d\'\nremoved directory \'e\'\n' "rm: cannot remove 'nope': No such file or directory" -rv a nope d e
run_case "-r read-only"        1 '' "rm: cannot remove 'ro/f': Permission denied" -rf ro
tree_is  "-r read-only"        $'ro/\nro/f: F' ro

# Symbolic links are removed, never followed
run_case "dangling link"       0 $'removed \'dang\'\n' '' -v dang
run_case "link to a directory" 0 $'removed \'lnk\'\n' '' -v lnk
tree_is  "link: target kept"   "$TARGET" target
run_case "-r link"             0 $'removed \'lnk\'\n' '' -rv lnk
tree_is  "-r link: target kept" "$TARGET" target
run_case "-d link"             0 '' '' -d lnk
tree_is  "-d link: target kept" "$TARGET" target
run_case "-r tree with links"  0 $'removed \'nest/far\'\nremoved \'nest/n\'\nremoved \'nest/tl\'\nremoved directory \'nest\'\n' '' -rv nest
tree_is  "-r tree: targets kept" "$OUTSIDE"$'\n'"$TARGET" outside target
run_case "link in read-only dir" 1 '' "rm: cannot remove 'roln/far': Permission denied" -rf roln
tree_is  "link in read-only dir: target kept" "$OUTSIDE" outside
run_case "link slash"          1 '' "rm: cannot remove 'lnk/': Is a directory" lnk/
run_case "-d link slash"       1 '' "rm: cannot remove 'lnk/': Directory not empty" -d lnk/
# With a trailing slash the link is followed, as in GNU rm: the target is
# emptied, then the link itself cannot be removed as a directory.
run_case "-r far/" 1 $'removed \'far/k\'\n' "rm: cannot remove 'far/': Not a directory" -rv far/
tree_is  "-r far/"             $'far -> outside/keep\noutside/\noutside/keep/' far outside

# . and ..
run_case "-r dots" 1 '' "rm: refusing to remove '.' or '..' directory: skipping '.'
rm: refusing to remove '.' or '..' directory: skipping '..'
rm: refusing to remove '.' or '..' directory: skipping 'd/..'
rm: refusing to remove '.' or '..' directory: skipping 'd/.'
rm: refusing to remove '.' or '..' directory: skipping './'" -rf . .. d/.. d/. ./
tree_is  "-r dots: nothing removed" $'a: A\nd/\nd/.h: H\nd/sub/\nd/sub/y: Y\nd/x: X' a d
run_case "-d dot"              1 '' "rm: cannot remove '.': Directory not empty" -d .
run_case "dot"                 1 '' "rm: cannot remove '.': Is a directory" .

# Options
run_case "--no-preserve-root"  0 '' '' -r --no-preserve-root d
run_case "--preserve-root=all" 0 '' '' -r --preserve-root=all d
run_case "bad --preserve-root" 1 '' "rm: unrecognized --preserve-root argument: 'x'" --preserve-root=x a
run_case "no operands"         1 '' $'rm: missing operand\nTry \'rm --help\' for more information.'
run_case "-f no operands"      0 '' '' -f
run_case "-i (not supported)"  1 '' $'rm: invalid option -- \'i\'\nTry \'rm --help\' for more information.' -i a
tree_is  "-i removes nothing"  'a: A' a
run_case "unknown option"      1 '' $'rm: unrecognized option \'--bogus\'\nTry \'rm --help\' for more information.' --bogus
run_case "long prefix"         0 '' '' --rec d
run_case "version"             0 $'rm (loup-cmd-rm) 0.1.0\n' '' --version
"$BIN" --help | head -1 > "$TMP/help"
if [ "$(cat "$TMP/help")" = "Usage: rm [OPTION]... [FILE]..." ]; then
    pass=$((pass + 1))
else
    fail=$((fail + 1))
    echo "FAIL: --help first line: $(cat "$TMP/help")"
fi

# Nothing above $TOP was touched.
if sentinels_kept; then
    pass=$((pass + 1))
else
    fail=$((fail + 1))
    echo "FAIL: a sentinel above the fixture was removed"
fi

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
