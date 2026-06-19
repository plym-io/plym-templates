# memoir

> An old-world reading theme for [plym](https://plym.io). Inked serif on grainy
> cream paper — e-ink calm, leather-bound restraint, a leaf at every turn.

`memoir` dresses a plym blog as a small private press would: a warm uncoated
sheet, near-black walnut ink, claret rubrication for links, and chapter
openings lifted by a drop-cap and a small-caps first line. Body copy is
justified and hyphenated, headings are set in a high-contrast didone, and every
horizontal rule is an engraved leaf flanked by hair-lines.

## The vibe, made literal

| Brief | How it's built |
| --- | --- |
| Grainy paper | A single faint `feTurbulence` fibre layer **plus** a soft corner vignette, both pinned to the viewport (`position: fixed`) so the page reads as one continuous sheet. Inlined SVG — zero requests. |
| Leaf in the centre of every rule | `<hr>` carries an inlined SVG ornament: an upright veined leaf between two hair-rules with small terminal dots. Reused for the title rule and TOC marker (`❧`). |
| Off-white, creamy background | `background` = `#f3ecdf` laid cream. |
| Inked serif, old-school British | Headings **Playfair Display** (600/900), body **EB Garamond** (400), old-style figures on. |
| Dark-brown, justified text | `primary` = `#2a2118` walnut ink; prose is `text-align: justify` with `hyphens: auto`. |
| First word upper-case | The opening paragraph gets a drop-cap initial **and** a small-caps first line — the classic illuminated chapter opening. |
| Luxury / e-ink calm | Matte surface, no glow, claret used only for links and flourishes, generous measure (~34rem). |

## Files

```
memoir/
├── index.html        # blog index — entries as front-matter, leaf rules between
├── post.html         # a single essay + sticky leaf-marked table of contents
├── template.yaml     # default fonts / colours / Prism theme
└── css/
    ├── base.css      # paper, type, links, rules, code, tables, footnotes, a11y
    ├── index.css     # .plym-index — the entry list
    └── post.css      # .plym-post — reading column, drop-cap, contents rail
```

All `css/*.css` are concatenated alphabetically by plym (`base → index → post`).

## Table of contents

On wide screens the contents become a **sticky left rail**; a small inline
scroll-spy (IntersectionObserver) lights the section you're reading in claret.
On narrow screens it folds into a collapsible card above the article. It is a
native `<details>` element — keyboard reachable, and **rendered `open`, so with
JavaScript disabled the full contents are still visible** and every link works.

## Honouring plym's rules

- **Body fragments only** — no `<html>`, `<head>`, or `<meta>`.
- **Zero external requests** — paper grain, leaf, and arrows are all inlined
  SVG / glyphs; no CDNs, web-font files, or scripts are fetched.
- **Driven by injected variables** — colours use `var(--color-*)`, type uses
  `var(--font-*)`; every tint is derived with `color-mix()`, so overriding the
  four colours in your `config.yaml` re-themes the whole template cleanly.
- **Font weights** — only heading 600/900 and body 400 are used (plym's
  allowance); `<em>` renders as a faux italic by design.
- **Accessibility** — skip link, visible `:focus-visible` rings, AA contrast
  (ink/sepia/claret all clear 4.5:1 on cream), and `prefers-reduced-motion`
  disables smooth scroll and transitions.
- **Budget** — concatenated CSS is well under the 30 KB minified limit.

## Customising

- **Recolour / re-font** anything via your `config.yaml`; the leaf ornament
  bakes a sepia tone for crispness, so deep palette shifts may want a matching
  `--m-leaf` override in a small custom CSS layer.
- **Drop-cap colour** is `var(--color-primary)` (dark brown). For a rubricated
  initial, change it to `var(--color-accent)` in `css/post.css`.
- **Prism theme** is `solarizedlight` in `template.yaml` — swap for any light
  theme that suits parchment.

## Preview

`preview/` (not shipped to plym) holds a static harness that mimics plym's
output — injected CSS variables, sample post + TOC — so the paper, leaf,
drop-cap, and contents rail can be rendered and screenshotted without a running
plym instance.
