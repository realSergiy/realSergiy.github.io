# Wiki

## Jekyll

### Most useful Jekyll 4.4 features for this site

This site = a growing set of image-heavy stories/articles on GitHub Pages, dark
theme, Markdown with code + math. The high-leverage features:

1. **Collections** — turn `stories/` into a real collection (`_stories/` + a
   config block). You then get `site.stories` as a list, so you can
   auto-generate a landing page ("all stories") with titles, dates, and hero
   thumbnails instead of hand-maintaining links. Each story can carry metadata
   (date, blurb, tags) in front matter.

2. **Plugins are unlocked** — the payoff of building via GitHub Actions. Legacy
   Pages only allowed ~8 plugins; the Actions build can use any gem. Worth
   adding:
   - `jekyll-seo-tag` — proper `<title>`, Open Graph / Twitter cards (link
     previews when sharing a story).
   - `jekyll-sitemap` — `sitemap.xml` for search engines, zero config.
   - `jekyll-feed` — RSS/Atom feed for followers.
   - `jekyll-redirect-from` — keep old URLs alive after renames.

3. **Front-matter defaults** — already in use (`layout: story` for everything
   under `stories`). Can extend to auto-set author, default hero, etc.

4. **Sass/SCSS** — move the inline `<style>` from the layout into
   `assets/css/story.scss` with variables (`$bg`, `$accent`). Cleaner, shared
   across future layouts. Jekyll compiles it automatically.

5. **Includes** — pull shared header/footer/nav into `_includes/` partials so
   every story stays consistent.

6. **Local preview** — `bundle exec jekyll serve --livereload` gives instant
   local rendering (needs Ruby installed locally).

### What `_config.yml` is

Jekyll's site-wide settings file — read once at build time.

```yaml
title: realSergiy            # site title; {{ site.title }} in layouts (used as <title> fallback)
markdown: kramdown           # Markdown engine (kramdown is Jekyll's default & most capable)
highlighter: rouge           # code-block syntax highlighter

kramdown:
  input: GFM                 # parse GitHub-Flavored Markdown (fenced code, tables, etc.)
  syntax_highlighter: rouge  # hand code blocks to Rouge -> the .highlight CSS classes

defaults:                    # apply front matter automatically by path, so it isn't repeated per file
  - scope:
      path: "stories"        # every file under stories/ ...
    values:
      layout: story          # ... gets the dark story layout without needing `layout:` in each file

exclude:                     # folders/files NOT copied into the built site (_site/)
  - drafts                   # work-in-progress, raw research, gists, settings, etc. stay off the site
  - docs
  - deep-research-raw
  - gists
  - gists_37132
  - settings
  - articles
  - README.md
  - .rumdl.toml
```

Key point about `exclude`: those paths are kept out of the **published** site
but stay in the repo (which is public). So they're "not on the website," not
"private." If `articles/` or `drafts/` are meant to be published eventually,
remove them from `exclude` and give them layouts.

Note: editing `_config.yml` is the one change Jekyll's `serve` does **not**
hot-reload — restart the server for it to take effect.
