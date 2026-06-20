#!/usr/bin/env python3
"""Inject the search box into the built LinuxCNC HTML docs.

For every page that carries the docs topbar this:
  - marks the topbar chrome with data-pagefind-ignore (so the nav, language
    switcher and search box are not indexed as page content),
  - inserts the search box (preferring the in-tree extension slot
    data-lcnc-slot="topbar-end" if present, else just before the language
    switcher),
  - adds a <link> to the injected search.css.

The page-relative path to the html root is computed per file and substituted
for the __LCNC_REL__ placeholder, so links work under any deployment prefix.
Idempotent: a page that already has the search box is left untouched.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(os.path.dirname(HERE), "assets")

HEADER_OPEN_RE = re.compile(r'<header\b[^>]*id="lcnc-topbar"[^>]*>')
SLOT_RE = re.compile(r'<div\b[^>]*data-lcnc-slot="topbar-end"[^>]*>\s*</div>')
LANG_SWITCHER_RE = re.compile(r'<div\b[^>]*class="[^"]*\blcnc-lang-switcher\b[^"]*"')


def rel_to_root(path, root):
    reldir = os.path.relpath(root, os.path.dirname(path))
    return "" if reldir == "." else reldir.replace(os.sep, "/") + "/"


def process(path, root, box_tmpl):
    with open(path, encoding="utf-8") as fh:
        html = fh.read()

    if "lcnc-topbar-search" in html:
        return False  # already injected
    if not HEADER_OPEN_RE.search(html) or "</head>" not in html:
        return False  # no topbar / not a full page

    rel = rel_to_root(path, root)
    box = box_tmpl.replace("__LCNC_REL__", rel)

    # 1. mark the topbar chrome as not-indexed
    def mark(m):
        tag = m.group(0)
        return tag if "data-pagefind-ignore" in tag else tag[:-1] + " data-pagefind-ignore>"
    html = HEADER_OPEN_RE.sub(mark, html, count=1)

    # 2. place the search box
    if SLOT_RE.search(html):
        html = SLOT_RE.sub(lambda _m: box, html, count=1)
    elif LANG_SWITCHER_RE.search(html):
        m = LANG_SWITCHER_RE.search(html)
        html = html[:m.start()] + box + "\n  " + html[m.start():]
    else:
        html = html.replace("</header>", box + "\n</header>", 1)

    # 3. link the search stylesheet
    link = '  <link rel="stylesheet" href="%ssearch.css">\n' % rel
    html = html.replace("</head>", link + "</head>", 1)

    with open(path, "w", encoding="utf-8") as fh:
        fh.write(html)
    return True


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "html"
    with open(os.path.join(ASSETS, "search-box.html"), encoding="utf-8") as fh:
        box_tmpl = fh.read().rstrip("\n")

    done = 0
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d != "_pagefind"]
        for name in filenames:
            if name.endswith(".html") and process(os.path.join(dirpath, name), root, box_tmpl):
                done += 1
    print("injected search box into %d pages" % done)


if __name__ == "__main__":
    main()
