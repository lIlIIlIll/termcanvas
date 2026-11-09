package core

import std.collection.*

/** 媒体来源的内容类别。 */
public enum MediaKind {
    /** 图像。 */
    | Image
    /** 动画。 */
    | Animation
    /** 视频。 */
    | Video
    /** HTML 内容。 */
    | Html
    /** 图表或示意图。 */
    | Diagram
    /** 数学内容。 */
    | Math
}

/** 媒体帧使用的终端输出协议。 */
public enum MediaProtocol {
    /** 文本回退。 */
    | Text
    /** Kitty 图形协议。 */
    | Kitty
    /** Sixel 图形协议。 */
    | Sixel
}

/** 媒体适配目标区域的方式。 */
public enum MediaFit {
    /** 完整包含在目标区域内。 */
    | Contain
    /** 覆盖目标区域。 */
    | Cover
    /** 填满目标区域。 */
    | Fill
    /** 使用原始尺寸。 */
    | Original
}

/** 描述媒体身份、地址、类别和替代文字。 */
public class MediaSource {
    /** 来源身份。 */
    public let id: String
    /** 来源地址。 */
    public let uri: String
    /** 媒体类别。 */
    public let kind: MediaKind
    /** 替代文字。 */
    public let alt: String

    /** 创建媒体来源描述。
     * @param id 来源身份
     * @param uri 来源地址
     * @param kind 媒体类别
     * @param alt 替代文字
     */
    public init(id: String, uri: String, kind!: MediaKind = MediaKind.Image, alt!: String = "") {
        this.id = id
        this.uri = uri
        this.kind = kind
        this.alt = alt
    }
}

/** 媒体帧的协议、载荷、像素尺寸和显示时长。 */
public class MediaFrameData {
    /** 帧输出协议。 */
    public let protocol: MediaProtocol
    /** 协议载荷。 */
    public let payload: String
    /** 像素宽度。 */
    public let widthPixels: Int64
    /** 像素高度。 */
    public let heightPixels: Int64
    /** 显示时长，单位为毫秒。 */
    public let durationMillis: Int64

    /** 创建帧数据；负尺寸和负时长按零处理。
     * @param protocol 输出协议
     * @param payload 协议载荷
     * @param widthPixels 像素宽度
     * @param heightPixels 像素高度
     * @param durationMillis 显示时长，单位为毫秒
     */
    public init(
        protocol: MediaProtocol,
        payload: String,
        widthPixels!: Int64 = 0,
        heightPixels!: Int64 = 0,
        durationMillis!: Int64 = 0
    ) {
        this.protocol = protocol
        this.payload = payload
        this.widthPixels = max(0, widthPixels)
        this.heightPixels = max(0, heightPixels)
        this.durationMillis = max(0, durationMillis)
    }

    /** 创建文本回退帧。
     * @param text 文本内容
     * @return 文本帧
     */
    public static func text(text: String): MediaFrameData {
        MediaFrameData(MediaProtocol.Text, text)
    }

    /** 将原始字节编码为 Base64 并创建 Kitty 帧。
     * @param rawBytes 原始数据
     * @param widthPixels 像素宽度
     * @param heightPixels 像素高度
     * @return Kitty 帧
     */
    public static func kitty(rawBytes: Array<Byte>, widthPixels!: Int64 = 0, heightPixels!: Int64 = 0): MediaFrameData {
        MediaFrameData(MediaProtocol.Kitty, base64Encode(rawBytes), widthPixels: widthPixels, heightPixels: heightPixels)
    }

    /** 使用给定载荷创建 Sixel 帧。
     * @param payload Sixel 载荷
     * @param widthPixels 像素宽度
     * @param heightPixels 像素高度
     * @return Sixel 帧
     */
    public static func sixel(payload: String, widthPixels!: Int64 = 0, heightPixels!: Int64 = 0): MediaFrameData {
        MediaFrameData(MediaProtocol.Sixel, payload, widthPixels: widthPixels, heightPixels: heightPixels)
    }
}

/** 媒体帧在终端区域中的放置描述。 */
public class MediaPlacement {
    /** 放置身份。 */
    public let id: String
    /** 媒体来源。 */
    public let source: MediaSource
    /** 目标区域。 */
    public let area: Rect
    /** 适配方式。 */
    public let fit: MediaFit
    /** 非负帧索引。 */
    public let frameIndex: Int64
    /** 帧数据。 */
    public let frame: MediaFrameData

    /** 创建放置描述；负帧索引置零，未提供帧时使用来源的文本回退。
     * @param id 放置身份
     * @param source 媒体来源
     * @param area 目标区域
     * @param fit 适配方式
     * @param frameIndex 帧索引
     * @param frame 可选帧数据
     */
    public init(
        id: String,
        source: MediaSource,
        area: Rect,
        fit!: MediaFit = MediaFit.Contain,
        frameIndex!: Int64 = 0,
        frame!: ?MediaFrameData = None
    ) {
        this.id = id
        this.source = source
        this.area = area
        this.fit = fit
        this.frameIndex = max(0, frameIndex)
        this.frame = match (frame) {
            case Some(value) => value
            case None => MediaFrameData.text(mediaFallbackText(source))
        }
    }

    /** 比较放置 ID、来源 ID 与 URI、区域、适配方式、帧索引和帧数据；不直接比较来源类别或替代文字。
     * @param other 待比较放置
     * @return 上述渲染内容均相同时为 true
     */
    public func sameRenderContent(other: MediaPlacement): Bool {
        id == other.id &&
        source.id == other.source.id &&
        source.uri == other.source.uri &&
        area == other.area &&
        sameMediaFit(fit, other.fit) &&
        frameIndex == other.frameIndex &&
        sameMediaFrame(frame, other.frame)
    }
}

/** 媒体放置差异中的操作类型。 */
public enum MediaOpKind {
    /** 绘制放置。 */
    | Draw
    /** 清除放置。 */
    | Clear
}

/** 针对一个媒体放置的绘制或清除操作。 */
public class MediaOp {
    /** 操作类型。 */
    public let kind: MediaOpKind
    /** 操作涉及的放置。 */
    public let placement: MediaPlacement

    /** 创建媒体操作。
     * @param kind 操作类型
     * @param placement 涉及的放置
     */
    public init(kind: MediaOpKind, placement: MediaPlacement) {
        this.kind = kind
        this.placement = placement
    }
}

/** 按放置 ID 比较两组媒体；移除项产生清除操作，变化项先清除旧项再绘制新项。调用方应使用稳定且唯一的 ID。
 * @param previous 之前的放置
 * @param next 新的放置
 * @return 按处理顺序排列的媒体操作
 */
public func diffMediaPlacements(previous: Array<MediaPlacement>, next: Array<MediaPlacement>): Array<MediaOp> {
    let ops = ArrayList<MediaOp>()
    for (old in previous) {
        if (!containsMediaPlacementId(next, old.id)) {
            ops.add(MediaOp(MediaOpKind.Clear, old))
        }
    }
    for (item in next) {
        match (findMediaPlacement(previous, item.id)) {
            case Some(old) =>
                if (!item.sameRenderContent(old)) {
                    ops.add(MediaOp(MediaOpKind.Clear, old))
                    ops.add(MediaOp(MediaOpKind.Draw, item))
                }
            case None => ops.add(MediaOp(MediaOpKind.Draw, item))
        }
    }
    ops.toArray()
}

/** 选择来源的回退文本，依次优先使用替代文字、URI 和 ID。
 * @param source 媒体来源
 * @return 回退文本
 */
public func mediaFallbackText(source: MediaSource): String {
    if (!source.alt.isEmpty()) { source.alt }
    else if (!source.uri.isEmpty()) { source.uri }
    else { source.id }
}

/** 返回媒体协议的小写名称。
 * @param protocol 媒体协议
 * @return 协议名称
 */
public func mediaProtocolName(protocol: MediaProtocol): String {
    match (protocol) {
        case MediaProtocol.Text => "text"
        case MediaProtocol.Kitty => "kitty"
        case MediaProtocol.Sixel => "sixel"
    }
}

func sameMediaFit(left: MediaFit, right: MediaFit): Bool {
    match (left) {
        case MediaFit.Contain => match (right) { case MediaFit.Contain => true; case _ => false }
        case MediaFit.Cover => match (right) { case MediaFit.Cover => true; case _ => false }
        case MediaFit.Fill => match (right) { case MediaFit.Fill => true; case _ => false }
        case MediaFit.Original =>
            match (right) {
                case MediaFit.Original => true
                case _ => false
            }
    }
}

func sameMediaFrame(left: MediaFrameData, right: MediaFrameData): Bool {
    sameMediaProtocol(left.protocol, right.protocol) &&
    left.payload == right.payload &&
    left.widthPixels == right.widthPixels &&
    left.heightPixels == right.heightPixels &&
    left.durationMillis == right.durationMillis
}

func sameMediaProtocol(left: MediaProtocol, right: MediaProtocol): Bool {
    match (left) {
        case MediaProtocol.Text => match (right) { case MediaProtocol.Text => true; case _ => false }
        case MediaProtocol.Kitty => match (right) { case MediaProtocol.Kitty => true; case _ => false }
        case MediaProtocol.Sixel => match (right) { case MediaProtocol.Sixel => true; case _ => false }
    }
}

func containsMediaPlacementId(items: Array<MediaPlacement>, id: String): Bool {
    for (item in items) {
        if (item.id == id) { return true }
    }
    false
}

func findMediaPlacement(items: Array<MediaPlacement>, id: String): ?MediaPlacement {
    for (item in items) {
        if (item.id == id) { return Some(item) }
    }
    None
}

func base64Encode(bytes: Array<Byte>): String {
    let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    var out = ""
    var i: Int64 = 0
    while (i < bytes.size) {
        let b0 = Int64(bytes[i])
        let has1 = i + 1 < bytes.size
        let has2 = i + 2 < bytes.size
        let b1 = if (has1) { Int64(bytes[i + 1]) } else { 0 }
        let b2 = if (has2) { Int64(bytes[i + 2]) } else { 0 }
        let n = (b0 << 16) | (b1 << 8) | b2
        out += base64Char(alphabet, (n >> 18) & 63)
        out += base64Char(alphabet, (n >> 12) & 63)
        out += if (has1) { base64Char(alphabet, (n >> 6) & 63) } else { "=" }
        out += if (has2) { base64Char(alphabet, n & 63) } else { "=" }
        i += 3
    }
    out
}

func base64Char(alphabet: String, index: Int64): String {
    unsafe { String.fromUtf8Unchecked([alphabet[index]]) }
}
