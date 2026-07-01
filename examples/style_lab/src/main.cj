package cjtui_style_lab

import core.*

let CSS = """
screen {
  display: flex;
  flex-direction: column;
  gap: 1;
  padding: 1;
  background: black;
  color: white;
}

.toolbar {
  height: 3;
  padding: 1;
  background: blue;
}

.row {
  display: flex;
  gap: 2;
  height: 9;
}

.card {
  width: 24;
  height: 7;
  padding: 1;
  border: 1;
  background: white;
  color: black;
}

.card:selected {
  background: yellow;
  color: blue;
}
"""

class StyleLab {
    var selected: Int64 = 0

    func update(event: Event): ControlFlow {
        match (event) {
            case Event.KeyDown(key) => match (key.code) {
                case KeyCode.CtrlC | KeyCode.Char(r'q') => return ControlFlow.Exit
                case KeyCode.Left => selected = max(0, selected - 1)
                case KeyCode.Right => selected = min(2, selected + 1)
                case _ => ()
            }
            case _ => ()
        }
        ControlFlow.Continue
    }

    func render(frame: Frame): Unit {
        let rows = Layout.vertical([Constraint.Min(12), Constraint.Length(8), Constraint.Length(1)]).withGap(1).split(frame.area)
        let tree = buildTree(selected)
        frame.renderNode(tree, StyleSheet.parse(CSS))
        frame.renderWidget(CanvasPanel(), rows[1])
        frame.renderWidget(StatusBar(left: "style_lab  arrows select  q quit", right: "DOM + CSS + Canvas", style: Style(fg: Color.White, bg: Color.Black)), rows[2])
    }
}

class CanvasPanel <: Widget {
    public func render(area: Rect, buffer: Buffer): Unit {
        let guard = SizeGuard(40, 6)
        let fit = guard.fit(area)
        let canvas = Canvas(buffer, fit.content)
        canvas.fillRect(fit.content, Style(bg: Color.Rgb(16, 20, 28)))
        canvas.strokeRect(fit.content, Style(fg: Color.Cyan, bg: Color.Rgb(16, 20, 28)))
        canvas.drawLine(fit.content.x + 2, fit.content.bottom - 2, fit.content.right - 3, fit.content.y + 1, "*", Style(fg: Color.Yellow, bg: Color.Rgb(16, 20, 28)))
        canvas.drawSprite(fit.content.x + 4, fit.content.y + 2, ["CANVAS", "clip + line + sprite"], Style(fg: Color.White, bg: Color.Rgb(16, 20, 28)))
        if (fit.tooSmall) {
            canvas.drawText(fit.content.x + 1, fit.content.y, "too small", Style(fg: Color.Red, bg: Color.Rgb(16, 20, 28)))
        }
    }
}

func buildTree(selected: Int64): ViewNode {
    let root = ViewNode("root", tag: "screen")
    let toolbar = ViewNode("toolbar", tag: "header", classes: ["toolbar"])
    toolbar.setText("StyleLab")
    root.add(toolbar)
    let row = ViewNode("row", tag: "section", classes: ["row"])
    for (i in 0..3) {
        let card = ViewNode("card${i}", tag: "article", classes: ["card"])
        card.setText(if (i == 0) { "cascade\nspecificity" } else if (i == 1) { "flex\nlayout" } else { "tokens\nstates" })
        if (i == selected) { card.setState("selected") }
        row.add(card)
    }
    root.add(row)
    root
}

main(): Int64 {
    let app = StyleLab()
    App(rawMode: true).run(
        { frame => app.render(frame) },
        { event => app.update(event) }
    )
    0
}
