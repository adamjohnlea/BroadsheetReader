// Broadsheet Reader — Highlight System
// Handles text selection, highlight creation, and restoration.
//
// Anchoring model: every position is expressed against one canonical text built from the
// article's text nodes, with whitespace runs collapsed to a single space. The same text is
// used when a highlight is saved and when it is restored, so offsets cannot drift.
// Matching ignores whitespace entirely and uses the saved prefix/suffix to pick the right
// occurrence when the highlighted phrase appears more than once.

window.BroadsheetHighlights = (function() {
    const ROOT_ID = 'broadsheet-article-root';
    const HIGHLIGHT_CLASS = 'broadsheet-highlight';
    const CONTEXT_LENGTH = 20;   // Matches the ~20 chars documented on Highlight.prefixContext
    const MIN_SELECTION_LENGTH = 6;
    const BLOCK_SELECTOR = 'p, div, li, ul, ol, h1, h2, h3, h4, h5, h6, blockquote, pre, '
        + 'table, tr, td, th, figure, figcaption, section, article, header, footer, dt, dd';

    function root() {
        const el = document.getElementById(ROOT_ID);
        if (!el) throw new Error('Article root element is missing.');
        return el;
    }

    function isWhitespace(ch) {
        return /\s/.test(ch);
    }

    function collapseWhitespace(str) {
        return str.replace(/\s+/g, ' ');
    }

    function removeWhitespace(str) {
        return str.replace(/\s+/g, '');
    }

    // Text inside script/style elements is never visible article text.
    const textFilter = {
        acceptNode: function(node) {
            const parent = node.parentElement;
            if (parent && parent.closest('script, style, noscript')) {
                return NodeFilter.FILTER_REJECT;
            }
            return NodeFilter.FILTER_ACCEPT;
        }
    };

    function textNodes(container) {
        const walker = document.createTreeWalker(container, NodeFilter.SHOW_TEXT, textFilter);
        const nodes = [];
        let node;
        while ((node = walker.nextNode())) nodes.push(node);
        return nodes;
    }

    // Builds the canonical text and the maps between it and the DOM.
    //  - text:          canonical (whitespace-collapsed) article text
    //  - starts/ends:   DOM position where each canonical character starts / ends
    //  - rawToText:     canonical index for each raw position (concatenated node data)
    //  - compact:       canonical text with all whitespace removed (used for matching)
    //  - compactToText: canonical index for each compact character
    function buildIndex() {
        const nodes = textNodes(root());
        let text = '';
        const starts = [], ends = [], rawToText = [];
        let compact = '';
        const compactToText = [];
        let lastWasSpace = false;
        let lastBlock = null;

        nodes.forEach(function(node) {
            const data = node.data;
            // Separate text from different blocks (e.g. "</p><p>") with a virtual space so saved
            // text reads naturally. It has no raw character, so it never anchors a highlight edge.
            const block = node.parentElement ? node.parentElement.closest(BLOCK_SELECTOR) : null;
            if (data.length > 0 && block !== lastBlock && text.length > 0 && !lastWasSpace) {
                text += ' ';
                starts.push({ node: node, offset: 0 });
                ends.push({ node: node, offset: 0 });
                lastWasSpace = true;
            }
            if (data.length > 0) lastBlock = block;

            for (let i = 0; i < data.length; i++) {
                const ch = data[i];
                if (isWhitespace(ch)) {
                    if (lastWasSpace) {
                        // Extend the current collapsed space to cover this character.
                        rawToText.push(text.length - 1);
                        ends[text.length - 1] = { node: node, offset: i + 1 };
                        continue;
                    }
                    rawToText.push(text.length);
                    text += ' ';
                    lastWasSpace = true;
                } else {
                    rawToText.push(text.length);
                    compactToText.push(text.length);
                    compact += ch;
                    text += ch;
                    lastWasSpace = false;
                }
                starts.push({ node: node, offset: i });
                ends.push({ node: node, offset: i + 1 });
            }
        });
        rawToText.push(text.length);

        return {
            text: text, starts: starts, ends: ends, rawToText: rawToText,
            compact: compact, compactToText: compactToText
        };
    }

    // Raw (concatenated text node data) length from the start of the article to a DOM point.
    function rawOffset(container, offset) {
        const range = document.createRange();
        range.selectNodeContents(root());
        range.setEnd(container, offset);
        let length = 0;
        textNodes(root()).forEach(function(node) {
            if (!range.intersectsNode(node)) return;
            if (node === range.endContainer) {
                length += range.endOffset;
            } else {
                length += node.data.length;
            }
        });
        return length;
    }

    // Converts a DOM range to canonical [start, end), trimming surrounding whitespace.
    function canonicalSpan(index, range) {
        let start = index.rawToText[rawOffset(range.startContainer, range.startOffset)];
        let end = index.rawToText[rawOffset(range.endContainer, range.endOffset)];
        while (start < end && index.text[start] === ' ') start++;
        while (end > start && index.text[end - 1] === ' ') end--;
        return { start: start, end: end };
    }

    function commonSuffixLength(a, b) {
        let n = 0;
        while (n < a.length && n < b.length && a[a.length - 1 - n] === b[b.length - 1 - n]) n++;
        return n;
    }

    function commonPrefixLength(a, b) {
        let n = 0;
        while (n < a.length && n < b.length && a[n] === b[n]) n++;
        return n;
    }

    // Finds the canonical span for a saved highlight, or null if its text is not in the article.
    // When the text occurs more than once, the occurrence whose surroundings best match the
    // saved prefix/suffix wins; ties go to the earliest occurrence.
    function locate(index, highlight) {
        const needle = removeWhitespace(highlight.text);
        if (!needle) return null;
        const prefix = removeWhitespace(highlight.prefix || '');
        const suffix = removeWhitespace(highlight.suffix || '');

        let best = -1, bestScore = -1;
        let at = index.compact.indexOf(needle);
        while (at !== -1) {
            const before = index.compact.substring(Math.max(0, at - prefix.length), at);
            const after = index.compact.substring(at + needle.length, at + needle.length + suffix.length);
            const score = commonSuffixLength(before, prefix) + commonPrefixLength(after, suffix);
            if (score > bestScore) {
                best = at;
                bestScore = score;
            }
            at = index.compact.indexOf(needle, at + 1);
        }
        if (best === -1) return null;

        return {
            start: index.compactToText[best],
            end: index.compactToText[best + needle.length - 1] + 1
        };
    }

    // Wraps canonical [start, end) in highlight spans, one per text node it touches.
    // Whitespace-only pieces are skipped so no empty markers appear between blocks.
    function wrap(index, span, id) {
        const first = index.starts[span.start];
        const last = index.ends[span.end - 1];
        const nodes = textNodes(root());
        const from = nodes.indexOf(first.node);
        const to = nodes.indexOf(last.node);

        for (let n = from; n <= to; n++) {
            let node = nodes[n];
            const startOffset = (n === from) ? first.offset : 0;
            const endOffset = (n === to) ? last.offset : node.data.length;
            if (startOffset >= endOffset) continue;
            if (!/\S/.test(node.data.substring(startOffset, endOffset))) continue;

            if (endOffset < node.data.length) node.splitText(endOffset);
            if (startOffset > 0) node = node.splitText(startOffset);

            const marker = document.createElement('span');
            marker.className = HIGHLIGHT_CLASS;
            marker.dataset.highlightId = id;
            node.parentNode.insertBefore(marker, node);
            marker.appendChild(node);
        }
    }

    function clear() {
        const container = root();
        container.querySelectorAll('.' + HIGHLIGHT_CLASS).forEach(function(marker) {
            const parent = marker.parentNode;
            while (marker.firstChild) parent.insertBefore(marker.firstChild, marker);
            parent.removeChild(marker);
        });
        container.normalize();
    }

    // Replaces all painted highlights with the given set.
    // Each highlight is { id, text, prefix, suffix }. Returns the ids that could not be found.
    function apply(highlights) {
        clear();
        const missing = [];
        highlights.forEach(function(h) {
            const index = buildIndex();   // Rebuilt each time: wrapping splits text nodes
            const span = locate(index, h);
            if (span) {
                wrap(index, span, h.id);
            } else {
                missing.push(h.id);
            }
        });
        return missing;
    }

    // Paints the given range as a highlight and returns what Swift should save,
    // or null if the range holds too little text to be a highlight.
    function createFromRange(range) {
        const index = buildIndex();
        const span = canonicalSpan(index, range);
        if (span.end - span.start < MIN_SELECTION_LENGTH) return null;

        wrap(index, span, 'new');
        return {
            text: index.text.substring(span.start, span.end),
            prefix: index.text.substring(Math.max(0, span.start - CONTEXT_LENGTH), span.start),
            suffix: index.text.substring(span.end, span.end + CONTEXT_LENGTH)
        };
    }

    function post(message) {
        window.webkit.messageHandlers.broadsheet.postMessage(message);
    }

    // Selection toolbar
    function installToolbar() {
        const toolbar = document.createElement('div');
        toolbar.className = 'broadsheet-selection-toolbar';
        toolbar.innerHTML = '<button id="bsHighlightBtn">✨ Highlight</button>';
        document.body.appendChild(toolbar);

        document.addEventListener('mouseup', function(e) {
            setTimeout(function() {
                const sel = window.getSelection();
                const insideToolbar = e.target.closest('.broadsheet-selection-toolbar');
                const hasSelection = sel.rangeCount > 0
                    && collapseWhitespace(sel.toString()).trim().length >= MIN_SELECTION_LENGTH
                    && root().contains(sel.getRangeAt(0).commonAncestorContainer);
                if (hasSelection && !insideToolbar) {
                    const rect = sel.getRangeAt(0).getBoundingClientRect();
                    const toolbarHeight = 36;
                    toolbar.style.left = Math.max(4, rect.left + rect.width / 2 - 50) + 'px';
                    // Show below selection if too close to top, above otherwise
                    if (rect.top < toolbarHeight + 8) {
                        toolbar.style.top = (rect.bottom + 6) + 'px';
                    } else {
                        toolbar.style.top = (rect.top - toolbarHeight - 4) + 'px';
                    }
                    toolbar.classList.add('visible');
                } else if (!insideToolbar) {
                    toolbar.classList.remove('visible');
                }
            }, 10);
        });

        document.getElementById('bsHighlightBtn').addEventListener('click', function(e) {
            e.preventDefault();
            e.stopPropagation();
            const sel = window.getSelection();
            toolbar.classList.remove('visible');
            if (sel.rangeCount === 0) return;

            try {
                const saved = createFromRange(sel.getRangeAt(0));
                sel.removeAllRanges();
                if (saved) {
                    post({ type: 'highlightCreated', text: saved.text, prefix: saved.prefix, suffix: saved.suffix });
                }
            } catch (err) {
                post({ type: 'highlightError', message: String(err && err.message ? err.message : err) });
            }
        });
    }

    installToolbar();

    return { apply: apply, createFromRange: createFromRange, buildIndex: buildIndex };
})();
