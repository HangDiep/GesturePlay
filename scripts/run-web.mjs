import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { createServer } from 'node:net';
import { spawn } from 'node:child_process';
import { root, findFlutter, startFlutter, waitForExit, stopChild } from './flutter-tools.mjs';

const args = process.argv.slice(2);
// npm.ps1 can consume `--` and expose flags as npm configuration instead.
const clearCache = args.includes('--clear') || process.env.npm_config_clear === 'true';
const noOpen = args.includes('--no-open') ||
  Object.hasOwn(process.env, 'npm_config_open') && !['true', '1'].includes(process.env.npm_config_open);
if (args.some(arg => !['--clear', '--no-open'].includes(arg))) {
  console.error('Cách chạy: npm run web -- --clear (thêm --no-open nếu không muốn tự mở trình duyệt)');
  process.exit(1);
}
const origin = 'http://127.0.0.1:8080';
const handPort = 8766;
let python, flutter, setup;
let stopping = false;

function stop(code = 0) {
  if (stopping) return;
  stopping = true;
  stopChild(flutter);
  stopChild(setup);
  stopChild(python);
  process.exit(code);
}
for (const signal of ['SIGINT', 'SIGTERM']) process.once(signal, () => stop());

async function requireFreePort(port) {
  const probe = createServer();
  await new Promise((resolve, reject) => {
    probe.once('error', () => reject(new Error(`Cổng ${port} đang được dùng. Đóng lần chạy trước rồi thử lại.`)));
    probe.listen(port, '127.0.0.1', resolve);
  });
  await new Promise(resolve => probe.close(resolve));
}

function openBrowser() {
  let opener;
  if (process.platform === 'win32') {
    opener = spawn(join(process.env.SystemRoot || 'C:\\Windows', 'System32', 'rundll32.exe'), ['url.dll,FileProtocolHandler', origin], { windowsHide: true, stdio: 'ignore' });
  } else {
    opener = spawn(process.platform === 'darwin' ? 'open' : 'xdg-open', [origin], { stdio: 'ignore' });
  }
  opener.on('error', () => console.log(`Mở trình duyệt tại ${origin}`));
  opener.unref();
}

try {
  const flutterPath = findFlutter();
  const pythonPath = join(root, '.venv', process.platform === 'win32' ? 'Scripts/python.exe' : 'bin/python');
  if (!existsSync(pythonPath)) throw new Error('Chưa có Python .venv. Xem phần cài môi trường trong README.md.');
  await requireFreePort(8080);
  await requireFreePort(handPort);
  if (clearCache) {
    console.log('Đang xóa bộ nhớ đệm biên dịch Flutter; thành tích vẫn được giữ.');
    setup = startFlutter(flutterPath, ['clean']);
    if (await waitForExit(setup) !== 0) throw new Error('Không làm sạch được bộ nhớ đệm Flutter.');
  }
  setup = startFlutter(flutterPath, ['pub', 'get']);
  let dependenciesReady = await waitForExit(setup) === 0;
  // On a fresh Windows checkout Flutter may write plugin metadata before
  // discovering that Developer Mode symlinks are unavailable. A second pass
  // uses the workspace junctions prepared from that newly written metadata.
  if (!dependenciesReady && process.platform === 'win32') {
    setup = startFlutter(flutterPath, ['pub', 'get']);
    dependenciesReady = await waitForExit(setup) === 0;
  }
  if (!dependenciesReady) throw new Error('Không chuẩn bị được thư viện Flutter.');
  setup = null;
  console.log('Đang mở dịch vụ Python nhận diện tay; webcam chỉ bật khi chọn chơi bằng tay.');
  python = spawn(pythonPath, ['-u', join(root, 'main.py'), '--port', String(handPort), '--idle-timeout', '0',
    '--origin', origin, '--origin', 'http://localhost:8080'], {
    cwd: root, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'],
    env: { ...process.env, PYTHONIOENCODING: 'utf-8' },
  });
  await new Promise((resolve, reject) => {
    const timeout = setTimeout(() => reject(new Error('Python chưa sẵn sàng sau 15 giây.')), 15000);
    const fail = code => { clearTimeout(timeout); reject(new Error(`Python đã dừng (mã ${code}). Kiểm tra thư viện trong .venv.`)); };
    python.once('error', error => { clearTimeout(timeout); reject(error); });
    python.once('exit', fail);
    const log = data => {
      const message = data.toString();
      process.stdout.write(message);
      if (message.includes('HAND_SERVICE_READY')) {
        clearTimeout(timeout);
        python.removeListener('exit', fail);
        resolve();
      }
    };
    python.stdout.on('data', log);
    python.stderr.on('data', log);
  });
  python.once('exit', code => {
    if (!stopping) { console.error(`Dịch vụ nhận diện đã dừng (${code}). Chạy lại npm run web.`); stop(1); }
  });
  flutter = startFlutter(flutterPath, ['run', '-d', 'web-server', '--web-hostname', '127.0.0.1', '--web-port', '8080', '--no-web-resources-cdn',
    `--dart-define=HAND_SERVICE_URL=ws://127.0.0.1:${handPort}`], ['inherit', 'pipe', 'pipe']);
  let opened = false;
  let output = '';
  const log = data => {
    const message = data.toString();
    process.stdout.write(message);
    output = (output + message).slice(-5000);
    if (!opened && output.includes('is being served at')) {
      opened = true;
      console.log(`\nGesturePlay: ${origin}\nGiữ terminal này mở. Nhấn Ctrl+C để dừng web và Python.\n`);
      if (!noOpen) openBrowser();
    }
  };
  flutter.stdout.on('data', log);
  flutter.stderr.on('data', log);
  stop(await waitForExit(flutter));
} catch (error) {
  console.error(`\nKhông mở được GesturePlay: ${error.message}`);
  stop(1);
}
