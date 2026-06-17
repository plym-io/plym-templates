set -euo pipefail

NAME=""
OPEN=0
SHOT=0
for arg in "$@"; do
  case "$arg" in
    --open)       OPEN=1 ;;
    --screenshot) SHOT=1 ;;
    -*)           echo "error: unknown flag '$arg'" >&2; exit 2 ;;
    *)            NAME="${arg##*/}" ;;
  esac
done
if [ -z "$NAME" ]; then
  echo "usage: $0 <template-name> [--open] [--screenshot]" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DIR=""
for cand in \
  "$NAME" \
  "templates/$NAME" \
  "$SCRIPT_DIR/templates/$NAME" \
  "$SCRIPT_DIR/$NAME"; do
  if [ -f "$cand/template.yaml" ]; then DIR="$cand"; break; fi
done
if [ -z "$DIR" ]; then
  hit="$(find "$SCRIPT_DIR" -type d -name "$NAME" -prune -exec test -f '{}/template.yaml' ';' -print 2>/dev/null | head -n1)"
  [ -n "$hit" ] && DIR="$hit"
fi
if [ -z "$DIR" ] || [ ! -f "$DIR/template.yaml" ]; then
  echo "error: could not find a template named '$NAME' (looked for a dir with template.yaml)" >&2
  exit 1
fi
DIR="$(cd "$DIR" && pwd)"
for f in index.html post.html template.yaml; do
  [ -f "$DIR/$f" ] || { echo "error: $DIR is missing $f" >&2; exit 1; }
done
[ -d "$DIR/css" ] || { echo "error: $DIR is missing css/ directory" >&2; exit 1; }

PREVIEW_DIR="$SCRIPT_DIR/preview"
[ -f "$PREVIEW_DIR/index.json" ] || { echo "error: missing $PREVIEW_DIR/index.json" >&2; exit 1; }
[ -d "$PREVIEW_DIR/content" ]    || { echo "error: missing $PREVIEW_DIR/content/" >&2; exit 1; }

python3 -c "import jinja2, yaml, markdown" 2>/dev/null || {
  echo "→ installing jinja2 + pyyaml + markdown ..."
  pip3 install --quiet jinja2 pyyaml markdown
}

DEMO_DIR="$SCRIPT_DIR/demo"
TEMPLATE_DIR="$DIR" TEMPLATE_NAME="$NAME" PREVIEW_DIR="$PREVIEW_DIR" DEMO_DIR="$DEMO_DIR" SHOT="$SHOT" python3 <<'PY'
import os, re, glob, json, datetime, pathlib, shutil, yaml
import markdown as md_lib
from jinja2 import Environment, FileSystemLoader, StrictUndefined

DIR     = os.environ["TEMPLATE_DIR"]
NAME    = os.environ["TEMPLATE_NAME"]
PREVIEW = os.environ["PREVIEW_DIR"]

class O:
    def __init__(self, **k): self.__dict__.update(k)
    def copy(self, **over):
        d = dict(self.__dict__); d.update(over); return O(**d)

cfg    = yaml.safe_load(open(os.path.join(DIR, "template.yaml"))) or {}
colors = cfg.get("colors", {}) or {}
fonts  = cfg.get("fonts", {}) or {}
prism  = cfg.get("prism", {}) or {}
C = {
    "primary":    colors.get("primary",    "#211A14"),
    "secondary":  colors.get("secondary",  "#8A7E73"),
    "accent":     colors.get("accent",     "#E9793A"),
    "background": colors.get("background", "#FBF7F2"),
}
F = {"heading": fonts.get("heading", "Space Grotesk"), "body": fonts.get("body", "Inter")}

css = "\n".join(open(p).read() for p in sorted(glob.glob(os.path.join(DIR, "css", "*.css"))))

# Per-template pages live under demo/<name>/. Assets (covers, logo, favicon)
# are NOT copied — every page references the single source under preview/
# directly, so there is exactly one copy of each asset on disk.
DEMO = pathlib.Path(os.environ["DEMO_DIR"])
OUT  = DEMO / NAME
(OUT / "posts").mkdir(parents=True, exist_ok=True)

# blog_prefix: path back to the template's own index (demo/<name>/).
# asset_prefix: path back to the preview/ source (covers/logo/favicon).
def make_site(blog_prefix, asset_prefix):
    return O(
        name=NAME, website="https://plym.io", blog_home="plym.io/blog",
        blog_prefix=blog_prefix, language="en",
        favicon=f"{asset_prefix}/favicon.ico", logo=f"{asset_prefix}/logo.webp",
        colors=O(**C), pagination=O(page_size=10),
        public_blog_url=lambda p=blog_prefix: f"{p}/index.html",
    )

# The templates link to the blog index as "{{ site.blog_prefix }}/" (a trailing
# slash). On file:// that opens a directory listing, not the page — so rewrite
# those bare "./" / "../" hrefs to point straight at index.html.
def link_to_index(html):
    return (html
            .replace('href="./"',  'href="./index.html"')
            .replace('href="../"', 'href="../index.html"'))

def render_markdown(text):
    md = md_lib.Markdown(extensions=["extra", "toc", "sane_lists"])
    html = md.convert(text)
    return html, md.toc_tokens

def reading_time(text):
    return max(1, round(len(text.split()) / 200))

data = json.load(open(os.path.join(PREVIEW, "index.json")))
raw_posts = data.get("posts", [])
if not raw_posts:
    raise SystemExit("error: no posts found in index.json")

base_date = datetime.datetime(2026, 6, 12)
posts = []
for i, p in enumerate(raw_posts):
    md_path = os.path.join(PREVIEW, "content", f"{i+1}.md")
    md_text = open(md_path).read() if os.path.isfile(md_path) else ""
    html, toc = render_markdown(md_text)
    author = O(display_name=p.get("author", {}).get("name", NAME),
               avatar_url=p.get("author", {}).get("avatar"))
    posts.append(O(
        title=p["title"],
        slug=p["slug"],
        excerpt=p.get("excerpt"),
        cover=p.get("cover"),                 # e.g. "assets/foo.png" (rel. to _preview/)
        author=author,
        published_at=base_date - datetime.timedelta(days=i * 7),
        reading_time=reading_time(md_text),
        tags=[O(name=t) if isinstance(t, str) else O(**t) for t in p.get("tags", [])],
        content=html,
        toc=toc,
    ))

def fam(name):
    return name.replace(" ", "+")
fonts_href = (
    "https://fonts.googleapis.com/css2?"
    f"family={fam(F['heading'])}:wght@600;900&"
    f"family={fam(F['body'])}&display=swap"
)
prism_theme = prism.get("theme")
prism_head = prism_foot = ""
if prism_theme:
    base = "https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0"
    prism_head = f'<link rel="stylesheet" href="{base}/themes/prism-{prism_theme}.min.css">'
    prism_foot = (
        f'<script src="{base}/components/prism-core.min.js"></script>'
        f'<script src="{base}/plugins/autoloader/prism-autoloader.min.js"></script>'
    )

def wrap(site, body, body_class, title, banner=True):
    note = '' if not banner else (
        '<style>'
        '@keyframes plymPvIn{from{opacity:0;transform:translateY(-100%)}'
        'to{opacity:1;transform:translateY(0)}}'
        '.plym-preview-banner{position:fixed;top:0;left:0;right:0;z-index:2147483647;'
        'box-sizing:border-box;width:100%;padding:11px 44px;text-align:center;'
        "font-family:ui-sans-serif,system-ui,-apple-system,'Segoe UI',Roboto,sans-serif;"
        'font-size:13px;font-weight:600;line-height:1.45;letter-spacing:.01em;'
        'color:#241400;background:linear-gradient(180deg,#ffc24b,#ff9e2c);'
        'border-bottom:1px solid rgba(0,0,0,.18);box-shadow:0 4px 14px rgba(0,0,0,.18);'
        'animation:plymPvIn .4s ease 1s both}'
        '.plym-preview-banner strong{font-weight:800}'
        '.plym-preview-banner button{position:absolute;top:50%;right:12px;'
        'transform:translateY(-50%);display:flex;align-items:center;justify-content:center;'
        'width:24px;height:24px;padding:0;border:0;border-radius:6px;cursor:pointer;'
        'background:rgba(0,0,0,.08);color:#241400;font-size:17px;line-height:1;'
        'opacity:.55;transition:opacity .15s,background .15s}'
        '.plym-preview-banner button:hover{opacity:1;background:rgba(0,0,0,.16)}'
        '</style>'
        '<div class="plym-preview-banner" role="alert">'
        "Preview only — the template's design, <strong>NOT</strong> a page built by the <strong>plym</strong> engine. A real <strong>plym</strong> blog with this template will look identical but with SEO and optimizations baked in."
        '<button type="button" aria-label="Dismiss this notice" '
        'onclick="this.parentNode.remove()">&times;</button></div>'
    )
    return f"""<!doctype html>
<html lang="{site.language}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} — {NAME}</title>
<link rel="icon" href="{site.favicon}">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="{fonts_href}" rel="stylesheet">
{prism_head}
<style>
:root{{
  --color-primary:{C['primary']};
  --color-secondary:{C['secondary']};
  --color-accent:{C['accent']};
  --color-background:{C['background']};
  --font-heading:'{F['heading']}';
  --font-body:'{F['body']}';
}}
html,body{{margin:0}}
{css}
</style>
</head>
<body class="{body_class}">
{body}
{note}
{prism_foot}
</body>
</html>
"""

env = Environment(loader=FileSystemLoader(DIR), undefined=StrictUndefined, autoescape=True)

# index at demo/<name>/index.html  -> blog ".", preview source "../../preview"
site_index = make_site(".", "../../preview")
index_posts = [p.copy(slug=f"posts/{p.slug}.html",
                      cover=(f"../../preview/{p.cover}" if p.cover else None)) for p in posts]
index_body = link_to_index(env.get_template("index.html").render(site=site_index, posts=index_posts))
(OUT / "index.html").write_text(wrap(site_index, index_body, "plym-index", "Blog"))
# banner-free source used only for the screenshot (removed afterwards)
if os.environ.get("SHOT") == "1":
    (OUT / ".shot.html").write_text(wrap(site_index, index_body, "plym-index", "Blog", banner=False))

# posts at demo/<name>/posts/<slug>.html  -> blog "..", preview source "../../../preview"
site_post = make_site("..", "../../../preview")
for p in posts:
    pr = p.copy(cover=(f"../../../preview/{p.cover}" if p.cover else None))
    body = link_to_index(env.get_template("post.html").render(site=site_post, post=pr))
    dest = OUT / "posts" / f"{p.slug}.html"
    dest.write_text(wrap(site_post, body, "plym-post", p.title))
PY

INDEX="$DEMO_DIR/$NAME/index.html"
echo "✓ Preview ready at file://$INDEX"

# ---- screenshot the rendered index (banner-free) into demo/<name>/<name>.png
if [ "$SHOT" -eq 1 ]; then
  SHOT_HTML="$DEMO_DIR/$NAME/.shot.html"
  PNG="$DEMO_DIR/$NAME/$NAME.png"
  CHROME=""
  for c in \
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    "/Applications/Chromium.app/Contents/MacOS/Chromium" \
    "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser" \
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" \
    google-chrome chromium chromium-browser; do
    if command -v "$c" >/dev/null 2>&1 || [ -x "$c" ]; then CHROME="$c"; break; fi
  done
  if [ -n "$CHROME" ] && [ -f "$SHOT_HTML" ]; then
    "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=2 \
      --window-size=1280,1600 --default-background-color=ffffffff \
      --screenshot="$PNG" "file://$SHOT_HTML" >/dev/null 2>&1 \
      && echo "✓ Screenshot saved to $PNG" \
      || echo "→ screenshot failed (chrome error); skipped" >&2
  else
    [ -z "$CHROME" ] && echo "→ no Chrome/Chromium found; skipped screenshot" >&2
  fi
  rm -f "$SHOT_HTML"
fi

if [ "$OPEN" -eq 1 ]; then
  if command -v open >/dev/null 2>&1; then open "$INDEX"            # macOS
  elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$INDEX"  # linux
  else echo "→ --open: no opener found (open/xdg-open); open manually: file://$INDEX" >&2
  fi
fi
