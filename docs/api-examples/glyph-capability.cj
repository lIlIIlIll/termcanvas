package cjtui_api_example

import core.*

class KnownFont <: GlyphCapabilityProvider {
    public func probe(budgetMillis: Int64): GlyphCapability {
        if (budgetMillis > 0) { GlyphCapability.VerifiedSupported } else { GlyphCapability.Unsupported }
    }
}

main(): Int64 {
    let provider: GlyphCapabilityProvider = KnownFont()
    match ((provider.probe(10), provider.probe(0), UnknownGlyphCapabilityProvider().probe(10))) {
        case (GlyphCapability.VerifiedSupported, GlyphCapability.Unsupported, GlyphCapability.Unknown) => ()
        case _ => throw IllegalStateException("incorrect glyph capability")
    }
    let session = GlyphCapabilitySession(provider: provider, timeoutMillis: 100, clock: TestClock())
    session.requestProbe()
    match ((session.detected(), session.iconSet())) {
        case (GlyphCapability.Unknown, IconSet.Unicode) => ()
        case _ => throw IllegalStateException("incorrect initial negotiation")
    }
    session.setOverride(IconSet.Ascii)
    let theme = session.applyTo(Theme.graphite())
    match (theme.iconSet) {
        case IconSet.Ascii => ()
        case _ => throw IllegalStateException("icon override was not applied")
    }
    session.close()
    return 0
}
