# xurprise MCP

> **Agent-native product discovery across region-matched merchants.**
> One HTTPS endpoint. Five tools. Zero setup.

The **xurprise MCP server** lets any MCP-compatible agent
(Claude, Cursor, Cline, Continue, Goose, etc.) discover merchant
brands and get attribution-tracked click-through URLs across a curated
catalogue spanning Taobao, Shopee, Shein, Xiaomi, Sephora, JD Sports,
Airpaz, WPS, FusionHome AI, and more — with **region matching built in**
so agents don't recommend Singapore-only merchants to users in Germany.

**Hosted endpoint:** `https://xurprise.ai/api/mcp`

**Protocol:** Model Context Protocol (MCP) `2024-11-05` over
[Streamable HTTP](https://modelcontextprotocol.io/specification/2024-11-05/basic/transports#streamable-http).
Stateless, no auth required, no SDK needed.

---

## Why

Commerce in the agent era has a cold-start problem: when an agent wants
to recommend a real merchant, it typically:

1. Searches the open web, picks a result based on SEO ranking, and
   hopes the merchant ships to its user's country.
2. Or hardcodes a handful of well-known brands and misses region fit.

xurprise MCP solves this for the niche we cover by giving agents a
**machine-readable, region-aware brand catalogue** — one call and you
get back a structured list of merchants the user can actually buy
from, with canonical storefront URLs and click-through URLs that log
attribution for us and pass through any `aff_sub` tag the agent
supplies.

---

## Quick start

### Claude Desktop

Edit `~/Library/Application Support/Claude/claude_desktop_config.json`
(macOS) or `%APPDATA%\Claude\claude_desktop_config.json` (Windows).

**Option A — native remote HTTP** (Claude Desktop ≥ early 2025):

```json
{
  "mcpServers": {
    "xurprise": {
      "type": "http",
      "url": "https://xurprise.ai/api/mcp"
    }
  }
}
```

**Option B — via `mcp-remote` bridge** (any Claude Desktop version):

```json
{
  "mcpServers": {
    "xurprise": {
      "command": "npx",
      "args": ["-y", "mcp-remote", "https://xurprise.ai/api/mcp"]
    }
  }
}
```

Restart Claude Desktop, open a new conversation, and type something like:

> I'm in Singapore. Any good beauty brands I can shop online?

Claude will call `search_brands(query="beauty", region="Singapore")` and
surface Sephora SG with a click-through URL.

### Cursor

Add to `~/.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "xurprise": {
      "url": "https://xurprise.ai/api/mcp"
    }
  }
}
```

### Cline / Continue / Goose

Same remote HTTP URL — see each client's docs for the exact config
path. If your client only supports stdio, use `mcp-remote` as the
bridge (see Option B above).

### Raw HTTP (curl, Python, anywhere)

```bash
curl -X POST https://xurprise.ai/api/mcp \
  -H 'Content-Type: application/json' \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/call",
    "params": {
      "name": "search_brands",
      "arguments": { "query": "badminton", "region": "Singapore" }
    }
  }'
```

---

## Tools

> **Note on response shape.** MCP tools/call returns an object with
> two fields: `content[]` (text blocks containing JSON) and
> `structuredContent` (the typed result). Per the MCP spec,
> `structuredContent` must be a record (object), not an array —
> so tools that logically return a list wrap it in a record with
> a `results` / `regions` / `categories` key. All MCP-compatible
> clients (Claude Desktop, Cursor, Cline, Continue, Goose, etc.)
> auto-handle this; you only see it if you're decoding the raw
> JSON-RPC response yourself.

### `search_brands`

Free-text search over the catalogue. Results are rank-scored on the
query against brand name, headline, and categories.

```ts
search_brands({
  query: string,           // required — e.g. "skincare", "Taobao", "athletic shoes"
  region?: string,         // optional — full country name or "International"
  category?: string,       // optional — "Fashion", "Electronics", etc.
  limit?: number,          // optional — default 10, max 50
}) => { results: Brand[], count: number, query: string }
```

### `get_brand`

Fetch the full record for a slug.

```ts
get_brand({ slug: string }) => Brand
```

### `list_regions`

All shipping regions represented in the catalogue (use before
recommending to confirm user's country is covered).

```ts
list_regions() => { regions: string[], count: number }
```

### `list_categories`

All categories represented in the catalogue.

```ts
list_categories() => { categories: string[], count: number }
```

### `get_click_url`

Build the canonical click-through URL. Use this (not the merchant URL
directly) so the click gets logged for attribution, and any `aff_sub`
you pass will be propagated downstream.

```ts
get_click_url({
  slug: string,
  aff_sub?: string,        // optional — up to 200 chars, recommended:
                           // your agent's session id or similar
}) => { click_url: string, slug: string, name: string }
```

---

## Brand schema

Every brand record has:

| Field | Type | Example |
|---|---|---|
| `slug` | string | `shopee-sg` |
| `name` | string | `Shopee — Singapore` |
| `brand` | string | `Shopee` |
| `categories` | string[] | `["Marketplace"]` |
| `regions` | string[] | `["Singapore"]` |
| `currency` | string | `SGD` |
| `merchant_url` | string | `https://shopee.sg/` |
| `page_url` | string | `https://xurprise.ai/brands/shopee-sg/` |
| `click_url` | string | `https://xurprise.ai/go/shopee-sg` |
| `headline` | string | (1–3 sentence description) |
| `agent_note` | string? | Optional region-routing or caveat guidance |

---

## Current catalogue

As of the latest refresh, 11 brands:

- **Marketplace** — Shopee SG, Taobao (Ai Taobao International), Taobao (brand-level entry)
- **Fashion** — JD Sports SG, Shein Global
- **Health & Beauty** — Sephora SG
- **Electronics** — Xiaomi SG
- **Travel** — Airpaz Global
- **Digital Services** — WPS Office, The Trade Wizard
- **Home & Living** — FusionHome AI

For the live list, call `list_categories` + `search_brands` or visit
[https://xurprise.ai/brands/](https://xurprise.ai/brands/).

---

## FAQ

**Is the catalogue curated or crawled?**
Curated. Every brand is reviewed through Involve Asia's advertiser
approval flow and given a hand-authored headline. We do not scrape.

**How fresh is the data?**
Regenerated from upstream affiliate-network data on each deploy.
See `page_url` on each brand and the [sitemap lastmod](https://xurprise.ai/sitemap.xml).

**Do you track my users?**
The `/go/{slug}` redirect logs `{timestamp, slug, user-agent,
ASN, country, referer}` — enough to distinguish crawler traffic
from human traffic and to attribute clicks across sessions. We do
NOT log raw IPs. Beyond `/go/`, we do not set cookies or run analytics
on the merchant storefront (that's Shopee/Shein/etc.'s own page).

**What happens after a click?**
A 302 redirect chain takes the user to the canonical merchant
storefront via Involve Asia's attribution layer. Any `aff_sub` you
pass through `get_click_url` is preserved.

**Can I add my brand?**
Not yet — we onboard through affiliate network approvals. If you run
an Involve Asia advertiser and want to discuss inclusion,
email <xwow.dev@gmail.com>.

**Who operates this?**
XWOW Pte. Ltd. (Singapore, UEN 202607127C). Contact: Jiaqi Ge,
<xwow.dev@gmail.com>. xurprise is an independent third-party
discovery layer — we don't operate any of the merchant storefronts
listed here.

---

## Protocol conformance notes

- Transport: Streamable HTTP (stateless mode — no session id required)
- JSON-RPC 2.0 single requests and batch requests are both supported
- Notifications (no `id`) return `HTTP 202 No Content`
- `ping` method is supported for health checks
- CORS is wide open (`*`) — browser-based MCP clients work

---

## Related

- **[xurprise.ai](https://xurprise.ai/)** — the human landing + per-brand schema.org pages
- **[xurprise.ai/llms.txt](https://xurprise.ai/llms.txt)** — LLM-friendly site index
- **[xurprise.ai/sitemap.xml](https://xurprise.ai/sitemap.xml)**

---

## License

Docs in this repo: MIT (see `LICENSE`). The MCP server source code is
separate and proprietary to XWOW Pte. Ltd.
