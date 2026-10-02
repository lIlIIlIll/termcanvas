package diff

import std.unittest.*
import std.unittest.testmacro.*

@Test
class Audit20261003DiffTest {
    @TestCase
    func filePathsExcludeUnifiedDiffTimestampMetadata(): Unit {
        let doc = parseUnifiedDiff("--- a/old name.txt\t2026-10-01 12:00:00 +0000\n+++ b/new name.txt\t2026-10-02 12:00:00 +0000\n@@ -1 +1 @@\n-old\n+new\n")
        @Assert(doc.files.size, 1)
        @Expect(doc.files[0].oldPath, "old name.txt")
        @Expect(doc.files[0].newPath, "new name.txt")
    }
}
