import { existsSync, readdirSync, statSync, createReadStream, writeFileSync, mkdirSync } from 'node:fs';
import { createServer } from 'node:http';
import { createServer as portProbe } from 'node:net';
import { dirname, extname, join, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';
import { stopChild, waitForExit } from './flutter-tools.mjs';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const project = join(root, 'godot_game');
const args = process.argv.slice(2);
const native = args.includes('--windows');
const onlyBuild = args.includes('--build');
const noOpen = args.includes('--no-open') || process.env.npm_config_open === 'false';
const noHand = args.includes('--no-hand') || process.env.npm_config_hand === 'false';
const portOption = args.find(a => a.startsWith('--port='));
const port = Number(portOption ? portOption.slice(7) : process.env.npm_config_port || 8080);
if (!Number.isInteger(port) || port < 1 || port > 65535 || args.some(a => !['--windows', '--build', '--no-open', '--no-hand'].includes(a) && a !== portOption)) {
  console.error('Cách chạy: npm run web [-- --no-open --port=8081]');
  process.exit(1);
}
const tools = join(root, '.cache', 'godot');
const candidates = existsSync(tools) ? readdirSync(tools).filter(n => n.endsWith('_console.exe')).map(n => join(tools, n)) : [];
const godot = process.env.GODOT_EXE || candidates.sort().at(-1);
let worker, python, server;
let stopping = false;
function stop(code = 0) {
  if (stopping) return;
  stopping = true;
  server?.close();
  stopChild(worker);
  stopChild(python);
  process.exit(code);
}
for (const signal of ['SIGINT', 'SIGTERM']) process.once(signal, () => stop());

async function freePort(number) {
  const probe = portProbe();
  await new Promise((ok, fail) => {
    probe.once('error', () => fail(new Error(`Cổng ${number} đang được dùng. Dừng lần chạy cũ bằng Ctrl+C rồi thử lại.`)));
    probe.listen(number, '127.0.0.1', ok);
  });
  await new Promise(ok => probe.close(ok));
}

async function build(arguments_) {
  worker = spawn(godot, ['--headless', '--path', project, ...arguments_], { cwd: root, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] });
  let failed = false;
  const log = bytes => {
    const value = bytes.toString();
    if (/SCRIPT ERROR|^ERROR:/m.test(value)) failed = true;
    if (!value.includes('savepack |') && !value.includes('first_scan_filesystem |')) process.stdout.write(value);
  };
  worker.stdout.on('data', log);
  worker.stderr.on('data', log);
  if (await waitForExit(worker) !== 0 || failed) throw new Error('Chưa tạo được game 3D. Xem thông báo phía trên.');
  worker = null;
}

function openBrowser(url) {
  const opener = process.platform === 'win32'
    ? spawn(join(process.env.SystemRoot || 'C:\\Windows', 'System32', 'rundll32.exe'), ['url.dll,FileProtocolHandler', url], { windowsHide: true, stdio: 'ignore' })
    : spawn(process.platform === 'darwin' ? 'open' : 'xdg-open', [url], { stdio: 'ignore' });
  opener.on('error', () => console.log(`Mở trình duyệt tại ${url}`));
  opener.unref();
}

async function startHand(origin) {
  if (noHand) return;
  await freePort(8766);
  const executable = join(root, '.venv', process.platform === 'win32' ? 'Scripts/python.exe' : 'bin/python');
  if (!existsSync(executable)) throw new Error('Chưa có Python .venv. Có thể chơi chuột bằng tùy chọn --no-hand.');
  python = spawn(executable, ['-u', join(root, 'main.py'), '--port', '8766', '--idle-timeout', '0',
    '--origin', origin, '--origin', origin.replace('127.0.0.1', 'localhost')], {
    cwd: root, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'], env: { ...process.env, PYTHONIOENCODING: 'utf-8' },
  });
  await new Promise((ok, fail) => {
    const timer = setTimeout(() => fail(new Error('Dịch vụ tay chưa sẵn sàng sau 15 giây.')), 15000);
    const log = bytes => {
      const value = bytes.toString();
      process.stdout.write(value);
      if (value.includes('HAND_SERVICE_READY')) { clearTimeout(timer); ok(); }
    };
    python.stdout.on('data', log);
    python.stderr.on('data', log);
    python.once('error', error => { clearTimeout(timer); fail(error); });
    python.once('exit', code => { clearTimeout(timer); fail(new Error(`Dịch vụ tay đã dừng (${code}).`)); });
  });
  python.once('exit', () => { if (!stopping) stop(1); });
}

try {
  if (!godot || !existsSync(godot)) throw new Error('Chưa có Godot. Chạy: powershell -ExecutionPolicy Bypass -File scripts/setup-godot.ps1');
  mkdirSync(join(project, 'build', native ? 'windows' : 'web'), { recursive: true });
  writeFileSync(join(project, 'build', '.gdignore'), '');
  console.log('Đang chuẩn bị DEAD SIGNAL 3D…');
  await build(['--editor', '--import']);
  await build(['--export-release', native ? 'Windows' : 'Web']);
  if (onlyBuild) process.exit(0);
  const origin = `http://127.0.0.1:${port}`;
  if (!native) await freePort(port);
  await startHand(origin);
  if (native) {
    worker = spawn(join(project, 'build', 'windows', 'DeadSignal3D.exe'), [], { cwd: project, windowsHide: false, stdio: 'inherit' });
    stop(await waitForExit(worker));
  } else {
    const base = resolve(project, 'build', 'web');
    const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png', '.svg': 'image/svg+xml' };
    server = createServer((request, response) => {
      let pathname;
      try { pathname = decodeURIComponent(new URL(request.url, origin).pathname); }
      catch { response.writeHead(400).end(); return; }
      const path = resolve(base, `.${pathname === '/' ? '/index.html' : pathname}`);
      if (!path.startsWith(base + sep) || !existsSync(path) || !statSync(path).isFile()) { response.writeHead(404).end(); return; }
      response.writeHead(200, { 'Content-Type': types[extname(path)] || 'application/octet-stream', 'Cache-Control': 'no-store', 'Cross-Origin-Opener-Policy': 'same-origin', 'Cross-Origin-Embedder-Policy': 'require-corp' });
      if (request.method === 'HEAD') { response.end(); return; }
      const stream = createReadStream(path);
      stream.on('error', () => response.destroy());
      stream.pipe(response);
    });
    server.listen(port, '127.0.0.1', () => {
      console.log(`\nDEAD SIGNAL 3D: ${origin}\nGiữ terminal mở. Ctrl+C để dừng game và dịch vụ tay.\n`);
      if (!noOpen) openBrowser(origin);
    });
    server.on('error', error => { console.error(error.message); stop(1); });
  }
} catch (error) { console.error(`Không mở được game 3D: ${error.message}`); stop(1); }
