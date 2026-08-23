## The answer is two lines

```css
.parent {
  display: grid;
  place-items: center;
}
```

That centers any single child, on both axes, in every browser shipping today. No wrapper div, no magic numbers, no `transform`, and it does not care how big the child is or whether the child knows its own size.

If that worked, you can stop reading. The rest of this is about the four situations where it does not, because "how do I center a div" is almost never really a question about centering. It is a question about height, and the centering is where you found out.

## Decide what you are centering first

Four different questions hide under the same sentence, and they have four different answers.

| What you actually want | The answer |
| --- | --- |
| A box horizontally inside a block parent | `margin-inline: auto` and a width |
| A line of text inside its box | `text-align: center` |
| One child on both axes inside a parent | `display: grid; place-items: center` |
| A thing in the middle of the screen, over everything | `position: fixed; inset: 0; margin: auto` |

The last two get confused constantly. Centering in a *parent* only means centering on screen if the parent happens to fill the screen, and most of the time it does not — which is the whole bug.

### `place-items: center` and why grid rather than flex

`place-items` is shorthand for `align-items` and `justify-items`. Grid honours both. Flexbox honours `align-items` and ignores `justify-items` entirely, so the flex version needs two different properties:

```css
/* grid: one property */
.parent { display: grid; place-items: center; }

/* flex: two, and they are not the pair you would guess */
.parent { display: flex; align-items: center; justify-content: center; }
```

Both work. Grid is one line, harder to typo, and does not silently do nothing when you reach for the symmetrical-looking property. Use grid unless you need flexbox for something else in the same container.

:::note This does not stretch the child
`place-items: center` sets both axes to `center`, which overrides the default `stretch`. If your child used to fill the parent's width and now does not, that is why — set `place-items: center stretch` to centre vertically and keep the fill.
:::

## The real problem is always height

Horizontal centering has worked since the 1990s. Vertical centering is where people get stuck, and it is nearly always the same root cause.

**A parent with no height cannot centre anything vertically.** There is no middle of a box whose height is determined by its contents, because its height *is* its contents. The browser is doing exactly what you asked. You asked for the middle of a box that is 40 pixels tall, and you got it.

### `height: 100%` does not chain

This is the one that eats an afternoon. `height: 100%` means "100% of my parent's height", and if that parent's height is `auto`, the percentage has nothing to resolve against and is ignored. Silently.

So a `height: 100%` on your wrapper does nothing unless every ancestor up to the root also has a resolved height:

```diff
+html, body { height: 100%; }
+
 .page {
   height: 100%;
   display: grid;
   place-items: center;
 }
```

Two lines at the top of the stylesheet, and the thing that "doesn't work" starts working.

The modern way out is to not chain at all:

```css
.page {
  min-height: 100dvh;   /* not 100vh — see below */
  display: grid;
  place-items: center;
}
```

`min-height` rather than `height`, so that content taller than the screen pushes the box down instead of overflowing it.

### `100vh` is wrong on a phone

`vh` is a fixed unit tied to the *largest* possible viewport, so on a mobile browser it includes the space under the address bar that retracts as you scroll. A `100vh` hero is taller than the screen on first paint, and your perfectly centred element sits slightly below the middle with a scrollbar you did not ask for.

| Unit | Resolves against | Use it when |
| --- | --- | --- |
| `100vh` | Largest viewport, UI retracted | You want the tall measurement deliberately |
| `100svh` | Smallest viewport, UI showing | Nothing may be cut off, ever |
| `100dvh` | Whatever the viewport is right now | The general answer |
| `100lvh` | Largest viewport | Same as `vh`, named honestly |

`dvh` changes value as the browser chrome moves, which means a layout animating on scroll. That is the trade, and for a centred hero it is the right one.

## The five methods, ranked

:::tabs
:::tab Grid
```css
.parent {
  display: grid;
  place-items: center;
  min-height: 100dvh;
}
```
One property, both axes, no assumptions about the child. This is the default answer.
:::
:::tab Flex
```css
.parent {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 100dvh;
}
```
Identical result. Reach for it when the container is already flex for other reasons, or when you need `gap` and `flex-wrap` behaviour for siblings.
:::
:::tab Auto margins
```css
.parent { display: flex; min-height: 100dvh; }
.child  { margin: auto; }
```
`margin: auto` on a flex item absorbs free space on *both* axes, which plain block layout never does. Useful when the parent is a flex container you do not control and you can only style the child.
:::
:::tab Absolute
```css
.parent { position: relative; }
.child {
  position: absolute;
  inset: 50% auto auto 50%;
  translate: -50% -50%;
}
```
The classic. Still correct, still needed when the element must be out of flow — dropdowns, modals, badges pinned to a corner. Note `translate` as its own property rather than `transform`, so it does not fight a `transform` animation.
:::
:::tab Fixed overlay
```css
.modal {
  position: fixed;
  inset: 0;
  margin: auto;
  width: min(90vw, 480px);
  height: fit-content;
}
```
`inset: 0` plus `margin: auto` centres in the viewport with no transform and no percentage maths. This is the modal answer.
:::
:::

## Why the absolute version suddenly stops working

You wrote `position: fixed` on a modal, it centred perfectly, and then someone added an animation to a parent and it moved.

**A `transform`, `filter`, `backdrop-filter`, `perspective`, `contain: paint` or `will-change` on an ancestor creates a containing block for its positioned descendants.** After that, `position: fixed` inside it is no longer relative to the viewport — it is relative to that ancestor. The element is still centred, just in the wrong box.

:::danger This is the single most confusing positioning bug in CSS
Nothing errors. Nothing warns. A `transform: translateY(0)` added three levels up for a scroll animation silently redefines what "fixed to the viewport" means for everything inside it. If a fixed overlay is in the wrong place, walk the ancestors looking for a transform before you touch the overlay.
:::

The fix is almost always to move the overlay out of that subtree entirely — a top-level container, or the `<dialog>` element, which the browser puts in the top layer where no ancestor can reach it:

```html
<dialog id="confirm">
  <p>Delete this draft?</p>
  <form method="dialog">
    <button value="cancel">Cancel</button>
    <button value="delete">Delete</button>
  </form>
</dialog>
```

```javascript
const dialog = document.getElementById("confirm");
dialog.showModal();               // top layer, centred by the UA, focus trapped
dialog.addEventListener("close", () => console.log(dialog.returnValue));
```

`showModal()` centres it, puts it above every stacking context on the page, traps focus, and closes on Escape. All the things people rebuild badly around a centred absolute div.

## Finding out what is actually happening

Guessing is slower than asking. Select the parent in devtools and read the two numbers that matter:

```console
> const p = $0, c = $0.firstElementChild
> getComputedStyle(p).display
"grid"
> getComputedStyle(p).height
"48px"                       // ← there it is
> getComputedStyle(p).placeItems
"center center"
> c.getBoundingClientRect().height
48
```

The parent is 48 pixels tall. The centring is working perfectly and there is nothing to centre inside. Every vertical-centring bug looks like this once you print the height.

Two more things worth knowing in devtools. The Layout panel has a **grid** checkbox that draws the tracks and the alignment, which shows you instantly whether the child is centred in a track or the track is the wrong size. And the badge next to an element in the Elements panel tells you whether the browser thinks it is `grid`, `flex` or neither — which catches the case where your `display` never applied because the selector was wrong.

## The cases nobody mentions

### Centring one item among several

`place-items: center` centres every child in its own grid cell. If you have three children and want the middle one centred in the *container*, that is a different layout — usually three columns with the outer two empty:

```css
.bar {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto minmax(0, 1fr);
  align-items: center;
}
```

Written out long, because a real one gets wide and this is what it looks like when it does:

```css
.toolbar { display: grid; grid-template-columns: [start] minmax(0, 1fr) [center-start] auto [center-end] minmax(0, 1fr) [end]; align-items: center; column-gap: clamp(0.5rem, 2vw, 1.5rem); }
```

That line does not wrap, and you have to scroll it, which is a reasonable argument for writing it as five.

### Geometric centring is not optical centring

A play triangle centred by its bounding box looks left of centre, because its visual mass sits left of its box. So does a right-pointing chevron, and so does most text with a hanging quotation mark.

The eye is right and the maths is right; they are measuring different things. Nudge it:

```css
.play-icon { translate: 8% 0; }
```

There is no formula. Somewhere between 5% and 10% of the width for a triangle, and you check it at the size it ships at.

### Centring text that wraps

`text-align: center` on a paragraph that wraps to four lines produces a ragged shape on both edges that is genuinely harder to read, because the eye loses the left margin it uses to find the next line. Centre headings. Centre one-line labels. Do not centre body copy, and if you must, cap it hard:

```scss
.centered-lede {
  text-align: center;
  max-width: 45ch;      // short measure so it never runs past three lines
  margin-inline: auto;
  text-wrap: balance;   // spread the words evenly across the lines
}
```

`text-wrap: balance` is the property worth knowing here. It evens out the line lengths of short blocks instead of leaving one orphaned word on the last line.

## The whole thing as a decision

- [ ] Do you want the box centred, or the text inside it? Different properties.
- [ ] Is the parent taller than its content? If not, nothing vertical will work — fix the height first.
- [ ] Is it a modal or overlay? Use `<dialog>` and `showModal()`.
- [ ] Does it need to be out of flow? `position: absolute; inset: 50% auto auto 50%; translate: -50% -50%`.
- [ ] Anything else: `display: grid; place-items: center`.
- [ ] Is a fixed element in the wrong place? Walk the ancestors looking for a `transform`.

Centring is easy. Height is the hard part, and it always was.
