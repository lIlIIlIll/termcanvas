package cjtui_api_example

import core.*

main(): Int64 {
    let kinds = [MediaKind.Image, MediaKind.Animation, MediaKind.Video, MediaKind.Html, MediaKind.Diagram, MediaKind.Math]
    let protocols = [MediaProtocol.Text, MediaProtocol.Kitty, MediaProtocol.Sixel]
    let fits = [MediaFit.Contain, MediaFit.Cover, MediaFit.Fill, MediaFit.Original]
    let source = MediaSource("logo", "asset:logo", kind: MediaKind.Image, alt: "Logo")
    let frame = MediaFrameData(MediaProtocol.Text, "Logo", widthPixels: 1, heightPixels: 2, durationMillis: 3)
    let text = MediaFrameData.text("Logo")
    let kitty = MediaFrameData.kitty([b'A'], widthPixels: 1, heightPixels: 1)
    let sixel = MediaFrameData.sixel("payload", widthPixels: 1, heightPixels: 1)
    if (kinds.size != 6 || protocols.size != 3 || fits.size != 4 || source.id != "logo" ||
        source.uri != "asset:logo" || source.alt != "Logo" || frame.payload != "Logo" ||
        frame.widthPixels != 1 || frame.heightPixels != 2 || frame.durationMillis != 3 ||
        text.payload != "Logo" || kitty.payload != "QQ==" || sixel.payload != "payload" ||
        mediaFallbackText(source) != "Logo" || mediaProtocolName(frame.protocol) != "text") {
        throw IllegalStateException("incorrect media data")
    }
    let area = Rect(0, 0, 4, 2)
    let placement = MediaPlacement("logo", source, area, fit: MediaFit.Contain, frameIndex: 0, frame: frame)
    let same = MediaPlacement("logo", source, area, fit: MediaFit.Contain, frameIndex: 0, frame: frame)
    let ops = diffMediaPlacements([], [placement])
    let clear = MediaOp(MediaOpKind.Clear, placement)
    match ((source.kind, placement.fit, ops[0].kind, clear.kind)) {
        case (MediaKind.Image, MediaFit.Contain, MediaOpKind.Draw, MediaOpKind.Clear) => ()
        case _ => throw IllegalStateException("incorrect media operation")
    }
    if (placement.id != "logo" || placement.source.id != "logo" || placement.area != area ||
        placement.frameIndex != 0 || placement.frame.payload != "Logo" || !placement.sameRenderContent(same) ||
        ops.size != 1 || ops[0].placement.id != "logo" || clear.placement.id != "logo") {
        throw IllegalStateException("incorrect placement diff")
    }
    return 0
}
