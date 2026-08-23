## Markdown has a small portable core and a very long tail

The core is about a dozen constructs, they have been stable for a decade, and they work in every renderer that has ever existed. Headings, paragraphs, emphasis, lists, links, images, blockquotes, code. That is the part you can write without thinking.

Everything past that varies. Tables are not in the original spec. Footnotes are not in CommonMark. Callouts, tab sets and collapsible blocks are extensions, and no two implementations spell them the same way.

So "the right way to write markdown" is really two questions. What is the correct way to write the portable core, which has real answers. And how do you use the tail without your document falling apart the first time it moves somewhere else.

| Construct | Where it lives | Safe to use |
| --- | --- | --- |
| Headings, lists, links, emphasis, code | CommonMark | Everywhere |
| Tables, task lists, strikethrough | GitHub Flavored Markdown | Almost everywhere |
| Footnotes | Extension | Most places, check first |
| Callouts, tabs, galleries, collapsibles | Extension | Your renderer only |
| Raw HTML | Everywhere, then sanitised | Depends entirely on the sanitiser |

## Write it so the diff is readable

Markdown is a text format that lives in version control, and most of what people get wrong about it is invisible until someone tries to review a change.

### One sentence per line

This is the single highest-value habit and it looks strange for about a day.

```markdown
The core is about a dozen constructs.
They have been stable for a decade.
Everything past that varies.
```

Renderers join consecutive lines into one paragraph, so the output is identical to writing it as a block. What changes is the diff. Fix a typo in a hard-wrapped paragraph and the diff shows the whole paragraph rewrapped, and a reviewer has to read all of it to find your two characters. Fix a typo in a one-sentence line and the diff is one line.

It also makes you notice your own sentence lengths, stacked up in a column, which is a better editing tool than it has any right to be.

### Reference links at the bottom

Inline links wreck the measure of the source. A paragraph with four of them is unreadable in the editor even though it renders fine.

```markdown
The spec is [CommonMark][cm], and GitHub's extensions are documented in [GFM][gfm].

[cm]: https://commonmark.org/
[gfm]: https://github.github.com/gfm/
```

Reference definitions can go anywhere; the bottom of the file is the convention. The prose stays readable, and when a URL rots you fix it in one place instead of hunting through paragraphs.

:::tip Use words as reference labels, not numbers
`[cm]` survives you inserting a new link above it. `[1]` means renumbering, and renumbering means a diff that touches every link in the file.
:::

### Do not hard-wrap at 80 columns

Hard wrapping fights one-sentence-per-line and it fights your editor's soft wrap. It made sense when people wrote in terminals that could not reflow. Turn on soft wrap and let the line be as long as the sentence.

## Headings are structure, not size

A heading level is a claim about the document's shape. `###` means "this is a subsection of the `##` above it", and every table of contents, screen reader, and outline view in the world reads it that way.

### In a CMS, start at h2

The post title is already the `<h1>` on the rendered page. If your body starts with `#`, the page has two `<h1>` elements and the outline is broken before the first paragraph.

### Never skip a level

Going from `##` straight to `####` because you wanted smaller text produces a table of contents with a hole in it. If a heading is too loud, that is a CSS problem, and reaching into the document structure to fix a visual problem breaks the thing that was working.

### Give headings that will be scanned

Most readers arrive at a heading, decide in under a second, and either read the section or skip it. Which means a heading is a promise about content, not a label for a topic. "Reference links at the bottom" tells you what to do. "Links" does not.

## Lists

Ordered when the sequence matters, unordered when it does not. Two details are worth deciding once.

**Number every item `1.`** and let the renderer count:

```markdown
1. Pin the runtime
1. Pin the dependencies
1. Pin the services
```

Insert a step in the middle and the diff is one line. Number them by hand and it is four.

**Indent nested items by the width of the parent marker.** Under `- ` that is two spaces; under `1. ` it is three. Get it wrong and you get a code block instead of a nested list, which is the single most common markdown bug there is.

- Pin the runtime.
  - A version file the tooling reads without being asked.
  - A range is not a pin.
- Pin the dependencies.
  - The install command that honours the lockfile, not the one that updates it.

One level of nesting is a qualification. Two is usually a structure problem, and three is a table pretending to be a list.

## Code fences

### Always tag the language

An untagged fence renders as grey text. The tag is what turns it into something a reader can scan.

### `console` and `bash` are different tags

They look interchangeable and they are not. A `bash` block is something the reader copies:

```bash
curl -sS https://example.com/health
```

A `console` block is a transcript. It has the prompt, and it has the machine's answer, and it must never be copied whole:

```console
$ curl -sS https://example.com/health
{"status":"ok","version":"2.4.1","uptime_s":918273}
```

Use the right one and the reader always knows which is which. Put a `$` in front of a command you meant them to copy and the `$` comes along with it.

### The long line is a real decision

Sometimes a line has to scroll, and that is correct rather than sloppy:

```bash
docker run --rm -v "$PWD":/work -w /work --network host --env-file .env ghcr.io/acme/toolchain:2.4.1 build --target release --profile production --output-dir ./dist --verbose
```

A command meant to be copied whole should stay one line, because breaking it introduces continuations the reader has to get exactly right. A command meant to be *read* should be broken by you, with backslashes, so it fits the column.

## Tables are the least portable thing you will write

They are also the most likely to break a layout. A table renders at whatever width its content demands, and on a phone that means either a horizontal scroll or squeezed columns.

| Ecosystem | Reproducible install | The one that drifts | Lockfile | Fails loudly |
| --- | --- | --- | --- | --- |
| npm | `npm ci` | `npm install` | `package-lock.json` | Yes |
| pnpm | `pnpm install --frozen-lockfile` | `pnpm install` | `pnpm-lock.yaml` | Yes |
| Yarn (berry) | `yarn install --immutable` | `yarn install` | `yarn.lock` | Yes |
| Python (uv) | `uv sync --frozen` | `uv add` | `uv.lock` | Yes |
| Python (pip) | `pip install -r requirements.lock` | `pip install -r req.txt` | none by default | No |

Three habits keep them working. Put the thing being compared in column one, because that is the column that stays visible when the rest scrolls. Keep cells to a phrase — the moment a cell needs a sentence with a comma in it, you have prose pretending to be data. And do not bother aligning the pipes in the source; no renderer cares, and every edit costs you a realignment pass.

## The extensions

Everything below here is a bet on your renderer. The ideas are near-universal and the spelling is not, so the syntax in this section is the `:::` convention — the one Docusaurus popularised and a lot of tools have since adopted. If you move a document, these are the blocks you will have to rewrite.

### Callouts

A callout opens with `:::` and a name and closes with a bare `:::`. The words after the name become the title, and leaving them off wastes the most scannable line in the block.

```markdown
:::warning Setting retries to zero disables the retry loop
A request that fails once now fails for the reader. Use 1 for fast failure.
:::
```

Nine names are typical. They sort into four jobs, and knowing the job is how you pick:

:::note
An aside. True, useful, safely skippable. The workhorse, and probably the only one you need most days.
:::

:::hint The read-it-aloud test
A nudge toward working something out yourself. Closer to a tip than to a note.
:::

:::tip Use reference links for anything over one per paragraph
A better way to do the thing the reader is already doing. Optional by definition — if it is not optional, it is a step.
:::

:::important Start at h2 in a CMS
Not optional, not dangerous. The thing a reader will skip and then have to come back for.
:::

:::attention This block is rendered by your renderer's extension set
Look up. Something about the current context is not what you assume.
:::

:::caution Check the fence tag before you publish
There is a cost to getting this wrong, and it is recoverable.
:::

:::warning Changing a heading changes its anchor
There is a cost to getting this wrong, and it lands on someone else — every link to that anchor breaks silently.
:::

:::danger This command deletes the volume and everything in it
There is a cost to getting this wrong, and it is not recoverable.
:::

:::error posts.unclosed_block — a colon block was never closed
The failure state itself, quoted. Use it to show a reader what went wrong, not for your own warnings.
:::

That is the only time you will ever see nine of them stacked. In a real document, one per screen is the ceiling. Every callout you add makes the others quieter, and a page of tinted boxes teaches the reader to skip tinted boxes.

The test for whether one has earned its box is subtraction. Delete it. If the paragraph before it now has a hole, the content was never an aside and belongs in the prose.

### Tab sets

Tabs are for one task on several platforms. Same verb, same outcome, different environment.

:::tabs
:::tab macOS
```bash
brew install jq
```
:::
:::tab Debian / Ubuntu
```bash
sudo apt-get install -y jq
```
:::
:::tab Windows
```powershell
winget install jqlang.jq
```
:::
:::

The failure is using tabs to hide *different* content. If pane one installs the tool and pane two explains why you would want it, most readers will read one and never click the other. Whatever sits behind a tab that is not a sibling of the visible pane is content you have decided most people should not see.

### Galleries

A gallery is a fence rather than a colon block, and it is for images that are one idea seen several ways.

````markdown
```gallery
![Phone width, one column](media/md-phone.webp)
![Tablet width, contents folded above the body](media/md-tablet.webp)
```
````

```gallery
![A tall riso-style composition: an indigo halftone disc crossed by a hatched rust lens, with ochre concentric rings at the corner](media/md-phone.webp)
![The same three forms recomposed to fill a squarer frame](media/md-tablet.webp)
![The same three forms again, spread across a wide frame](media/md-desktop.webp)
```

Three views of one thing is a gallery. A screenshot, a team photo and a logo is three images, and each of them wants its own place in the argument with its own sentence attached.

Note that the caption text goes into `alt` rather than being printed. The images have to carry the idea on their own.

### Collapsible sections

Most renderers pass `<details>` straight through, which makes it the most portable extension in this section by a distance.

<details>
<summary>The full output of the failing install</summary>
<pre><code>$ npm ci
npm error code EBADENGINE
npm error engine Unsupported engine
npm error notsup Required: {"node":"&gt;=22.0.0"}
npm error notsup Actual:   {"npm":"10.8.2","node":"v18.20.4"}</code></pre>
</details>

Two rules, both about honesty. Write a summary that says what is inside — "Details" and "Click to expand" waste the only line most readers will ever see. And never collapse the answer. If the reader needs it to finish the task, it is not optional, and hiding it means half of them fail the step without knowing why.

### Footnotes

A footnote is for the sentence you want to write but do not want in the paragraph.[^1] Provenance, a caveat, the exception you know someone will raise.

```markdown
Most reprinted editorial in the language.[^src]

[^src]: The Sun, 21 September 1897. Attribution came nine years later.
```

Put the definitions at the bottom with your link references. Use words as labels rather than numbers, for the same reason.

### Task lists

Nothing is stored and nothing survives a reload. A task list is a visual affordance for work the reader does away from the screen, not a checklist the page remembers:

- [ ] Turn off hard wrapping and turn on soft wrap
- [ ] Convert one file to one sentence per line
- [ ] Tag every untagged code fence
- [ ] Find a `bash` block that should be `console`
- [x] Read a document about markdown, in markdown

## What actually breaks when a document moves

Ranked by how often it happens:

1. **Nested lists collapse**, because the indentation was two spaces under an ordered list that needed three.
2. **Callouts render as literal `:::` text**, because the target renderer never had the extension.
3. **Tables vanish**, because the target is strict CommonMark.
4. **Heading anchors change**, because slugging rules differ, and every deep link into the document dies quietly.
5. **Raw HTML disappears**, because the target sanitises a different allowlist.

None of these throw an error. That is what makes them expensive.

---

## A house style worth copying

Ten rules. They cost nothing and they settle most arguments before anyone has them.

1. One sentence per line. Soft wrap on, hard wrap off.
2. Reference links at the bottom, with word labels.
3. Body starts at `##`. Never skip a level.
4. Every fence gets a language tag. `console` for transcripts, `bash` for copyable commands.
5. `1.` for every ordered item.
6. Nest lists at the width of the parent marker.
7. Headings are promises, not topics.
8. One callout per screen, and every callout gets a title.
9. Tables get the compared thing in column one and phrases in the cells.
10. Anything from the extension section is a bet. Know what your renderer supports before you make it.

The portable core will outlive every tool you write it in. Get that part right and the tail is a detail.

[^1]: Like this one. If a footnote's content would change the reader's next action, it is not a footnote — it belongs in the paragraph where they will actually see it.
