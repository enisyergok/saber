#!/usr/bin/env python3
"""Turns `flutter test --file-reporter=json:...` output into a short summary.

Usage: summarize_tests.py test-results.json > tests-summary.txt
"""
import json
import sys

tests = {}
errors = {}
prints = {}
done = {}
suites = {}

with open(sys.argv[1], encoding="utf-8", errors="replace") as f:
    for line in f:
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            event = json.loads(line)
        except ValueError:
            continue
        kind = event.get("type")
        if kind == "suite":
            suites[event["suite"]["id"]] = event["suite"].get("path") or ""
        elif kind == "testStart":
            test = event["test"]
            tests[test["id"]] = (suites.get(test.get("suiteID"), ""), test["name"])
        elif kind == "error":
            errors.setdefault(event["testID"], []).append(event.get("error", ""))
        elif kind == "print":
            prints.setdefault(event.get("testID"), []).append(event.get("message", ""))
        elif kind == "testDone":
            done[event["testID"]] = event

passed = failed = skipped = 0
failures = []
for test_id, event in done.items():
    if event.get("hidden"):
        # Hidden entries are suite loaders; they only matter when they fail.
        if event.get("result") != "success":
            failures.append(test_id)
        continue
    if event.get("skipped"):
        skipped += 1
    elif event.get("result") == "success":
        passed += 1
    else:
        failed += 1
        failures.append(test_id)

unfinished = [t for t in tests if t not in done]

print(f"passed={passed} failed={failed} skipped={skipped} unfinished={len(unfinished)}")
print()


def exception_excerpt(test_id):
    """The first lines of the first framework exception printed by a test.

    Widget tests report "Test failed. See exception logs above." as their
    error; the useful part is in what they printed.
    """
    lines = "\n".join(prints.get(test_id, [])).splitlines()
    for i, line in enumerate(lines):
        if "EXCEPTION CAUGHT" in line:
            excerpt = []
            for l in lines[i + 1 : i + 40]:
                if l.startswith("When the exception was thrown") or l.startswith("#0"):
                    break
                if l.strip():
                    excerpt.append(l)
            return excerpt[:14]
    return []


by_suite = {}
for test_id in failures:
    suite, name = tests.get(test_id, ("?", "?"))
    by_suite.setdefault(suite, []).append((test_id, name))
for suite in sorted(by_suite):
    print(f"## {suite.split('/test/')[-1]}")
    for test_id, name in by_suite[suite]:
        print(f"- {name}")
        lines = exception_excerpt(test_id)
        if not lines:
            for err in errors.get(test_id, [])[:1]:
                lines = [l for l in err.splitlines() if l.strip()][:8]
        for l in lines:
            print(f"    {l[:240]}")
    print()
for test_id in unfinished:
    suite, name = tests[test_id]
    print(f"UNFINISHED {suite}: {name}")
