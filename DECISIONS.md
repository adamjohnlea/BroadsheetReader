# Decisions

New decisions go here, newest first, each with the date and the reason.

Decisions already baked into the app are described in CLAUDE.md:
- All SwiftData relationships optional and no `@Attribute(.unique)`, with logic-based deduplication via guid checking (CloudKit requirement). See the Data Layer section.
- Local storage fallback when iCloud is unavailable. See the Architecture section (`BroadsheetApp.swift`).

## 2026-10-11 (article rendering)

**Feed content can't run scripts in the article or talk to the app.**
Tests showed that scripts in feed HTML could post fake highlights, pop error alerts with any text, and make real highlights show "Not found in article". Article JavaScript is now off, and the highlight code runs where article content can't reach it. Embedded posts from X and similar script widgets fall back to plain text; I accept that.

**Embedded videos keep working.**
YouTube iframes are the most common embed in real feeds, so iframes from other sites still get their JavaScript. Only the article itself and iframes it writes itself are script-free.

**Links open in my browser, and the article stays put.**
Clicking a link used to replace the article in the pane and then show a highlight error. Now clicked links open in the default browser, and footnote links still scroll within the article. Anything else the content tries, such as redirects, auto-refresh or submitting a form, is blocked. Newsletter signup forms in articles won't work; the Mac beeps instead.

## 2026-10-11

**Claude writes DECISIONS.md at the end of each session.**
I decide; Claude writes the decisions up in my words and commits them, and I review the commit.

**I do the hands-on Mac check when Claude can't drive the app.**
Xcode's device-interaction tool only supports simulators, and a UI test can't see which passage is highlighted. A test that passes without being able to tell would be false evidence, so I ran the highlight check myself before we committed.

**Highlights anchor by their surrounding text.**
Each highlight saves the text just before and after it, and restoring uses that to pick the right occurrence of a repeated phrase. Highlighting the second "Apple Intelligence" in an article must bring back the second one, not the first. Highlights saved before this change still restore exactly where they did, so nothing gets worse for existing highlights.

**Highlight problems are shown, never hidden.**
If highlighting fails, the app shows an alert. If a highlight's text is no longer in the article, the annotations panel labels it "Not found in article" instead of quietly dropping it. Silent failures make people think their highlights are gone.

**Unit-test data stores never use iCloud.**
Test stores are created with CloudKit sync turned off. Otherwise they pick up the app's iCloud entitlement and crash the test run locally. Xcode Cloud never saw this because the CI script strips the entitlement.

**Fix highlight bugs before adding highlight tests.**
Highlights had real bugs (wrong passage, drifting, silent failures). Tests written first would have locked that behaviour in, so the fix and its tests went in together.
