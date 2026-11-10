package cjtui_api_example

import core.*
import media.*

main(): Int64 {
    let source = MediaSource("logo", "logo.png", alt: "Logo")
    let area = Rect(0, 0, 2, 2)
    let request = MediaDecodeRequest(source, area, MediaProtocol.Text, frameIndex: -1)
    let adapter: MediaAdapter = FallbackMediaAdapter()
    let fallback = adapter.decode(request)
    let external = ExternalMediaAdapter()
    if (request.source.id != "logo" || request.area.width != 2 || request.frameIndex != 0 ||
        !external.commandFor(request).isEmpty()) { throw IllegalStateException("media request failed") }
    match ((request.protocol, fallback.protocol, external.decode(request).protocol,
            preferredMediaProtocol(TerminalCapabilities(kittyGraphics: false, sixel: false)))) {
        case (MediaProtocol.Text, MediaProtocol.Text, MediaProtocol.Text, MediaProtocol.Text) => ()
        case _ => throw IllegalStateException("text fallback failed")
    }
    let placed = mediaPlacementWithAdapter("header", source, area, TerminalCapabilities(), adapter: adapter)
    if (placed.id != "header") { throw IllegalStateException("placement failed") }
    let buffer = Buffer(Rect(0, 0, 10, 2))
    let animation = AsciiAnimation([AsciiFrame(["ok"])])
    AsciiAnimationView(animation, zoom: 1).render(buffer.area, buffer)
    if (buffer.getCell(0, 0).symbol != "o") { throw IllegalStateException("animation view failed") }
    return 0
}
