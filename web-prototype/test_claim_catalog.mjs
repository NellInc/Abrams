// The browser decoder must feed the native callback the same visitor-derived
// pixels as the desktop source oracle. No original bytes are printed or saved.
import {execFileSync} from 'node:child_process';
import {readdir, readFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {buildClaimCatalog} from './claim_catalog.mjs';

const root = new URL('../', import.meta.url);
const game = new URL('GAME/', root);
const originals = new Map();
for (const name of await readdir(game))
  originals.set(name.toUpperCase(), new Uint8Array(await readFile(new URL(name, game))));
const browser = buildClaimCatalog(originals);
const desktop = execFileSync('python3', ['web-prototype/claim_catalog.py', 'GAME'], {
  cwd: fileURLToPath(root), maxBuffer: 1024 * 1024,
});
if (!Buffer.from(browser).equals(desktop))
  throw new Error('Browser source catalog differs from desktop source oracle');
console.log(`PASS: ${browser.length} visitor-derived claim catalog bytes match desktop`);
