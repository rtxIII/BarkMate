import XCTest
@testable import Store

final class GlanceRefreshTests: XCTestCase {

    /// 锁定 widget kind 契约值。Widget 声明与 NSE/主 app 的 reloadTimelines
    /// 都引用此常量,一旦被改名而 widget 端未同步,注册即静默失效——此断言即漂移守卫。
    func testWidgetKindActiveAgentsContractValue() {
        XCTAssertEqual(WidgetKind.activeAgents, "ActiveAgentsWidget")
    }

    /// reload() 是 fire-and-forget:请求非保证、非 throwing。此处确认链路可调用且不崩,
    /// 不断言系统真去刷新(那是 WidgetKit 系统行为,单测不可观测)。
    func testReloadDoesNotThrowOrCrash() {
        GlanceRefresh.reload()
    }
}
