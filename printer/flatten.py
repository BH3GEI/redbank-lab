#!/usr/bin/env python3
"""Flatten a BambuStudio preset json (resolve `inherits` chain) and apply overrides."""
import json, sys, os

BASE = "/Applications/BambuStudio.app/Contents/Resources/profiles/BBL"
KIND_DIR = {"machine": "machine", "process": "process", "filament": "filament"}

def load_chain(kind, name):
    path = os.path.join(BASE, KIND_DIR[kind], name + ".json")
    with open(path) as f:
        d = json.load(f)
    parent = d.pop("inherits", None)
    incs = d.pop("include", [])
    base = load_chain(kind, parent) if parent else {}
    # BambuStudio "include": template files (start/end gcode etc.) merged before own keys
    for inc in incs:
        t = json.load(open(os.path.join(BASE, KIND_DIR[kind], inc + ".json")))
        for k in ("name", "instantiation", "inherits", "include"): t.pop(k, None)
        base.update(t)
    base.update(d)
    return base

if __name__ == "__main__":
    kind, name, out = sys.argv[1], sys.argv[2], sys.argv[3]
    overrides = json.loads(sys.argv[4]) if len(sys.argv) > 4 else {}
    d = load_chain(kind, name)
    d.update(overrides)
    d["name"] = name
    json.dump(d, open(out, "w"), indent=1)
    print(out, "ok,", len(d), "keys")
