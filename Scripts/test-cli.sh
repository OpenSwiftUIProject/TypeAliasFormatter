#!/bin/bash
set -euo pipefail

cli=${1:?Usage: bash Scripts/test-cli.sh /path/to/typealias-formatter}
repo_dir=$(cd "$(dirname "$0")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

printf 'Pair<\n    A,\n    B\n>\n' > "$test_dir/expected.txt"
printf 'typealias Body = Pair<A, B>\n' | "$cli" > "$test_dir/stdout.txt"
cmp "$test_dir/expected.txt" "$test_dir/stdout.txt"

printf 'Box<\n\tValue\n>\n' > "$test_dir/expected.txt"
printf 'Box<Value>\n' | "$cli" - --indent tab --expand-generics -o - > "$test_dir/stdout.txt"
cmp "$test_dir/expected.txt" "$test_dir/stdout.txt"

fixtures="$repo_dir/Packages/TypeAliasFormatterCore/Tests/TypeAliasFormatterCoreTests/Fixtures"
"$cli" "$fixtures/ResolvedLabelStyle.txt" -o "$test_dir/fixture.txt"
cmp "$fixtures/ResolvedLabelStyle.formatted.txt" "$test_dir/fixture.txt"

printf 'Pair<A, B>\n' | "$cli" --format graph > "$test_dir/graph.svg"
xmllint --noout "$test_dir/graph.svg"

if printf 'Pair<A, B\n' | "$cli" > "$test_dir/stdout.txt" 2> "$test_dir/stderr.txt"; then
    echo 'Invalid input must fail.' >&2
    exit 1
fi
test ! -s "$test_dir/stdout.txt"
grep -Fq "Missing closing '>'." "$test_dir/stderr.txt"

if "$cli" --indent 3 </dev/null > "$test_dir/stdout.txt" 2> "$test_dir/stderr.txt"; then
    echo 'Invalid arguments must fail.' >&2
    exit 1
fi
test ! -s "$test_dir/stdout.txt"
test -s "$test_dir/stderr.txt"

"$cli" --help > "$test_dir/help.txt"
grep -Fq 'USAGE: typealias-formatter' "$test_dir/help.txt"
echo 'CLI integration checks passed.'
