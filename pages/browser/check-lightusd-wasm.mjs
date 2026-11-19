import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';

const directory = resolve(process.argv[2]);
const moduleURL = pathToFileURL(resolve(directory, 'lightusd.js'));
const {default: createModule} = await import(moduleURL.href);
const wasmBinary = await readFile(resolve(directory, 'lightusd.wasm'));
const native = await createModule({wasmBinary});
const document = new native.LayerDocument();
try {
  const fixture = '#usda 1.0\ndef Xform "SmokeTest" {}\n';
  const loaded = document.load(new TextEncoder().encode(fixture));
  assert.equal(loaded.success, true, loaded.error);
  assert.match(document.exportUSDA().text, /def Xform "SmokeTest"/);
} finally {
  document.delete();
}
