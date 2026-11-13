// Marp engine that adds line highlights to fenced code blocks.
//
//   ```elixir {2,5-6}        lines 2, 5 and 6 are highlighted all the time
//   ```elixir {2|5-6|9}      no highlight when the slide loads, then each
//                            click moves the highlight: 2, then 5-6, then 9
//
// A block with no language takes the braces alone: ``` {3}
//
// Animated steps use Marp's fragments, so they step in the browser presenter
// (marp -s, or an HTML export). Each step is a hidden marker element marked as
// a fragment. The theme highlights the lines of whichever marker is current.
// When a slide has two animated blocks, the first block's steps run first.
//
// A table row can light up with a step too: put
// <span class="hl-row" data-step="1"></span> in its first cell. See the
// table row section at the end of theme.css.

const STEPS = /\{([\d,\-|\s]*)\}\s*$/

function parseLines(spec) {
  const lines = new Set()
  for (const part of spec.split(",")) {
    const range = part.trim()
    if (!range) continue
    const [from, to = from] = range.split("-").map(Number)
    for (let n = from; n <= to; n += 1) lines.add(n)
  }
  return lines
}

// Splits highlighted HTML into lines. A highlight.js span can cross a line
// break (a multi-line string, say), so each line closes the spans still open
// at its end and reopens them at the start of the next line.
function splitLines(html) {
  const lines = []
  let open = []
  let current = ""
  const tokens = html.split(/(<span[^>]*>|<\/span>|\n)/)
  for (const token of tokens) {
    if (token === "\n") {
      lines.push(current + "</span>".repeat(open.length))
      current = open.join("")
    } else if (token.startsWith("<span")) {
      open.push(token)
      current += token
    } else if (token === "</span>") {
      open.pop()
      current += token
    } else {
      current += token
    }
  }
  if (current !== open.join("")) lines.push(current + "</span>".repeat(open.length))
  return lines
}

function highlightLines(md) {
  const fence = md.renderer.rules.fence

  md.renderer.rules.fence = (tokens, idx, options, env, self) => {
    const token = tokens[idx]
    const match = token.info.match(STEPS)
    if (!match) return fence(tokens, idx, options, env, self)

    // Render the block without the braces, so the language is still found.
    token.info = token.info.slice(0, match.index).trim()
    const html = fence(tokens, idx, options, env, self)

    const animated = match[1].includes("|")
    // A trailing "|" marks a block as animated without adding an empty step,
    // so {4|} is one animated step that highlights line 4.
    const parts = match[1].split("|")
    while (animated && parts.length > 1 && parts[parts.length - 1].trim() === "") parts.pop()
    const steps = parts.map(parseLines)

    return html.replace(/(<code[^>]*>)([\s\S]*?)(<\/code>)/, (_, open, body, close) => {
      const lines = splitLines(body).map((line, i) => {
        const n = i + 1
        if (!animated) {
          const on = steps[0].has(n) ? " hl-on" : ""
          return `<span class="hl-line${on}">${line}</span>`
        }
        const inSteps = steps
          .map((set, s) => (set.has(n) ? `s${s + 1}` : null))
          .filter(Boolean)
          .join(" ")
        return `<span class="hl-line ${inSteps}">${line}</span>`
      })

      const markers = animated
        ? steps
            .map((_, s) => `<span class="hl-step" data-step="${s + 1}" data-marpit-fragment></span>`)
            .join("")
        : ""

      const kind = animated ? "hl-animated" : "hl-static"
      return `${open.replace("<code", `<code data-hl="${kind}"`)}${lines.join("")}${close}${markers}`
    })
  }
}

// A plate of nachos in the bottom-right corner that gets eaten as the talk
// goes. Each slide gets the plate drawn as it stands at that point: a full
// plate on the first slide after the title, and on the final slide nothing
// but crumbs and cheese stuck to the plate. The crumbs and cheese are always
// there under the pile, so they show more as the chips over them go.
// The drawing is a real element in the slide, so a slide with a ![bg] image
// shows it like any other. On the title slide, the theme serves the plate on
// the click that writes in "Nachos".
//
// Every topping sits on a chip and is eaten with it, so nothing goes without a
// chip going too. Chips come off the top of the pile first.

const cheese = (x, y, rx, ry, turn = 0) =>
  `<ellipse cx="${x}" cy="${y}" rx="${rx}" ry="${ry}" transform="rotate(${turn} ${x} ${y})"
    fill="#f2a12a" opacity="0.92"/>`
const jalapeno = (x, y) =>
  `<circle cx="${x}" cy="${y}" r="4.5" fill="#6aa83a" stroke="#2f6b17" stroke-width="1.2"/>
  <circle cx="${x}" cy="${y}" r="1.6" fill="#d8ecb5"/>`
const tomato = (x, y) => `<rect x="${x}" y="${y}" width="3.5" height="3.5" fill="#c8102e"/>`
const onion = (x, y) =>
  `<rect x="${x}" y="${y}" width="3" height="3" fill="#fbf7ee" stroke="#d8d2c4" stroke-width="0.5"/>`
const guacamole = `<path d="M-24 2 q6 -10 16 -8 q12 -4 17 6 q4 8 -6 10 q-10 4 -20 1 q-10 -1 -7 -9 z"
    fill="#86b545" stroke="#5c8a2a" stroke-width="1.2"/>
  <path d="M-8 -6 q2 -9 9 -5 q6 3 2 8 q-5 4 -11 -3 z"
    fill="#ffffff" stroke="#c9c9c9" stroke-width="1.2"/>`

// Each chip, from the bottom of the pile up: x, y, a turn in degrees, and the
// toppings on it, drawn around the chip's center. The pile is eaten from the
// top, so the last chip goes first.
const CHIPS = [
  [100, 80, 10, [cheese(0, -2, 8, 3)]],
  [76, 82, -25, [cheese(2, -3, 7, 3, -10), tomato(-5, -6)]],
  [124, 81, 35, [cheese(-2, -3, 7, 3, 12), jalapeno(3, -5)]],
  [88, 72, 60, [cheese(2, -2, 10, 4, -8), tomato(-7, -4), onion(4, 0)]],
  [113, 71, -10, [cheese(0, -2, 10, 3, 10), jalapeno(-4, -3), tomato(5, -7)]],
  [62, 76, 15, [cheese(4, -2, 7, 3), jalapeno(6, -4)]],
  [138, 75, -40, [cheese(-4, -2, 7, 3, -15), tomato(-8, -8), onion(-2, -5)]],
  [100, 64, 25, [cheese(0, 0, 11, 4), jalapeno(4, -5), tomato(-7, -3)]],
  [80, 62, -50, [cheese(4, 2, 9, 3, -10), jalapeno(4, 0), onion(-3, -4)]],
  [121, 61, 5, [cheese(-3, 1, 9, 3, 12), tomato(-5, -5), jalapeno(-3, 6)]],
  [92, 54, -20, [cheese(4, 2, 8, 3), tomato(-3, -2), onion(6, -2)]],
  [110, 50, 40, [guacamole]],
]
const CHIP_COLORS = ["#f3c55b", "#efbb48", "#f6cf6e"]

// Crumbs and cheese stuck to the plate, drawn under the pile.
const LEFTOVERS = `<g fill="#f2a12a" opacity="0.85">
    <ellipse cx="84" cy="88" rx="13" ry="3.5" transform="rotate(-4 84 88)"/>
    <ellipse cx="116" cy="91" rx="9" ry="2.5" transform="rotate(6 116 91)"/>
    <ellipse cx="101" cy="83" rx="5" ry="1.8"/>
  </g>
  <g fill="#efbb48" stroke="#c98f22" stroke-width="0.8" stroke-linejoin="round">
    <polygon points="70,84 75,82 74,87"/>
    <polygon points="94,92 99,90 97,95"/>
    <polygon points="125,85 129,86 126,89"/>
    <polygon points="108,87 111,85 112,89"/>
    <polygon points="62,90 65,88 66,92"/>
    <polygon points="134,91 138,90 136,94"/>
  </g>
  <g fill="#e2b04a">
    <circle cx="88" cy="94" r="1"/><circle cx="104" cy="89" r="0.9"/>
    <circle cx="120" cy="84" r="1"/><circle cx="78" cy="91" r="0.8"/>
    <circle cx="112" cy="94" r="0.9"/><circle cx="131" cy="88" r="0.8"/>
  </g>`

// fraction runs from 0 on the title slide to 1 on the last slide, which has no
// chips left.
function nachoPlate(fraction) {
  const left = CHIPS.slice(0, CHIPS.length - Math.floor(fraction * CHIPS.length))
  const chips = left
    .map(([x, y, turn], i) =>
      `<polygon points="0,-17 16,11 -16,11" transform="translate(${x} ${y}) rotate(${turn})"
        fill="${CHIP_COLORS[i % CHIP_COLORS.length]}" stroke="#c98f22" stroke-width="1.5"
        stroke-linejoin="round"/>`
    )
    .join("")
  // Toppings go over the whole pile, so they are drawn after every chip.
  const toppings = left
    .map(([x, y, , on]) => `<g transform="translate(${x} ${y})">${on.join("")}</g>`)
    .join("")

  return `<svg class="nachos" viewBox="0 0 200 120" aria-hidden="true">
  <ellipse cx="100" cy="88" rx="92" ry="27" fill="#ffffff" stroke="#c4c4c4" stroke-width="2"/>
  <ellipse cx="100" cy="86" rx="70" ry="18" fill="none" stroke="#e6e6e6" stroke-width="1.5"/>
  ${LEFTOVERS}
  <g transform="translate(100 80) scale(1.35) translate(-100 -80)">${chips}${toppings}</g>
</svg>`
}

function nachoProgress(md) {
  md.core.ruler.push("nacho_progress", (state) => {
    const total = state.tokens.filter((t) => t.type === "marpit_slide_open").length
    let index = -1
    const out = []
    for (const token of state.tokens) {
      out.push(token)
      if (token.type !== "marpit_slide_open") continue
      index += 1
      const plate = new state.Token("html_block", "", 0)
      plate.content = nachoPlate(index / (total - 1))
      out.push(plate)
    }
    state.tokens = out
  })
}

module.exports = ({ marp }) => marp.use(highlightLines).use(nachoProgress)
