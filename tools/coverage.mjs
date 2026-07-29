#!/usr/bin/env node
/**
 * Coverage audit: which API capabilities are not reachable from any UI.
 *
 * An endpoint nobody calls is either a gap in the apps or dead weight in the
 * API. Either way it needs a decision, so it is listed rather than ignored.
 */
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";

const ROOT = new URL("..", import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1");

function walk(dir, test, out = []) {
  for (const name of readdirSync(dir)) {
    if (["node_modules", ".next", ".expo", "bin", "obj"].includes(name)) continue;
    const path = join(dir, name);
    let s;
    try { s = statSync(path); } catch { continue; }
    if (s.isDirectory()) walk(path, test, out);
    else if (test(name)) out.push(path);
  }
  return out;
}

const norm = (p) => ("/" + p.replace(/^\/+/, ""))
  .replace(/\$\{[^}]+\}/g, "{x}").replace(/\{[^}]*\}/g, "{x}").replace(/\{x\}:\w+/g, "{x}").replace(/\/+$/, "");

const routes = [];
for (const f of walk(join(ROOT, "api/src/Diti365.Api/Controllers/V2"), (n) => n.endsWith(".cs"))) {
  const src = readFileSync(f, "utf8");
  const base = src.match(/\[Route\("([^"]+)"\)\]/)?.[1] ?? "";
  for (const m of src.matchAll(/\[Http(Get|Post|Put|Patch|Delete)(?:\("([^"]*)"\))?/g)) {
    const p = m[2] ?? "";
    routes.push({
      verb: m[1].toUpperCase(),
      path: norm(p.startsWith("/") ? p : `${base}/${p}`),
      file: relative(ROOT, f),
    });
  }
}

const calls = new Set();
for (const dir of ["apps/web/src", "apps/mobile"]) {
  for (const f of walk(join(ROOT, dir), (n) => /\.tsx?$/.test(n))) {
    const src = readFileSync(f, "utf8");
    for (const m of src.matchAll(/\.(get|post|put|patch|delete)<[^>]*>\(\s*[`"']([^`"']+)/g))
      calls.add(`${m[1].toUpperCase()} ${norm(m[2])}`);
    /*  Any /api/v2 path appearing anywhere in a UI file counts as reached,
        for any verb. FieldForm takes `endpoint` as a JSX prop, the punch screen
        picks its endpoint with a ternary, and reports open a download URL - all
        real usages that a stricter pattern misses, producing a gap list full of
        endpoints that are in fact wired.  */
    for (const m of src.matchAll(/\/api\/v2\/[\w\-{}$/.]+/g))
      for (const v of ["GET", "POST", "PUT", "PATCH", "DELETE"]) calls.add(`${v} ${norm(m[0])}`);
  }
}

const reached = ({ verb, path }) => {
  const want = path.split("/");
  for (const c of calls) {
    const [v, p] = c.split(" ");
    if (v !== verb) continue;
    const have = p.split("/");
    if (have.length !== want.length) continue;
    if (want.every((seg, i) => seg === "{x}" || have[i] === "{x}" || have[i] === seg)) return true;
  }
  return false;
};

const gaps = routes.filter((r) => !reached(r));
console.log(`${routes.length} v2 endpoints, ${routes.length - gaps.length} reachable from a UI, ${gaps.length} not\n`);

if (gaps.length) {
  const byFile = new Map();
  for (const g of gaps) {
    const k = g.file.split("/").pop();
    byFile.set(k, [...(byFile.get(k) ?? []), `${g.verb} ${g.path}`]);
  }
  for (const [file, list] of [...byFile].sort()) {
    console.log(`  ${file}`);
    for (const l of list.sort()) console.log(`      ${l}`);
  }
}
