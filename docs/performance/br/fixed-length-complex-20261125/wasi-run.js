const fs = require('node:fs');
const crypto = require('node:crypto');
const { WASI } = require('node:wasi');
(async () => {
  const file = process.argv[2];
  const bytes = fs.readFileSync(file);
  const wasi = new WASI({ version: 'preview1', args: ['fixed-length-tests'], env: {}, preopens: { '/': '/' }, returnOnExit: true });
  const module = await WebAssembly.compile(bytes);
  const instance = await WebAssembly.instantiate(module, { wasi_snapshot_preview1: wasi.wasiImport });
  const exit = wasi.start(instance) ?? 0;
  console.log(JSON.stringify({ schema: 'vort.fixed-length-wasi-test.v1', exit_code: exit, wasm_sha256: crypto.createHash('sha256').update(bytes).digest('hex'), imports: WebAssembly.Module.imports(module) }));
  process.exitCode = exit;
})().catch(error => { console.error(error); process.exitCode = 1; });
