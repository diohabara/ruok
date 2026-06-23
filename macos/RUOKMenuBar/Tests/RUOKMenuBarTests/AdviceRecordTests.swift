import XCTest
@testable import RUOKMenuBar

final class AdviceRecordTests: XCTestCase {
    func testEncodesNilPreviousScreenshotPathForPythonCompatibility() throws {
        let record = AdviceRecord(
            id: "check-1",
            createdAt: "2026-06-23T20:00:00+09:00",
            screenshotPath: "screenshots/check-1.png",
            previousScreenshotPath: nil,
            changedPercent: 100,
            rms: 0,
            summary: "初回チェックです。",
            advice: "次の一手: 作業を1つ決めてください。",
            model: "fallback:qwen2.5vl:7b"
        )

        let data = try JSONEncoder().encode(record)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertTrue(object.keys.contains("previous_screenshot_path"))
        XCTAssertTrue(object["previous_screenshot_path"] is NSNull)
    }
}
