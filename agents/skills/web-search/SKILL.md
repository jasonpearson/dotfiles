---
name: web-search
description: Find current information, discover sources, and extract web page text with the DDGS CLI when built-in web tools are unavailable or this skill is explicitly requested.
allowed-tools: Bash(ddgs:*)
---

# Web search

Assume `ddgs` is already installed and available on `PATH`. Use it directly;
no API key or background service is needed.

Prefer built-in web tools when available, unless the user explicitly requests
DDGS or this skill. Use DDGS for search and readable page text; use browser
tooling for interaction or JavaScript rendering.

## Search

```sh
ddgs text -q "mise dotfiles documentation" -m 5 -nc </dev/null
```

Start with a small result set. Add `-t d`, `-t w`, `-t m`, or `-t y` when recency
matters, or use `site:example.com` in the query to focus on a source.
Redirect stdin as shown to avoid interactive per-result prompts.

Search returns titles, URLs, and snippets. Fetch the relevant pages before
making claims that snippets alone cannot establish, and cite the source URLs.

## Read a page

```sh
page_file=$(mktemp "${TMPDIR:-/tmp}/web-search.XXXXXX")
ddgs extract -u "https://mise.jdx.dev/dotfiles.html" -f text_markdown > "$page_file"
wc -c "$page_file"
head -c 15000 "$page_file"
```

Keep the full extraction in the temporary file. If it exceeds the displayed
excerpt, read or search the relevant remaining sections and make clear when
your answer relies on only part of the page.

DDGS can print an error while returning a successful exit code; inspect the
output before treating a search or extraction as successful. Pages requiring
JavaScript or login may return little useful text. Use available browser tools
or the `agent-browser` skill when needed, respecting the host's skill invocation
policy. If neither is available, report the limitation. Do not silently switch
to a paid search provider.

For other options, consult `ddgs text --help` or `ddgs extract --help`.
