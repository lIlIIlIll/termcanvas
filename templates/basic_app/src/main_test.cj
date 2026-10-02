package cjtui_basic_app

import core.*
import cjtui_testing.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class DemoAppTest {
    @TestCase
    func incrementAndResizeRenderThroughTheApplication(): Unit {
        let app = DemoApp()
        let report = TestScenario().key(KeyEvent(KeyCode.Char(r'+')))
            .resize(32, 8).tick().run(
                { frame => app.render(frame) }, { event => app.update(event) }
            )
        @Expect(report.passed)
        @Expect(app.count, 1)
        @Expect(report.lastSnapshot().contains("count: 1"))
    }
}
