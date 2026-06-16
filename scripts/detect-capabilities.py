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

def query(soql, tooling=True):
    cmd = ["sf", "data", "query", "--json", "-q", soql]
    if tooling:
        cmd.append("--use-tooling-api")
    if ORG:
        cmd += ["-o", ORG]
    out = subprocess.run(cmd, capture_output=True, text=True, cwd=HERE)
    return json.loads(out.stdout).get("result", {}).get("records", [])

# every object any agent cares about (required + optional), plus any LIKE patterns + licenses
wanted = set()
like_patterns = set()
need_licenses = set()
for a in agents:
    wanted.update(a.get("requiredObjects", []))
    wanted.update(a.get("optionalObjects", []))
    like_patterns.update(a.get("requiredObjectsLike", []))
    need_licenses.update(a.get("requiredLicenses", []))

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
    # active feature licenses (the reliable signal for clouds whose objects aren't in EntityDefinition, e.g. Data Cloud)
    active_licenses = set()
    if need_licenses:
        lin = ",".join("'%s'" % l for l in sorted(need_licenses))
        for r in query("SELECT MasterLabel FROM PermissionSetLicense WHERE Status = 'Active' AND MasterLabel IN (%s)" % lin, tooling=False):
            active_licenses.add(r["MasterLabel"])
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
    missing += ["license:%s" % l for l in a.get("requiredLicenses", []) if l not in active_licenses]
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
    # id | mode | bundle | permissionSet | seed-or-schedule | space-separated metadata
    print("|".join([
        aid,
        a.get("mode", "agent"),
        a.get("bundle", ""),
        a.get("permissionSet", ""),
        a.get("schedule", "") if a.get("mode") == "headless" else a.get("seed", ""),
        " ".join(meta),
    ]))
