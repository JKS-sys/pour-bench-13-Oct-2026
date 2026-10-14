#!/usr/bin/env python3
"""Paste the newest results/<date>/benchmark.md into README.md between the markers."""
import glob, re, os
runs = sorted(glob.glob("results/*/benchmark.md"))
if not runs: raise SystemExit("no results yet")
latest = open(runs[-1]).read()
body = latest.split("\n", 1)[1].strip()  # drop the H1
readme = open("README.md").read()
new = re.sub(r"<!-- results:start -->.*?<!-- results:end -->", f"<!-- results:start -->\n{body}\n<!-- results:end -->", readme, flags=re.S)
open("README.md", "w").write(new)
print("README updated from", runs[-1])
