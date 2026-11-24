// Prints an Umbraco JSON log (UmbracoTraceLog*.json, or a runs/runN.json copy) as a timeline:
// time, thread, level, logger and message, with the message placeholders filled in.
//
// Usage: node timeline.mjs <log file> [from] [to]
//   from and to are times as HH:MM:SS.mmm, to show only part of the log.
//
// Example: the lines that show the URL rebuild and the indexing thread overlapping
//   node timeline.mjs runs/run5.json | grep -E "Rebuilding all|WriteLock for id -34[58]|Unattended upgrade|ContentIndexer"
import fs from 'node:fs';

const [file, from = '', to = '99'] = process.argv.slice(2);
if (!file) {
  console.error('Usage: node timeline.mjs <log file> [from] [to]');
  process.exit(1);
}

for (const line of fs.readFileSync(file, 'utf8').split('\n')) {
  if (!line.trim()) continue;
  let e;
  try { e = JSON.parse(line); } catch { continue; }
  const t = e['@t'].slice(11, 23);
  if (t < from || t > to) continue;
  const msg = e['@mt'].replace(/\{@?(\w+)(:[^}]*)?\}/g, (m, k) => (e[k] !== undefined ? e[k] : m));
  // The install writes thousands of schema lines; leave them out
  if (/^(Create (table|Index)|New table|Creating data|Completed creating data)/.test(msg)) continue;
  const src = (e.SourceContext || '').split('.').pop();
  console.log(`${t} T${String(e.ThreadId).padEnd(3)} ${(e['@l'] || 'Info').padEnd(7)} ${src}: ${msg.slice(0, 170).replace(/\s+/g, ' ')}`);
}
