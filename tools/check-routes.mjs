#!/usr/bin/env node
/**
 * Fails the build if the web app calls an API route that does not exist.
 *
 * This caught a real one: the payroll screen posted to /payroll/runs/validate
 * when the API exposes GET /payroll/validate. TypeScript cannot see that -
 * a URL is just a string - so it would have shipped as a 404 that only
 * appeared when someone clicked "Validate".
 *
 * Run: node tools/check-routes.mjs   (or: pnpm check:routes)
 */
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";

const ROOT = new URL("..", import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1");
const CONTROLLERS = join(ROOT, "api/src/Diti365.Api/Controllers/V2");
const APPS = [
  { label: "web", dir: join(ROOT, "apps/web/src") },
  { label: "mobile", dir: join(ROOT, "apps/mobile") },
];

function walk(dir, test, out = []) {
  for (const name of readdirSync(dir)) {
    // node_modules is both enormous and full of symlinks that break stat() in
    // a pnpm workspace. Nothing we care about lives in there.
    if (name === "node_modules" || name === ".next" || name === ".expo") continue;
    const path = join(dir, name);
    let stat;
    try {
      stat = statSync(path);
    } catch {
      continue;
    }
    if (stat.isDirectory()) walk(path, test, out);
    else if (test(name)) out.push(path);
  }
  return out;
}

/** Route params, template holes and type constraints all collapse to {x}. */
function normalise(path) {
  return ("/" + path.replace(/^\/+/, ""))
    .replace(/\$\{[^}]+\}/g, "{x}")
    .replace(/\{[^}]*\}/g, "{x}")
    .replace(/\{x\}:\w+/g, "{x}")
    .replace(/\/+$/, "");
}

// ---------------------------------------------------------------- real routes
const real = new Set();
for (const file of walk(CONTROLLERS, (n) => n.endsWith(".cs"))) {
  const src = readFileSync(file, "utf8");
  const base = src.match(/\[Route\("([^"]+)"\)\]/)?.[1] ?? "";
  for (const m of src.matchAll(/\[Http(Get|Post|Put|Patch|Delete)(?:\("([^"]*)"\))?/g)) {
    const verb = m[1].toUpperCase();
    const path = m[2] ?? "";
    real.add(`${verb} ${normalise(path.startsWith("/") ? path : `${base}/${path}`)}`);
  }
}

/**
 * A `${...}` hole in a call may stand for an id OR for a literal segment -
 * `/recruits/${id}/${path}` is really /recruits/{id}/status and /convert. So a
 * hole matches any single segment. A fully literal call still has to match
 * exactly, which is what catches a genuinely wrong URL.
 */
function matchesSomeRoute(verb, callPath) {
  const want = normalise(callPath).split("/");
  for (const route of real) {
    const [rVerb, rPath] = route.split(" ");
    if (rVerb !== verb) continue;
    const have = rPath.split("/");
    if (have.length !== want.length) continue;
    if (want.every((seg, i) => seg === "{x}" || have[i] === "{x}" || have[i] === seg)) return true;
  }
  return false;
}

// ------------------------------------------------------------ what apps call
const problems = [];
let callCount = 0;

/*  Two shapes to find:
      getApi().get<T>("/api/v2/...")     - a direct read
      enqueue({ endpoint: "/api/v2/..." }) - a mobile write, which goes through
                                             the outbox and is always a POST  */
const DIRECT = /\.(get|post|put|patch|delete)<[^>]*>\(\s*[`"']([^`"']+)/g;
const QUEUED = /endpoint:\s*[`"']([^`"']+)/g;

for (const app of APPS) {
  for (const file of walk(app.dir, (n) => /\.tsx?$/.test(n))) {
    const src = readFileSync(file, "utf8");

    for (const m of src.matchAll(DIRECT)) {
      const [, verb, path] = m;
      if (!path.startsWith("/api/v2")) continue;
      callCount++;
      if (!matchesSomeRoute(verb.toUpperCase(), path))
        problems.push(`  ${verb.toUpperCase().padEnd(6)} ${path.padEnd(50)} ${relative(ROOT, file)}`);
    }

    for (const m of src.matchAll(QUEUED)) {
      const path = m[1];
      if (!path.startsWith("/api/v2")) continue;
      callCount++;
      if (!matchesSomeRoute("POST", path))
        problems.push(`  ${"QUEUE".padEnd(6)} ${path.padEnd(50)} ${relative(ROOT, file)}`);
    }
  }
}

console.log(`${real.size} API routes, ${callCount} calls from the web and mobile apps`);

if (problems.length > 0) {
  console.error(`\n${problems.length} call(s) point at a route that does not exist:\n`);
  console.error([...new Set(problems)].join("\n"));
  console.error("\nEither the path is wrong or the endpoint was never written.\n");
  process.exit(1);
}

console.log("every call resolves to a real route");
