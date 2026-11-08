#!/usr/bin/env node
// Static site builder for pages/.
//
// Node built-ins only; zero npm dependencies, zero runtime JS on the output.
// Markdown is converted to HTML at build time.
//
// Cloudflare Pages settings:
//   Build command:           node pages/build.mjs
//   Build output directory:  pages
//
// Output: pages/<name>.html for humans and pages/<name>.md (same content,
// raw markdown with rewritten absolute links) for AI agents.

import { promises as fs } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const PAGES_DIR = path.join(REPO_ROOT, 'pages');
const GITHUB_BASE = 'https://github.com/lighttransport/usdspec-conformance';
const SITE_NAME = 'usdspec-conformance';

// Site manifest. `src` is repo-root-relative markdown; `out` is the output
// base name. `label` is the nav label; `title` overrides <title>.
const PAGES = [
  { src: 'pages/src/index.md', out: 'index', label: 'Home', title: 'USD Core Spec: Lean formalization and conformance' },
  { src: 'doc/STATUS.md', out: 'status', label: 'Status' },
  { src: 'verif/lean/README.md', out: 'formalization', label: 'Lean formalization' },
  { src: 'verif/lean/REFLECTION.md', out: 'reflection', label: 'Reflection' },
  { src: 'verif/lean/ISSUES.md', out: 'findings', label: 'Spec findings' },
  { src: 'doc/validation/verification-2026-11-07.md', out: 'verification', label: 'Verification report' },
  { src: 'doc/validation/lean-followup-status.md', out: 'ledger', label: 'Execution ledger' },
];

const OWN_PAGE = new Map(); // normalized repo-relative .md path -> output name
for (const p of PAGES) OWNER_init(p);
function OWNER_init(p) {
  if (p.out !== 'index') OWN_PAGE.set(path.posix.normalize(path.posix.join('.', p.src)), p.out);
}

const warnings = [];

// ---------------------------------------------------------------------------
// HTML escaping and inline markdown
// ---------------------------------------------------------------------------

function escapeHtml(s) {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

// Render inline markdown (code spans, links, bold, italic, hard breaks).
// Assumes no raw HTML in the source (everything is escaped first).
function inline(text) {
  let s = escapeHtml(text);
  const stash = [];
  // Inline code first, stashed so later passes cannot touch its content.
  s = s.replace(/`([^`]+)`/g, (_m, c) => {
    const i = stash.length;
    stash.push(`<code>${c}</code>`);
    return `\u0000${i}\u0000`;
  });
  // Links. href and text are already escaped; link-rewrite ran at the
  // markdown level, so hrefs are final here.
  s = s.replace(/\[([^\]]+)\]\(([^()\s]+)\)/g, (_m, t, href) => `<a href="${href}">${t}</a>`);
  // Bold then italic.
  s = s.replace(/\*\*([^*\n]+)\*\*/g, '<strong>$1</strong>');
  s = s.replace(/(^|[^*\w])\*([^*\n]+)\*(?![*\w])/g, '$1<em>$2</em>');
  // Restore stashed code spans.
  s = s.replace(/\u0000(\d+)\u0000/g, (_m, i) => stash[Number(i)] ?? '');
  if (s.includes('\u0000')) warnings.push(`unresolved inline placeholder in: ${text.slice(0, 80)}`);
  return s;
}

// ---------------------------------------------------------------------------
// Markdown blocks
// ---------------------------------------------------------------------------

const LIST_RE = /^(\s*)([-*+]|\d+[.)])\s+(.*)$/;

function isBlank(l) {
  return !l.trim();
}

function splitRow(line) {
  let s = line.trim();
  // Remove one leading and one trailing pipe, and split on unescaped pipes
  // that are not inside backticks.
  if (s.startsWith('|')) s = s.slice(1);
  if (s.endsWith('|') && !s.endsWith('\\|')) s = s.slice(0, -1);
  const cells = [];
  let cur = '';
  let code = 0;
  for (let i = 0; i < s.length; i++) {
    const ch = s[i];
    if (ch === '\\') {
      // Literal pipe escape.
      if (s[i + 1] === '|') { cur += '|'; i++; continue; }
      cur += ch; i++; if (i < s.length) { cur += s[i]; }
      continue;
    }
    if (ch === '`') code ^= 1;
    if (ch === '|' && !code) { cells.push(cur); cur = ''; continue; }
    cur += ch;
  }
  cells.push(cur);
  return cells.map((c) => c.trim());
}

function isSeparatorRow(cells) {
  return cells.length > 0 && cells.every((c) => /^:?-{1,}:?$/.test(c));
}

function parseTable(lines, i) {
  const head = splitRow(lines[i]);
  const sep = splitRow(lines[i + 1]);
  const aligns = sep.map((c) => {
    const l = c.startsWith(':');
    const r = c.endsWith(':');
    return l && r ? 'center' : r ? 'right' : 'left';
  });
  i += 2;
  const rows = [];
  while (i < lines.length && /^\s*\|/.test(lines[i])) {
    rows.push(splitRow(lines[i]));
    i++;
  }
  const th = head
    .map((c, j) => `<th${aligns[j] && aligns[j] !== 'left' ? ` style="text-align:${aligns[j]}"` : ''}>${inline(c)}</th>`)
    .join('');
  let html = `<table><thead><tr>${th}</tr></thead><tbody>\n`;
  for (const r of rows) {
    const tds = r
      .map((c, j) => `<td${aligns[j] && aligns[j] !== 'left' ? ` style="text-align:${aligns[j]}"` : ''}>${inline(c)}</td>`)
      .join('');
    html += `<tr>${tds}</tr>\n`;
  }
  html += '</tbody></table>\n';
  return { html, next: i };
}

function parseFence(lines, i) {
  const open = lines[i].match(/^(\s*)(`{3,}|~{3,})\s*(\S*)\s*$/);
  const marker = open[2];
  const lang = open[3].replace(/[^A-Za-z0-9_-]/g, '');
  i++;
  const body = [];
  while (i < lines.length && !new RegExp(`^\\s*${marker[0]}{3,}\\s*$`).test(lines[i])) {
    body.push(lines[i]);
    i++;
  }
  i++; // closing fence
  const cls = lang ? ` class="language-${lang}"` : '';
  return { html: `<pre><code${cls}>${escapeHtml(body.join('\n'))}</code></pre>\n`, next: i };
}

function headingText(t) {
  return t.replace(/`([^`]+)`/g, '$1').replace(/\[([^\]]+)\]\([^)]*\)/g, '$1');
}

let anchorSeen = new Map();
function anchorId(text) {
  let id = textOfHeading(text)
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9_\- ]+/g, '')
    .replace(/\s+/g, '-')
    .replace(/^-+|-+$/g, '');
  if (!id) id = 'section';
  const n = anchorSeen.get(id) ?? 0;
  anchorSeen.set(id, n + 1);
  return n === 0 ? id : `${id}-${n}`;
}
const textOfHeading = headingText;

function parseBlockquote(lines, i) {
  const inner = [];
  while (i < lines.length) {
    const m = lines[i].match(/^\s*>?\s?(.*)$/);
    if (lines[i].trim() === '>') { inner.push(''); i++; continue; }
    if (/^\s*>/.test(lines[i])) { inner.push(lines[i].replace(/^\s*>\s?/, '')); i++; continue; }
    // Quoted paragraph continuation without '>'.
    if (inner.length && /\S/.test(lines[i]) && !startsWithBlock(lines[i])) { inner.push(lines[i]); i++; continue; }
    break;
  }
  return { html: `<blockquote>\n${blocks(inner)}\n</blockquote>\n`, next: i };
}

function startsWithBlock(line) {
  return (
    LIST_RE.test(line) ||
    /^(#{1,6})\s/.test(line) ||
    /^\s{0,3}(`{3,}|~{3,})/.test(line) ||
    /^\s*>/.test(line) ||
    /^\s{0,3}([-*_])(\s*\1){2,}\s*$/.test(line) ||
    (/^\s*\|/.test(line) && isSeparatorRow(splitRow(line)))
  );
}

function parseList(lines, i) {
  const first = lines[i].match(LIST_RE);
  const baseIndent = first[1].length;
  const ordered = /\d/.test(first[2][0]);
  const items = [];
  while (i < lines.length) {
    if (isBlank(lines[i])) {
      // A blank line is list-internal only if another same-level item follows.
      let j = i + 1;
      while (j < lines.length && isBlank(lines[j])) j++;
      const m = lines[j] && lines[j].match(LIST_RE);
      if (m && m[1].length >= baseIndent && m[1].length <= baseIndent + 1) { i = j; continue; }
      break;
    }
    const m = lines[i].match(LIST_RE);
    if (!m) break;
    if (m[1].length < baseIndent) break;
    if (m[1].length >= baseIndent + 2 && items.length > 0) {
      const sub = parseList(lines, i);
      items[items.length - 1].children.push(sub.html);
      i = sub.next;
      continue;
    }
    const item = { text: [m[3]], children: [] };
    i++;
    while (i < lines.length) {
      const l = lines[i];
      if (isBlank(l)) break;
      const cont = l.match(/^(\s*)(\S.*)$/);
      if (cont && cont[1].length >= baseIndent + 2 && !LIST_RE.test(l) && !startsWithBlock(l)) {
        item.text.push(cont[2]);
        i++;
        continue;
      }
      break;
    }    items.push(item);
  }
  const tag = ordered ? 'ol' : 'ul';
  let html = `<${tag}>\n`;
  for (const it of items) {
    // Single inline pass over the joined item text: inline markers (bold,
    // links, code) may span wrapped continuation lines.
    html += `<li>${inline(it.text.join(' '))}`;
    for (const c of it.children) html += c;
    html += `</li>\n`;
  }
  html += `</${tag}>\n`;
  return { html, next: i };
}

function isInterrupt(line) {
  return isBlank(line) || startsWithBlock(line) || (/^\s*\|/.test(line));
}

function parseParagraph(lines, i) {
  const parts = [];
  while (i < lines.length && !isInterrupt(lines[i])) {
    parts.push(lines[i]);
    i++;
  }
  // Single inline pass over the joined text; inline markers may span wrapped
  // lines (none of the sources use two-space hard breaks).
  let html = inline(parts.join(' '));
  html += '\n';
  return { html: html.trim() ? `<p>${html.trim()}\n</p>\n` : '', next: i };
}

function blocks(lines) {
  let out = '';
  let i = 0;
  let prev = -1;
  while (i < lines.length) {
    if (i === prev) {
      throw new Error(
        `markdown parser made no progress at line ${i + 1}: ${JSON.stringify(lines[i].slice(0, 120))}`,
      );
    }
    prev = i;
    const line = lines[i];
    if (isBlank(line)) { i++; continue; }
    if (/^\s{0,3}(`{3,}|~{3,})/.test(line)) {
      const r = parseFence(lines, i);
      out += r.html; i = r.next; continue;
    }
    const h = line.match(/^(#{1,6})\s+(.+?)(\s+#+\s*)?$/);
    if (h) {
      const lvl = h[1].length;
      const text = h[2].trim();
      out += `<h${lvl} id="${escapeHtml(anchorId(text))}">${inline(text)}</h${lvl}>\n`;
      i++;
      continue;
    }
    if (/^\s{0,3}([-*_])(\s*\1){2,}\s*$/.test(line)) { out += '<hr>\n'; i++; continue; }
    if (/^\s*\|/.test(line) && i + 1 < lines.length && isSeparatorRow(splitRow(lines[i + 1]))) {
      const r = parseTable(lines, i);
      out += r.html; i = r.next; continue;
    }
    if (/^\s*>/.test(line)) {
      const r = parseBlockquote(lines, i);
      out += r.html; i = r.next; continue;
    }
    if (LIST_RE.test(line)) {
      const r = parseList(lines, i);
      out += r.html; i = r.next; continue;
    }
    const p = parseParagraph(lines, i);
    out += p.html; i = p.next;
  }
  return out;
}

// ---------------------------------------------------------------------------
// Markdown-level link rewriting (for both .html and agent-facing .md output)
// ---------------------------------------------------------------------------

function existsInRepo(rel) {
  return fs.access(path.join(REPO_ROOT, rel)).then(
    () => fs.stat(path.join(REPO_ROOT, rel)),
    () => null,
  );
}

const SITE_PAGE_NAMES = new Set(PAGES.map((p) => p.out));

async function rewriteLinkHref(dir, href) {
  if (/^(https?:|mailto:)/i.test(href) || href.startsWith('#')) return href;
  if (href.endsWith('.html')) return href; // site-internal link
  // Agent-facing .md copies (e.g. ./status.md written inside a page's own
  // markdown): keep on-site if the basename names one of the site pages.
  const mdBase = path.posix.basename(href);
  if (href.endsWith('.md') && SITE_PAGE_NAMES.has(mdBase.replace(/\.md$/, ''))) {
    return href.startsWith('.') ? href : `./${mdBase}`;
  }
  const [body, frag] = href.split('#');
  const rel = path.posix.normalize(path.posix.join(dir, body));
  const own = OWN_PAGE.get(rel);
  if (own) return `./${own}.html${frag ? `#${frag}` : ''}`;
  const st = await existsInRepo(rel);
  const kind = st ? (st.isDirectory() ? 'tree' : 'blob') : 'blob';
  if (!st) {
    warnings.push(`link target not found in repo: ${rel} (from ${dir})`);
  }
  return `${GITHUB_BASE}/${kind}/HEAD/${rel}${frag ? `#${frag}` : ''}`;
}

const LINK_RE = /\]\(([^()\s]+)\)/g;

async function main() {
  // Resolve all link rewrites first (they can be async).
  const prepared = [];
  for (const p of PAGES) {
    const full = path.join(REPO_ROOT, p.src);
    let src;
    try {
      src = await fs.readFile(full, 'utf8');
    } catch (e) {
      throw new Error(`build.mjs: cannot read ${p.src}: ${e.message}`);
    }
    const dir = path.posix.dirname(path.posix.normalize(p.src));
    const lines = src.replace(/\r\n?/g, '\n').split('\n');
    let inFence = false;
    const rewritten = [];
    for (const line of lines) {
      if (/^\s{0,3}(`{3,}|~{3,})/.test(line)) { inFence = !inFence; rewritten.push(line); continue; }
      if (inFence) { rewritten.push(line); continue; }
      const parts = line.split(/(`[^`]*`)/);
      const doneParts = [];
      for (let k = 0; k < parts.length; k++) {
        const part = parts[k];
        if (k % 2 === 1) { doneParts.push(part); continue; }
        // Find links and resolve their hrefs (sequentially; docs are small).
        const segs = [];
        for (const m of part.matchAll(LINK_RE)) {
          const start = m.index; // replace the whole '](' ... ')'
          const end = m.index + m[0].length;
          segs.push({ start, end, href: await rewriteLinkHref(dir, m[1]) });
        }
        let built = '';
        let last = 0;
        for (const s of segs) {
          built += part.slice(last, s.start) + `](${s.href})`;
          last = s.end;
        }
        built += part.slice(last);
        doneParts.push(built);
      }
      rewritten.push(doneParts.join(''));
    }
    prepared.push({ page: p, md: rewritten.join('\n') });
  }

  // Convert and write.
  await fs.mkdir(PAGES_DIR, { recursive: true });
  for (const { page, md } of prepared) {    anchorSeen = new Map();
    const firstH1 = md.match(/^#\s+(.+?)\s*$/m);
    const title = page.title ?? (firstH1 ? headingText(firstH1[1]).trim() : page.out);
    const body = blocks(md.replace(/\r\n?/g, '\n').split('\n'));
    const nav = PAGES.map((q) => `<a href="./${q.out}.html"${q.out === page.out ? ' aria-current="page"' : ''}>${q.label}</a>`).join('\n    ');
    const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escapeHtml(`${title} — ${SITE_NAME}`)}</title>
<link rel="stylesheet" href="./style.css">
</head>
<body>
<header class="site-header">
  <div class="wrap">
    <a class="home" href="./index.html">${SITE_NAME}</a>
    <nav>
    ${nav}
    </nav>
  </div>
</header>
<main>
${body}
</main>
<footer class="site-footer">
  <div class="wrap">
    <p>An independent project by Light Transport Entertainment Inc. Not affiliated with or endorsed by the Alliance for OpenUSD (AOUSD).
    Source: <a href="${GITHUB_BASE}">github.com/lighttransport/usdspec-conformance</a>.
    Each page is also available as raw markdown for AI agents at the same path with a <code>.md</code> extension.</p>
  </div>
</footer>
</body>
</html>
`;
    await fs.writeFile(path.join(PAGES_DIR, `${page.out}.html`), html, 'utf8');
    if (page.src !== `pages/${page.out}.md`) {
      await fs.writeFile(path.join(PAGES_DIR, `${page.out}.md`), `${md}\n`, 'utf8');
    }
    console.log(`wrote pages/${page.out}.html (${md.length} bytes markdown)`);
  }

  // 404 page (served by the Workers assets config's not_found_handling).
  const notFound = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>404 Not found — ${SITE_NAME}</title>
<link rel="stylesheet" href="./style.css">
</head>
<body>
<header class="site-header">
  <div class="wrap">
    <a class="home" href="./index.html">${SITE_NAME}</a>
  </div>
</header>
<main>
  <h1>404 — page not found</h1>
  <p>The requested page does not exist on this site. Try the <a href="./index.html">home page</a> or one of these:</p>
  <p>${PAGES.filter((p) => p.out !== 'index')
    .map((p) => `<a href="./${p.out}.html">${p.label}</a>`)
    .join(' &middot; ')}</p>
</main>
</body>
</html>
`;
  await fs.writeFile(path.join(PAGES_DIR, '404.html'), notFound, 'utf8');
  console.log('wrote pages/404.html');
}

main().then(
  () => {
    for (const w of warnings) console.error(`warning: ${w}`);
    if (warnings.length) console.error(`build finished with ${warnings.length} warning(s)`);
    else console.log('build finished cleanly');
  },
  (e) => {
    console.error(e);
    process.exitCode = 1;
  },
);
