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

module.exports = ({ marp }) => marp.use(highlightLines)
