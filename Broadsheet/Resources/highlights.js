// Broadsheet Reader — Highlight System
// Handles text selection, highlight creation, restoration, and cross-element wrapping.

(function() {
    // Create selection toolbar
    const toolbar = document.createElement('div');
    toolbar.className = 'broadsheet-selection-toolbar';
    toolbar.innerHTML = '<button id="bsHighlightBtn">✨ Highlight</button>';
    document.body.appendChild(toolbar);

    // Show toolbar on text selection
    document.addEventListener('mouseup', function(e) {
        setTimeout(function() {
            const sel = window.getSelection();
            const text = sel.toString().trim();
            if (text.length > 5 && !e.target.closest('.broadsheet-selection-toolbar')) {
                const range = sel.getRangeAt(0);
                const rect = range.getBoundingClientRect();
                const toolbarHeight = 36;
                toolbar.style.left = Math.max(4, rect.left + rect.width / 2 - 50) + 'px';
                // Show below selection if too close to top, above otherwise
                if (rect.top < toolbarHeight + 8) {
                    toolbar.style.top = (rect.bottom + 6) + 'px';
                } else {
                    toolbar.style.top = (rect.top - toolbarHeight - 4) + 'px';
                }
                toolbar.classList.add('visible');
            } else if (!e.target.closest('.broadsheet-selection-toolbar')) {
                toolbar.classList.remove('visible');
            }
        }, 10);
    });

    // Create highlight
    document.getElementById('bsHighlightBtn').addEventListener('click', function(e) {
        e.preventDefault();
        e.stopPropagation();
        const sel = window.getSelection();
        const text = sel.toString().trim();
        if (!text) return;

        const range = sel.getRangeAt(0);
        const fullText = document.body.innerText;
        const selStart = fullText.indexOf(text);
        const prefix = selStart > 0 ? fullText.substring(Math.max(0, selStart - 20), selStart) : '';
        const suffix = fullText.substring(selStart + text.length, selStart + text.length + 20);

        // Wrap selection
        try {
            const span = document.createElement('span');
            span.className = 'broadsheet-highlight';
            range.surroundContents(span);
        } catch(err) {
            wrapRangeHighlight(range);
        }

        sel.removeAllRanges();
        toolbar.classList.remove('visible');

        window.webkit.messageHandlers.broadsheet.postMessage({
            type: 'highlightCreated',
            text: text,
            prefix: prefix,
            suffix: suffix
        });
    });
})();

// Wrap cross-element selections
function wrapRangeHighlight(range) {
    const walker = document.createTreeWalker(
        range.commonAncestorContainer, NodeFilter.SHOW_TEXT, null
    );
    const textNodes = [];
    let node;
    while (node = walker.nextNode()) {
        if (range.intersectsNode(node)) textNodes.push(node);
    }
    textNodes.forEach(function(textNode) {
        const span = document.createElement('span');
        span.className = 'broadsheet-highlight';
        textNode.parentNode.insertBefore(span, textNode);
        span.appendChild(textNode);
    });
}

// Restore highlights from saved data
function restoreHighlights(highlights) {
    const bodyText = document.body.innerText;
    highlights.forEach(function(h) {
        const idx = bodyText.indexOf(h.text);
        if (idx === -1) return;

        const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null);
        let charCount = 0, node, startNode = null, startOffset = 0, endNode = null, endOffset = 0;

        while (node = walker.nextNode()) {
            const nodeLen = node.textContent.length;
            if (!startNode && charCount + nodeLen > idx) {
                startNode = node;
                startOffset = idx - charCount;
            }
            if (startNode && charCount + nodeLen >= idx + h.text.length) {
                endNode = node;
                endOffset = idx + h.text.length - charCount;
                break;
            }
            charCount += nodeLen;
        }

        if (startNode && endNode) {
            try {
                const range = document.createRange();
                range.setStart(startNode, startOffset);
                range.setEnd(endNode, endOffset);
                if (startNode === endNode) {
                    const span = document.createElement('span');
                    span.className = 'broadsheet-highlight';
                    range.surroundContents(span);
                } else {
                    wrapRangeHighlight(range);
                }
            } catch(err) {}
        }
    });
}
