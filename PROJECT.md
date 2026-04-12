# Pulse — RSS Reader

## Project Overview

A multi-user RSS reader focused on AI/tech news. Clean, minimal design inspired by Reeder 5: thin typography, generous whitespace, favicon-based feed identity, collapsible sidebar groups. Card-grid layout with article previews. Mobile-first from day one.

Full feature set: feed management with groups, read/unread tracking, bookmarks, full-text search, email digests via AWS SES, and OPML import/export.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | PHP 8.4 |
| Database | SQLite (via PDO) |
| Templating | Twig 3.x |
| HTTP / Routing | Symfony HttpFoundation + Routing |
| Styling | Tailwind CSS 4 |
| Interactivity | Alpine.js |
| Charts | Chart.js |
| PDF | DOMPDF |
| Email | AWS SES via aws-sdk-php |
| Testing | PHPUnit 11.x |
| Static Analysis | PHPStan Level 9 + strict-rules |
| Code Style | PHP-CS-Fixer (PSR-12) |

---

## Architecture

### Directory Structure

```
pulse/
├── public/
│   └── index.php              # Front controller
├── src/
│   ├── Domain/
│   │   ├── Feed/
│   │   │   ├── Feed.php
│   │   │   ├── FeedGroup.php
│   │   │   ├── FeedItem.php
│   │   │   └── FeedRepository.php
│   │   ├── User/
│   │   │   ├── User.php
│   │   │   └── UserRepository.php
│   │   ├── Bookmark/
│   │   │   ├── Bookmark.php
│   │   │   └── BookmarkRepository.php
│   │   └── Digest/
│   │       ├── Digest.php
│   │       └── DigestRepository.php
│   ├── Application/
│   │   ├── Feed/
│   │   │   ├── AddFeedHandler.php
│   │   │   ├── RemoveFeedHandler.php
│   │   │   ├── RefreshFeedsHandler.php
│   │   │   ├── ImportOpmlHandler.php
│   │   │   └── ExportOpmlHandler.php
│   │   ├── Item/
│   │   │   ├── MarkReadHandler.php
│   │   │   ├── MarkUnreadHandler.php
│   │   │   └── SearchItemsHandler.php
│   │   ├── Bookmark/
│   │   │   ├── SaveBookmarkHandler.php
│   │   │   └── RemoveBookmarkHandler.php
│   │   └── Digest/
│   │       └── SendDigestHandler.php
│   ├── Infrastructure/
│   │   ├── Database/
│   │   │   ├── Connection.php
│   │   │   └── Migration.php
│   │   ├── Http/
│   │   │   ├── Router.php
│   │   │   └── Middleware/
│   │   │       └── AuthMiddleware.php
│   │   ├── Feed/
│   │   │   └── RssParser.php        # SimplePie or custom parser
│   │   ├── Email/
│   │   │   └── SesMailer.php
│   │   └── Template/
│   │       └── TwigFactory.php
│   └── Controller/
│       ├── AuthController.php
│       ├── FeedController.php
│       ├── ItemController.php
│       ├── BookmarkController.php
│       ├── SearchController.php
│       ├── DigestController.php
│       └── OpmlController.php
├── templates/
│   ├── layout/
│   │   ├── base.html.twig
│   │   ├── sidebar.html.twig
│   │   └── mobile-nav.html.twig
│   ├── feed/
│   │   ├── index.html.twig        # Main card grid view
│   │   ├── manage.html.twig       # Feed management
│   │   └── add.html.twig
│   ├── item/
│   │   └── show.html.twig         # Article detail
│   ├── bookmark/
│   │   └── index.html.twig
│   ├── search/
│   │   └── results.html.twig
│   ├── digest/
│   │   ├── settings.html.twig
│   │   └── email.html.twig        # Email template
│   └── auth/
│       ├── login.html.twig
│       └── register.html.twig
├── database/
│   └── migrations/
│       ├── 001_create_users.sql
│       ├── 002_create_feeds.sql
│       ├── 003_create_feed_groups.sql
│       ├── 004_create_feed_items.sql
│       ├── 005_create_read_status.sql
│       ├── 006_create_bookmarks.sql
│       └── 007_create_digest_settings.sql
├── tests/
│   ├── Unit/
│   │   ├── Domain/
│   │   └── Application/
│   └── Integration/
├── var/
│   ├── db/
│   │   └── pulse.sqlite
│   ├── cache/
│   └── logs/
├── bin/
│   └── refresh-feeds             # CLI cron script
├── composer.json
├── phpstan.neon
├── .php-cs-fixer.php
└── phpunit.xml
```

### Design Patterns

- **Domain-Driven Design**: Domain objects are pure PHP, no framework coupling
- **Repository pattern**: All data access behind interfaces, SQLite implementations
- **Handler pattern**: One class per use case in Application layer
- **Front controller**: Single `public/index.php` entry point
- **PHPStan level 9 + strict-rules**: No `mixed`, strict types everywhere, `declare(strict_types=1)` in every file

---

## Database Schema

### users
```sql
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    display_name TEXT NOT NULL,
    digest_enabled INTEGER NOT NULL DEFAULT 0,
    digest_frequency TEXT NOT NULL DEFAULT 'daily', -- daily | weekly
    digest_time TEXT NOT NULL DEFAULT '08:00',
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

### feed_groups
```sql
CREATE TABLE feed_groups (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    collapsed INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

### feeds
```sql
CREATE TABLE feeds (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    group_id INTEGER REFERENCES feed_groups(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    url TEXT NOT NULL,                -- RSS/Atom feed URL
    site_url TEXT,                    -- Homepage URL (for favicon)
    favicon_url TEXT,                 -- Cached favicon URL
    description TEXT,
    last_fetched_at TEXT,
    fetch_error TEXT,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

### feed_items
```sql
CREATE TABLE feed_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    feed_id INTEGER NOT NULL REFERENCES feeds(id) ON DELETE CASCADE,
    guid TEXT NOT NULL,               -- Feed item GUID/link for deduplication
    title TEXT NOT NULL,
    url TEXT NOT NULL,
    author TEXT,
    summary TEXT,                     -- First ~300 chars of content
    content TEXT,                     -- Full content if available
    image_url TEXT,                   -- OG image or first image in content
    published_at TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(feed_id, guid)
);
```

### read_status
```sql
CREATE TABLE read_status (
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    item_id INTEGER NOT NULL REFERENCES feed_items(id) ON DELETE CASCADE,
    read_at TEXT NOT NULL DEFAULT (datetime('now')),
    PRIMARY KEY (user_id, item_id)
);
```

### bookmarks
```sql
CREATE TABLE bookmarks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    item_id INTEGER NOT NULL REFERENCES feed_items(id) ON DELETE CASCADE,
    note TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(user_id, item_id)
);
```

### search (FTS5 virtual table)
```sql
CREATE VIRTUAL TABLE feed_items_fts USING fts5(
    title,
    summary,
    content,
    content=feed_items,
    content_rowid=id
);
```

---

## Routes

### Auth
- `GET  /login` — Login form
- `POST /login` — Authenticate
- `GET  /register` — Register form
- `POST /register` — Create account
- `POST /logout` — Destroy session

### Main Reader
- `GET  /` — Today view: items from last 24h, card grid
- `GET  /all` — All unread items, card grid
- `GET  /bookmarks` — Saved bookmarks, card grid
- `GET  /item/{id}` — Single article detail
- `POST /item/{id}/read` — Mark read (Alpine.js XHR)
- `POST /item/{id}/unread` — Mark unread (Alpine.js XHR)
- `POST /item/{id}/bookmark` — Toggle bookmark (Alpine.js XHR)

### Feeds
- `GET  /feeds` — Feed management (list all feeds + groups)
- `POST /feeds` — Add new feed
- `GET  /feeds/{id}` — View single feed's items
- `POST /feeds/{id}/delete` — Remove feed
- `POST /feeds/{id}/refresh` — Force refresh single feed
- `POST /groups` — Create feed group
- `POST /groups/{id}/delete` — Remove group
- `POST /groups/{id}/collapse` — Toggle collapse state (Alpine.js XHR)

### Search
- `GET  /search?q=` — Full-text search results

### OPML
- `GET  /opml/export` — Download OPML file
- `POST /opml/import` — Upload and parse OPML

### Digest
- `GET  /digest` — Digest settings
- `POST /digest` — Save digest settings
- `POST /digest/send-now` — Trigger immediate digest send

---

## UI Design Specification

### Design Language

Inspired by Reeder 5. The goal is a "thin" minimal aesthetic: generous whitespace, restrained typography, high-signal low-noise.

**Key principles:**
- Almost everything is light gray, off-white, or black. Color used sparingly — one accent only.
- Typography does the heavy lifting. One font family, multiple weights.
- Favicons give feeds their visual identity. Don't fight them with competing color.
- Unread/read state is the primary visual affordance. Unread = full weight. Read = muted.
- Mobile is not an afterthought — same design language, reflow only.

### Color Palette (CSS custom properties)

```css
:root {
  --color-bg: #ffffff;
  --color-surface: #f7f7f5;       /* Sidebar, card hover */
  --color-border: #e8e8e4;
  --color-text-primary: #1a1a1a;
  --color-text-secondary: #6b6b6b;
  --color-text-muted: #9b9b9b;
  --color-accent: #16a34a;        /* Green — unread dots, active states */
  --color-accent-hover: #15803d;
  --color-unread-dot: #16a34a;
  --color-read: #9b9b9b;
}
```

### Typography

Single font: **Inter** (variable font from Bunny Fonts — no Google Fonts dependency).

```css
--font-sans: 'Inter', system-ui, sans-serif;

/* Scale */
--text-xs: 0.75rem;    /* 12px — timestamps, metadata */
--text-sm: 0.875rem;   /* 14px — sidebar items, secondary */
--text-base: 1rem;     /* 16px — body */
--text-lg: 1.125rem;   /* 18px — card titles */
--text-xl: 1.25rem;    /* 20px — page headings */
--text-2xl: 1.5rem;    /* 24px — main page title */
```

### Layout — Desktop

Three-column shell, responsive:

```
┌──────┬────────────────────┬──────────────────────────────────┐
│ Icon │ Sidebar            │ Content Area                     │
│ nav  │ (240px)            │ (flex-grow)                      │
│      │                    │                                  │
│ 48px │ - Today            │ [Page Title]                     │
│      │ - All Items        │                                  │
│      │ - Bookmarks        │ ┌──────┐ ┌──────┐ ┌──────┐      │
│      │ - Search           │ │ Card │ │ Card │ │ Card │      │
│      │                    │ └──────┘ └──────┘ └──────┘      │
│      │ FEEDS              │ ┌──────┐ ┌──────┐ ┌──────┐      │
│      │ ▾ AI / Tech        │ │ Card │ │ Card │ │ Card │      │
│      │   · Hacker News    │ └──────┘ └──────┘ └──────┘      │
│      │   · Simon Willison │                                  │
│      │ ▾ Research         │                                  │
│      │   · ArXiv cs.AI    │                                  │
└──────┴────────────────────┴──────────────────────────────────┘
```

### Layout — Mobile

No sidebar visible by default. Bottom tab bar for primary navigation. Sidebar accessible via slide-in drawer (Alpine.js). Cards reflow to single column.

```
┌────────────────────────┐
│ ≡  Pulse          🔍   │  ← top bar
├────────────────────────┤
│ Today                  │
│                        │
│ ┌──────────────────┐   │
│ │ Card             │   │
│ └──────────────────┘   │
│ ┌──────────────────┐   │
│ │ Card             │   │
│ └──────────────────┘   │
├────────────────────────┤
│ 🏠  ☰  🔖  🔍         │  ← bottom nav
└────────────────────────┘
```

### Card Design

Each card in the grid:

```
┌─────────────────────────────────┐
│ [Image — 16:9, lazy loaded]     │
├─────────────────────────────────┤
│ ● Source name        2h ago     │  ← favicon + name + timestamp
│                                 │
│ Article Title Goes Here         │  ← font-weight: 600 if unread
│ Maybe Two Lines Long            │     font-weight: 400 if read
│                                 │
│ Summary preview text truncated  │  ← 2 lines max, muted color
│ to two lines with ellipsis...   │
│                                 │
│ 🔖                              │  ← bookmark toggle, appears on hover
└─────────────────────────────────┘
```

- Unread indicator: green dot (●) before source name
- Read state: title weight drops, dot disappears, card slightly muted
- No border on cards — shadow only on hover (`box-shadow: 0 2px 8px rgba(0,0,0,0.08)`)
- Card click marks as read + opens article (new tab or detail view)
- Bookmark icon fades in on hover, toggles via Alpine.js XHR

### Sidebar Design

```
[favicon] Today                    ← bold if has unread
[icon]    All Items      124       ← unread count badge
[icon]    Bookmarks
[icon]    Search

FEEDS                              ← section label, uppercase, 11px, muted

▾ AI / Tech              36       ← collapsible group, count = total unread
    [fav] Hacker News    12
    [fav] Simon Willison  8
    [fav] ArXiv cs.AI    16

▾ Research                4
    [fav] The Batch        4

+ Add Feed                         ← bottom of sidebar
```

- Active item: accent-colored left border (3px), light surface background
- Hover: surface background only
- Unread counts: muted gray pill, disappear when zero
- Group collapse state persisted to DB via XHR

---

## Feed Refresh Strategy

### CLI Script (`bin/refresh-feeds`)

Run via cron every 15–30 minutes:

```
*/15 * * * * /usr/bin/php /path/to/pulse/bin/refresh-feeds
```

The script:
1. Queries all distinct feed URLs
2. Fetches each feed (HTTP with proper User-Agent, ETag/Last-Modified support)
3. Parses RSS/Atom (use `simplepie/simplepie` or custom parser)
4. Deduplicates items by GUID
5. Extracts OG image from item content or page meta
6. Inserts new items, updates `last_fetched_at`
7. Logs errors per feed to `fetch_error` column

### Feed Parser Requirements

- Handle RSS 2.0, Atom 1.0, RSS 1.0
- Respect `<media:content>` and `<enclosure>` for images
- Extract OG image via HTTP HEAD + meta parse when no feed image present
- Store raw `<content:encoded>` if available, fall back to `<description>`
- Truncate summary to 300 characters for storage

---

## Features

### Feed Management

- Add feed by URL (auto-detect RSS from HTML page URL)
- Feeds can be ungrouped or assigned to a group
- Groups are collapsible, sortable (drag-and-drop via Alpine.js, order persisted)
- Remove feed removes all its items and read status for that user
- Force-refresh single feed from management page

### Read/Unread Tracking

- Clicking a card marks it read (optimistic UI via Alpine.js, XHR confirm)
- "Mark all read" button per feed and per group
- Unread counts shown in sidebar, update without page reload
- Items older than 30 days auto-marked read (CLI cleanup job)

### Bookmarks

- Toggle from card hover state or article detail view
- Optional note field on bookmark (added from detail view)
- Dedicated `/bookmarks` view with same card grid layout
- Bookmarks never auto-expire

### Search

- SQLite FTS5 full-text search across title, summary, content
- Search scoped to current user's subscribed feeds only
- Results sorted by relevance then date
- Highlight matching terms in results (Twig filter)
- FTS index updated on item insert via SQLite trigger

### OPML Import/Export

**Export:** Generates valid OPML 2.0 with feed groups as `<outline>` folders

**Import:**
- Accepts OPML 2.0 file upload
- Parses feed URLs, creates groups from folder structure
- Queues feeds for fetch (does not block response)
- Reports import summary (X feeds added, Y already existed, Z failed)

### Email Digest (AWS SES)

- Per-user setting: daily or weekly, at a chosen time
- Digest contains top N unread items from last period
- Sorted by feed group, then by published date
- HTML email template (DOMPDF not needed here — SES accepts HTML directly)
- "Send now" option for immediate test
- CLI command `bin/send-digests` runs on schedule, checks per-user timing

---

## Authentication

- Session-based auth (Symfony HttpFoundation sessions)
- Passwords hashed with `password_hash()` / `PASSWORD_BCRYPT`
- Login rate limiting: 5 attempts per 15 minutes per IP (tracked in SQLite)
- Remember-me token (secure cookie, 30 days)
- No OAuth in v1 — email/password only
- Admin: first registered user is admin (can manage all users)

---

## Quality Requirements

### PHPStan

- Level 9 + `phpstan/phpstan-strict-rules`
- No `mixed` types anywhere
- All return types explicit
- Strict comparison everywhere

```neon
# phpstan.neon
parameters:
    level: 9
    paths:
        - src
    strictRules:
        disallowedLooseComparison: true
        booleansInConditions: true
```

### PHP-CS-Fixer

PSR-12 + opinionated extras:

```php
// .php-cs-fixer.php
return (new Config())
    ->setRules([
        '@PSR12' => true,
        'strict_param' => true,
        'array_syntax' => ['syntax' => 'short'],
        'ordered_imports' => true,
        'no_unused_imports' => true,
        'declare_strict_types' => true,
    ]);
```

### PHPUnit

- Unit tests for all Domain objects and Application handlers
- Integration tests for repository implementations (real SQLite, in-memory)
- No mocking of repositories in integration tests
- Coverage target: 80% on `src/Domain` and `src/Application`

---

## Composer Dependencies

```json
{
    "require": {
        "php": "^8.4",
        "symfony/http-foundation": "^7.0",
        "symfony/routing": "^7.0",
        "twig/twig": "^3.0",
        "simplepie/simplepie": "^1.8",
        "aws/aws-sdk-php": "^3.0",
        "dompdf/dompdf": "^2.0"
    },
    "require-dev": {
        "phpunit/phpunit": "^11.0",
        "phpstan/phpstan": "^1.10",
        "phpstan/phpstan-strict-rules": "^1.5",
        "friendsofphp/php-cs-fixer": "^3.0"
    }
}
```

---

## Environment Configuration

Use a simple `.env` file parsed manually (no Dotenv library needed):

```env
APP_ENV=production
APP_SECRET=changeme

DB_PATH=/var/db/pulse.sqlite

AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
SES_FROM_EMAIL=digest@yourdomain.com
SES_FROM_NAME=Pulse

APP_URL=https://yourdomain.com
```

---

## Build Notes for Claude Code

- Start with DB migrations, then Domain objects, then Repositories, then Handlers, then Controllers, then Templates
- Run PHPStan after each layer is complete — do not accumulate errors
- Tailwind 4 is configured via CSS `@import` — no `tailwind.config.js` needed
- Alpine.js loaded via CDN in base template (`<script defer src="...">`)
- Chart.js loaded via CDN, only on pages that need it
- No build step required for PHP — Tailwind 4 CDN or CLI output to `public/css/app.css`
- Favicons fetched and cached locally in `public/favicons/{domain}.ico` at feed-add time
- All XHR responses return JSON `{"success": true}` or `{"error": "message"}`
- CSRF token required on all POST requests (stored in session, verified in middleware)

---

## Starter Feed List (seed data)

On first run, offer to seed these feeds:

```
AI / Tech (group)
  - Hacker News          https://news.ycombinator.com/rss
  - Simon Willison       https://simonwillison.net/atom/everything/
  - The Verge AI         https://www.theverge.com/rss/ai-artificial-intelligence/index.xml
  - MIT Tech Review AI   https://www.technologyreview.com/feed/

Research (group)
  - ArXiv cs.AI          https://rss.arxiv.org/rss/cs.AI
  - ArXiv cs.LG          https://rss.arxiv.org/rss/cs.LG

Newsletters (group)
  - Interconnects        https://www.interconnects.ai/feed
  - The Batch            https://www.deeplearning.ai/the-batch/feed/

Reddit (group)
  - r/MachineLearning    https://www.reddit.com/r/MachineLearning.rss
  - r/artificial         https://www.reddit.com/r/artificial.rss
```
