#!/usr/bin/env python3
"""Zip the addon like CurseForge's packager, for the GitHub release (.github/workflows/release.yml).

    python3 tools/package.py 0.3.0-alpha        # -> dist/Craftbound-0.3.0-alpha.zip
    python3 tools/package.py 0.3.0-alpha --notes  # print that version's CHANGELOG section

Takes the git-tracked files, leaves out .pkgmeta's ignore list, puts them in a folder named by
package-as and writes the version into the .toc (@project-version@). Locally, `wowbench pack`
does the same.
"""
import os
import re
import subprocess
import sys
import zipfile

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))


def pkgmeta():
    name, ignore, section = None, [], None
    for line in open(os.path.join(ROOT, ".pkgmeta"), encoding="utf-8"):
        line = line.split("#", 1)[0].rstrip()
        if not line:
            continue
        m = re.match(r"^(\S[^:]*):\s*(.*)$", line)
        if m:
            section = m.group(1)
            if section == "package-as":
                name = m.group(2).strip()
            continue
        m = re.match(r"^\s*-\s*(.+)$", line)
        if m and section == "ignore":
            ignore.append(m.group(1).strip().rstrip("/"))
    return name, ignore


def ignored(path, ignore):
    return any(path == i or path.startswith(i + "/") for i in ignore) or path.startswith(".")


def notes(version):
    log = open(os.path.join(ROOT, "CHANGELOG.md"), encoding="utf-8").read()
    m = re.search(r"(?ms)^## %s\b[^\n]*\n(.*?)(?=^## |\Z)" % re.escape(version), log)
    if not m:
        sys.exit("CHANGELOG.md has no '## %s' section." % version)
    return m.group(1).strip()


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    version = sys.argv[1].lstrip("v")
    if "--notes" in sys.argv:
        print(notes(version))
        return
    notes(version)  # a release without its changelog is a mistake: stop here
    name, ignore = pkgmeta()
    files = subprocess.run(["git", "ls-files"], cwd=ROOT, capture_output=True, text=True,
                           check=True).stdout.split("\n")
    os.makedirs(os.path.join(ROOT, "dist"), exist_ok=True)
    out = os.path.join(ROOT, "dist", "%s-%s.zip" % (name, version))
    n = 0
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for f in sorted(x for x in files if x and not ignored(x, ignore)):
            data = open(os.path.join(ROOT, f), "rb").read()
            if f.endswith(".toc"):
                data = data.replace(b"@project-version@", version.encode())
            z.writestr("%s/%s" % (name, f), data)
            n += 1
    print("%s (%d files)" % (os.path.relpath(out, ROOT), n))


if __name__ == "__main__":
    main()
