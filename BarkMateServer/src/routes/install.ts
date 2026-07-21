/**
 * BarkMate CLI installer + documentation endpoints.
 *
 * - GET /install.sh         → text/x-shellscript (curl-piped installer)
 * - GET /uninstall.sh       → text/x-shellscript (curl-piped uninstaller)
 * - GET /docs/cli-setup     → text/html (rendered docs page)
 * - GET /docs/cli-setup.md  → text/markdown (raw, for `curl`)
 *
 * Source files are bundled via wrangler `rules: type=Text`:
 * - ../../scripts/install.sh.txt
 * - ../../scripts/uninstall.sh.txt
 * - ../../docs/cli-setup.md
 *
 * Markdown→HTML is a tiny inline renderer that only covers the subset used
 * by cli-setup.md (headings, **bold**, `code`, ``` blocks, > quote,
 * - lists, GFM tables, [links], paragraphs). Add cases here, not deps.
 */

import { Hono } from 'hono';
import type { Bindings } from '../types';
import installScript from '../../scripts/install.sh.txt';
import uninstallScript from '../../scripts/uninstall.sh.txt';
import cliSetupMarkdown from '../../docs/cli-setup.md';

export const installRoute = new Hono<{ Bindings: Bindings }>();

installRoute.get('/install.sh', (c) =>
  c.body(installScript, 200, {
    'content-type': 'text/x-shellscript; charset=utf-8',
    'cache-control': 'public, max-age=300',
  }),
);

installRoute.get('/uninstall.sh', (c) =>
  c.body(uninstallScript, 200, {
    'content-type': 'text/x-shellscript; charset=utf-8',
    'cache-control': 'public, max-age=300',
  }),
);

installRoute.get('/docs/cli-setup', (c) =>
  c.html(renderHtml(cliSetupMarkdown), 200, {
    'cache-control': 'public, max-age=3600',
  }),
);

installRoute.get('/docs/cli-setup.md', (c) =>
  c.body(cliSetupMarkdown, 200, {
    'content-type': 'text/markdown; charset=utf-8',
    'cache-control': 'public, max-age=3600',
  }),
);

// ── Tiny markdown renderer (subset; see file header for supported syntax) ──

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function renderInline(s: string): string {
  // Stash `code spans` first so ** and [] inside them aren't re-interpreted.
  const stash: string[] = [];
  let r = s.replace(/`([^`]+)`/g, (_m, c: string) => {
    stash.push(c);
    return `@@BARKMATE_CODE_${stash.length - 1}@@`;
  });
  r = escapeHtml(r);
  r = r.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
  r = r.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');
  r = r.replace(/@@BARKMATE_CODE_(\d+)@@/g, (_m, i: string) => {
    const raw = stash[Number(i)] ?? '';
    return `<code>${escapeHtml(raw)}</code>`;
  });
  return r;
}

function slugify(s: string): string {
  return s
    .toLowerCase()
    .replace(/[^\w一-龥]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

function renderBody(md: string): string {
  const lines = md.split('\n');
  const out: string[] = [];
  let i = 0;

  while (i < lines.length) {
    const line = lines[i] ?? '';

    if (line.startsWith('```')) {
      const lang = line.slice(3).trim();
      const buf: string[] = [];
      i++;
      while (i < lines.length && !(lines[i] ?? '').startsWith('```')) {
        buf.push(lines[i] ?? '');
        i++;
      }
      i++; // closing ```
      const safeLang = escapeHtml(lang || 'text');
      out.push(`<pre><code class="lang-${safeLang}">${escapeHtml(buf.join('\n'))}</code></pre>`);
      continue;
    }

    const h = /^(#{1,3})\s+(.*)$/.exec(line);
    if (h) {
      const level = (h[1] ?? '').length;
      const raw = h[2] ?? '';
      out.push(`<h${level} id="${slugify(raw)}">${renderInline(raw)}</h${level}>`);
      i++;
      continue;
    }

    if (line.startsWith('> ')) {
      const buf: string[] = [];
      while (i < lines.length && (lines[i] ?? '').startsWith('> ')) {
        buf.push((lines[i] ?? '').slice(2));
        i++;
      }
      out.push(`<blockquote>${renderInline(buf.join(' '))}</blockquote>`);
      continue;
    }

    if (/^- /.test(line)) {
      const items: string[] = [];
      while (i < lines.length && /^- /.test(lines[i] ?? '')) {
        items.push(`<li>${renderInline((lines[i] ?? '').slice(2))}</li>`);
        i++;
      }
      out.push(`<ul>${items.join('')}</ul>`);
      continue;
    }

    if (line.startsWith('|')) {
      const buf: string[] = [];
      while (i < lines.length && (lines[i] ?? '').startsWith('|')) {
        buf.push(lines[i] ?? '');
        i++;
      }
      const rows = buf.map((r) =>
        r
          .trim()
          .replace(/^\|/, '')
          .replace(/\|$/, '')
          .split('|')
          .map((c) => c.trim()),
      );
      const header = rows[0] ?? [];
      const body = rows.slice(2); // skip header + |---|---| separator
      const thead = `<thead><tr>${header.map((c) => `<th>${renderInline(c)}</th>`).join('')}</tr></thead>`;
      const tbody = `<tbody>${body
        .map((r) => `<tr>${r.map((c) => `<td>${renderInline(c)}</td>`).join('')}</tr>`)
        .join('')}</tbody>`;
      out.push(`<table>${thead}${tbody}</table>`);
      continue;
    }

    if (line.trim() === '') {
      i++;
      continue;
    }

    const buf: string[] = [];
    while (i < lines.length) {
      const cur = lines[i] ?? '';
      if (
        cur.trim() === '' ||
        /^#{1,3}\s/.test(cur) ||
        cur.startsWith('```') ||
        cur.startsWith('> ') ||
        /^- /.test(cur) ||
        cur.startsWith('|')
      )
        break;
      buf.push(cur);
      i++;
    }
    if (buf.length > 0) out.push(`<p>${renderInline(buf.join(' '))}</p>`);
  }

  return out.join('\n');
}

function renderHtml(md: string): string {
  return `<!doctype html>
<html lang="zh-Hans">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>BarkMate CLI 接入</title>
<style>
  :root { color-scheme: light dark; }
  body { font: 16px/1.65 -apple-system, "PingFang SC", "Helvetica Neue", Arial, sans-serif;
         max-width: 760px; margin: 2rem auto; padding: 0 1.2rem; color: #1a1a1a; }
  @media (prefers-color-scheme: dark) {
    body { background: #0e0e10; color: #ececec; }
    a { color: #7ab8ff; }
    code, pre { background: #1a1a1f; }
    th, td { border-color: #333; }
    blockquote { border-color: #444; color: #aaa; }
  }
  h1 { font-size: 1.7rem; margin-top: 2.4rem; }
  h2 { font-size: 1.25rem; margin-top: 2rem; border-bottom: 1px solid currentColor; padding-bottom: 0.3rem; opacity: 0.95; }
  h3 { font-size: 1.05rem; margin-top: 1.4rem; }
  table { border-collapse: collapse; width: 100%; margin: 0.6rem 0; font-size: 0.92rem; }
  th, td { border: 1px solid #ccc; padding: 6px 10px; text-align: left; vertical-align: top; }
  th { font-weight: 600; }
  code { font: 0.9em "SF Mono", Menlo, Consolas, monospace; background: rgba(127,127,127,0.12); padding: 1px 5px; border-radius: 3px; }
  pre { background: rgba(127,127,127,0.12); padding: 0.8rem 1rem; border-radius: 6px; overflow-x: auto; }
  pre code { background: none; padding: 0; }
  blockquote { border-left: 3px solid #888; padding: 0.2rem 0 0.2rem 1rem; margin: 1rem 0; color: #555; }
  a { color: #0050b3; text-decoration: none; }
  a:hover { text-decoration: underline; }
</style>
</head>
<body>
${renderBody(md)}
</body>
</html>
`;
}
