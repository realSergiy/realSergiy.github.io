# Wiki

## Jekyll

### Most useful Jekyll 4.4 features for this site

This site = a growing set of image-heavy stories/articles on GitHub Pages, dark
theme, Markdown with code + math. All six are now implemented:

1. **Collections** — `_stories/`, `_cheet/`, `_tech/` are real collections, so
   `site.stories` / `site.cheet` / `site.tech` are lists and the root
   `index.md` (layout `home`) auto-generates the landing page from front
   matter (title, date, description, hero). Permalinks
   (`/stories/:path:output_ext` etc.) keep the original URLs, which also keeps
   relative image links inside story folders working.

2. **Plugins** — the payoff of building via GitHub Actions (any gem allowed):
   - `jekyll-seo-tag` — proper `<title>`, Open Graph / Twitter cards (link
     previews when sharing a story).
   - `jekyll-sitemap` — `sitemap.xml` for search engines, zero config.
   - `jekyll-feed` — Atom feeds per collection (`/feed/stories.xml`, …).
   - `jekyll-redirect-from` — keep old URLs alive after renames.

3. **Front-matter defaults** — every collection gets `layout: story` and
   `author: realSergiy` automatically; per-file front matter overrides.

4. **Sass/SCSS** — palette variables (`$bg`, `$accent`, …) live in
   `_sass/palette.scss`; shared partials (`base`, `article`, `rouge`,
   `landing`) are composed by `assets/css/story.scss` and
   `assets/css/home.scss`.

5. **Includes** — shared `head.html`, `nav.html`, `footer.html` partials in
   `_includes/`, used by both layouts.

6. **Local preview** — `just serve` (= `bundle exec jekyll serve
   --livereload`; needs Ruby installed locally).

### What `_config.yml` is

Jekyll's site-wide settings file — read once at build time.

```yaml
title: realSergiy            # site title; {{ site.title }} in layouts (used as <title> fallback)
description: …               # site tagline; used by jekyll-seo-tag and the landing hero fallback
author: realSergiy           # site-wide author for jekyll-seo-tag
url: "https://realsergiy.github.io"  # canonical base URL (seo-tag, sitemap, feed need it)
markdown: kramdown           # Markdown engine (kramdown is Jekyll's default & most capable)
highlighter: rouge           # code-block syntax highlighter

kramdown:
  input: GFM                 # parse GitHub-Flavored Markdown (fenced code, tables, etc.)
  syntax_highlighter: rouge  # hand code blocks to Rouge -> the .highlight CSS classes

collections:                 # content lives in _stories/, _cheet/, _tech/
  stories:
    output: true             # render each document to a page
    permalink: /stories/:path:output_ext  # keep pre-collection URLs (and relative image links)
  cheet:
    output: true
    permalink: /cheet/:path:output_ext
  tech:
    output: true
    permalink: /tech/:path:output_ext

defaults:                    # apply front matter automatically by type, so it isn't repeated per file
  - scope:
      type: stories          # every document in the stories collection ...
    values:
      layout: story          # ... gets the dark article layout
      author: realSergiy     # ... and the default author (per-file front matter overrides)
  # (same blocks for cheet and tech)

plugins:
  - jekyll-seo-tag
  - jekyll-sitemap
  - jekyll-feed
  - jekyll-redirect-from

feed:
  collections:               # jekyll-feed only feeds `posts` by default;
    - stories                # this adds /feed/stories.xml, /feed/cheet.xml, /feed/tech.xml
    - cheet
    - tech

exclude:                     # folders/files NOT copied into the built site (_site/)
  - excludes                 # work-in-progress, raw research, gists, settings, etc. stay off the site
  - docs
  - gists
  - gists_37132
  - settings
  - README.md
  - .rumdl.toml
  - justfile
```

Documents in a collection need front matter to be rendered; a file without it
is copied to `_site/` as a raw static file. Static assets (images) inside
collection folders are output following the collection permalink, so
`_stories/x/hero.png` still lands at `/stories/x/hero.png`.

Key point about `exclude`: those paths are kept out of the **published** site
but stay in the repo (which is public). So they're "not on the website," not
"private." If `articles/` or `drafts/` are meant to be published eventually,
remove them from `exclude` and give them layouts.

Note: editing `_config.yml` is the one change Jekyll's `serve` does **not**
hot-reload — restart the server for it to take effect.
