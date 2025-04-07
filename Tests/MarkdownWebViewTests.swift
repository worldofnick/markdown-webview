import Testing
@testable import MarkdownWebView

struct MarkdownWebViewTests {
  // Test initialization without errors
  @Test func testMarkdownWebViewInitialization() {
    let view = MarkdownWebView("")
    #expect(view != nil)
  }

  // Test initialization with text
  @Test func testMarkdownWebViewInitializationWithText() {
    let view = MarkdownWebView("Hello, world!")
    #expect(view != nil)
  }

  // Test initialization with markdown content
  @Test func testMarkdownWebViewInitializationWithMarkdownContent() {
    let view = MarkdownWebView("# Hello, world!")
    #expect(view != nil)
  }
}
