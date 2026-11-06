package core

import std.unittest.*
import std.unittest.testmacro.*

@Test
class TranscriptStatusReferenceTest {
    @TestCase
    func legacyCallbackAndExplicitThemeRemainUsable(): Unit {
        let handler: (TranscriptItemStatus, Style) -> Style = transcriptStatusStyle
        let base = Style(fg: Color.White)
        for (status in [TranscriptItemStatus.Pending, TranscriptItemStatus.Running, TranscriptItemStatus.Failed]) {
            @Expect(handler(status, base), transcriptStatusStyle(status, base, theme: Option<Theme>.None))
        }
        let error = Style(fg: Color.Magenta)
        let theme = Theme(error: error)
        @Expect(transcriptStatusStyle(TranscriptItemStatus.Failed, base, theme: theme), base.patch(error))
    }
}
