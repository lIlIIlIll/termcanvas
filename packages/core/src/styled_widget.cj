package core

/** 对子组件本次写入的单元格应用逐属性样式覆盖。
 * 未指定属性保留子组件解析后的样式；可用 Color.Reset 恢复终端默认颜色，
 * 或用 false 关闭修饰。内层 StyledWidget 的指定属性优先于外层。
 * 媒体图像不属于字符单元格，不受样式覆盖影响。
 * 键鼠事件仍由调用方交给原子组件处理。
 */
public class StyledWidget <: Widget {
    private let child: Widget
    private let styleOverride: StyleOverride

    public init(child: Widget, override!: StyleOverride) {
        this.child = child
        this.styleOverride = override
    }

    /** 在区域内绘制子组件；覆盖和裁剪在返回或抛出异常后恢复。 */
    public func render(area: Rect, buffer: Buffer): Unit {
        if (area.width <= 0 || area.height <= 0) { return }
        buffer.withCanvasClip(area) { =>
            buffer.withStyleOverride(styleOverride) { => child.render(area, buffer) }
        }
    }
}

// Keep the inner override where present and inherit every other outer field.
func mergeStyleOverride(outer: StyleOverride, inner: StyleOverride): StyleOverride {
    StyleOverride(
        fg: match (inner.fg) { case Some(value) => Some(value); case None => outer.fg },
        bg: match (inner.bg) { case Some(value) => Some(value); case None => outer.bg },
        bold: match (inner.bold) { case Some(value) => Some(value); case None => outer.bold },
        italic: match (inner.italic) { case Some(value) => Some(value); case None => outer.italic },
        underline: match (inner.underline) { case Some(value) => Some(value); case None => outer.underline },
        reversed: match (inner.reversed) { case Some(value) => Some(value); case None => outer.reversed }
    )
}
