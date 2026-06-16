#!/usr/bin/env python3
"""
detect-capabilities.py — the brain of the license-aware installer.

For each agent in agents.json, checks that every requiredObject actually EXISTS in the
target org (the real capability test — a license can be present while the backing object
or managed package is not). Prints a human-readable eligibility table to stderr, and the
list of eligible agent ids (one per line) to stdout so install.sh can consume it.

Usage:
  python3 scripts/detect-capabilities.py [org-alias-or-username]
"""
import json, subprocess, sys, os

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLAN = "--plan" in sys.argv[1:]
positional = [a for a in sys.argv[1:] if not a.startswith("--")]
ORG = positional[0] if positional else None

def err(*a): print(*a, file=sys.stderr)

with open(os.path.join(HERE, "agents.json")) as f:
    catalog = json.load(f)
agents = catalog["agents"]

def query(soql):
    cmd = ["sf", "data", "query", "--use-tooling-api", "--json", "-q", soql]
    if ORG:
        cmd += ["-o", ORG]
    out = subprocess.run(cmd, capture_output=True, text=True, cwd=HERE)
    return json.loads(out.stdout).get("result", {}).get("records", [])

# every object any agent cares about (required + optional), plus any LIKE patterns
wanted = set()
like_patterns = set()
for a in agents:
    wanted.update(a.get("requiredObjects", []))
    wanted.update(a.get("optionalObjects", []))
    like_patterns.update(a.get("requiredObjectsLike", []))

err("==> Detecting org capabilities%s ..." % (" for %s" % ORG if ORG else ""))
try:
    present = set()
    if wanted:
        in_list = ",".join("'%s'" % o for o in sorted(wanted))
        present = {r["QualifiedApiName"] for r in query(
            "SELECT QualifiedApiName FROM EntityDefinition WHERE QualifiedApiName IN (%s)" % in_list)}
    # which LIKE patterns have at least one matching entity
    like_satisfied = set()
    for pat in sorted(like_patterns):
        rows = query("SELECT QualifiedApiName FROM EntityDefinition WHERE QualifiedApiName LIKE '%s' LIMIT 1" % pat)
        if rows:
            like_satisfied.add(pat)
except Exception as e:
    err("ERROR: could not query the org. Is it authenticated? (%s)" % e)
    sys.exit(2)

err("")
err("  %-26s %-9s  %s" % ("AGENT", "STATUS", "DETAIL"))
err("  " + "-" * 78)
eligible = []
for a in agents:
    req = a.get("requiredObjects", [])
    missing = [o for o in req if o not in present]
    missing += ["matching:%s" % p for p in a.get("requiredObjectsLike", []) if p not in like_satisfied]
    opt_present = [o for o in a.get("optionalObjects", []) if o in present]
    if not missing:
        eligible.append(a["id"])
        extra = (" +optional: " + ", ".join(opt_present)) if opt_present else ""
        err("  %-26s %-9s  ready%s" % (a["id"], "ELIGIBLE", extra))
    else:
        err("  %-26s %-9s  missing: %s" % (a["id"], "skip", ", ".join(missing)))
err("  " + "-" * 78)
err("  %d of %d agents are installable in this org." % (len(eligible), len(agents)))
err("")

# stdout = machine-readable output the installer consumes
by_id = {a["id"]: a for a in agents}
for aid in eligible:
    a = by_id[aid]
    if not PLAN:
        print(aid)
        continue
    # build the --metadata list: ApexClass for each class + test, CustomField for each field, the PermissionSet
    meta = []
    for c in a.get("classes", []) + a.get("testClasses", []):
        meta.append("ApexClass:%s" % c)
    for fld in a.get("fields", []):
        meta.append("CustomField:%s" % fld)
    if a.get("permissionSet"):
        meta.append("PermissionSet:%s" % a["permissionSet"])
    # id | bundle | permissionSet | seed | space-separated metadata
    print("|".join([
        aid,
        a.get("bundle", ""),
        a.get("permissionSet", ""),
        a.get("seed", ""),
        " ".join(meta),
    ]))
