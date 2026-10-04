#!/usr/bin/env python3
"""Turns `flutter test --file-reporter=json:...` output into a short summary.

Usage: summarize_tests.py test-results.json > tests-summary.txt
"""
import json
import sys

tests = {}
errors = {}
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
by_suite = {}
for test_id in failures:
    suite, name = tests.get(test_id, ("?", "?"))
    by_suite.setdefault(suite, []).append((name, errors.get(test_id, [])))
for suite in sorted(by_suite):
    print(f"## {suite}")
    for name, errs in by_suite[suite]:
        print(f"- {name}")
        for err in errs[:1]:
            lines = [l for l in err.splitlines() if l.strip()][:6]
            for l in lines:
                print(f"    {l[:300]}")
    print()
for test_id in unfinished:
    suite, name = tests[test_id]
    print(f"UNFINISHED {suite}: {name}")
