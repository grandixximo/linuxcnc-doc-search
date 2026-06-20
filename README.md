# linuxcnc-doc-search

Adds in-browser search to the [LinuxCNC](https://github.com/LinuxCNC/linuxcnc)
HTML documentation, as a **post-processing step that lives outside the LinuxCNC
source tree**.

The LinuxCNC build stays minimalist and pulls in nothing extra: it just leaves
a generic extension point in the docs topbar. This project takes the docs that
LinuxCNC CI already produces, builds a pagefind search
index, plugs the search box into that extension point, and emits the result as
a downloadable artifact. Nothing here runs during the LinuxCNC build.

## How it works

1. Download the `linuxcnc-doc` artifact (the built `html/` tree) from
   LinuxCNC CI.
2. `scripts/inject.py` adds, to every page that carries the topbar:
   - `data-pagefind-ignore` on the topbar so the nav/switcher/search box are
     not indexed as content,
   - the search box (into the in-tree slot `data-lcnc-slot="topbar-end"` if
     present, otherwise just before the language switcher),
   - a `<link>` to `search.css`.
   The page-relative path to the html root is computed per file, so links work
   under any deployment prefix.
3. `pagefind` builds one isolated index per language subtree
   (`en/_pagefind`, `de/_pagefind`, ...), so results stay in the page's own
   language.
4. The search-enabled `html/` tree is uploaded as the `linuxcnc-doc-search`
   artifact.

Search is a progressive enhancement: with JavaScript disabled the docs are
unchanged and fully usable.

## Running it

In CI: `.github/workflows/build.yml` runs weekly and on demand. It needs a
secret **`SOURCE_TOKEN`** to read LinuxCNC's Actions artifacts: a classic
personal access token with the `public_repo` scope. The repo's default
`GITHUB_TOKEN` cannot read another repository's artifacts, and a fine-grained
PAT cannot grant Actions read on a repo you do not own.

Locally, against an extracted `html/` tree:

```sh
./scripts/build.sh html      # fetches the pinned pagefind binary if needed
```

Then serve `html/` over HTTP (search needs `fetch`, not `file://`):

```sh
python3 -m http.server -d html 8000
```

## The in-tree contract

The only thing LinuxCNC needs to carry is the extension point: a generic, empty
slot in the topbar that post-processors can fill. The injector also works
without it (it falls back to inserting before the language switcher), so it
runs against today's docs unchanged.

## Pinning

The pagefind version is pinned in `scripts/build.sh` (`PAGEFIND_VERSION`).
