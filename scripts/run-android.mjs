import { existsSync, mkdirSync, openSync, closeSync, readFileSync, writeFileSync, copyFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { spawn, spawnSync } from 'node:child_process';
import { root, appRoot, findFlutter, startFlutter, waitForExit, stopChild } from './flutter-tools.mjs';

const args = process.argv.slice(2);
let requestedAvd;
let graphics = 'auto';
let resetWindow = false;
for (let i = 0; i < args.length; i += 1) {
  if (args[i] === '--reset-window') resetWindow = true;
  else if (args[i] === '--avd' && args[i + 1] && !args[i + 1].startsWith('--')) requestedAvd = args[++i];
  else if (args[i] === '--gpu' && ['auto', 'host', 'swiftshader'].includes(args[i + 1])) graphics = args[++i];
  else {
    console.error('Cách chạy: npm run android (tùy chọn -- --avd Tên_giả_lập --gpu host|swiftshader|auto --reset-window)');
    process.exit(1);
  }
}
let child;
for (const signal of ['SIGINT', 'SIGTERM']) process.once(signal, () => {
  stopChild(child);
  // Keep the emulator open so the player can use it again.
  process.exit(0);
});

function capture(executable, commandArgs, timeout = 10000) {
  const result = spawnSync(executable, commandArgs, { encoding: 'utf8', windowsHide: true, timeout });
  if (result.error || result.status !== 0) throw new Error(result.error?.message || result.stderr?.trim() || 'Không chạy được công cụ Android.');
  return result.stdout;
}

function sdkFolder() {
  const properties = join(appRoot, 'android', 'local.properties');
  const configured = existsSync(properties)
    ? readFileSync(properties, 'utf8').match(/^sdk\.dir=(.+)$/m)?.[1].trim().replace(/\\:/g, ':').replace(/\\\\/g, '\\')
    : undefined;
  const candidates = [process.env.ANDROID_HOME, process.env.ANDROID_SDK_ROOT, configured,
    process.env.LOCALAPPDATA && join(process.env.LOCALAPPDATA, 'Android', 'Sdk')];
  const sdk = candidates.find(path => path && existsSync(join(path, 'platform-tools', process.platform === 'win32' ? 'adb.exe' : 'adb')));
  if (!sdk) throw new Error('Chưa tìm thấy Android SDK. Mở Android Studio → SDK Manager để cài SDK và Android Emulator.');
  return sdk;
}

function connected(adb) {
  return capture(adb, ['devices']).split(/\r?\n/)
    .map(line => line.match(/^(emulator-\d+)\s+device\b/)?.[1]).filter(Boolean);
}

function restoreWindow(name, folder) {
  const avdHome = process.env.ANDROID_AVD_HOME
    || join(process.env.ANDROID_USER_HOME || join(homedir(), '.android'), 'avd');
  const avdIndex = join(avdHome, `${name}.ini`);
  const avdPath = existsSync(avdIndex)
    ? readFileSync(avdIndex, 'utf8').match(/^path=(.+)$/m)?.[1].trim()
    : undefined;
  const deviceFolder = avdPath || join(avdHome, `${name}.avd`);
  const settingsPath = join(deviceFolder, 'emulator-user.ini');
  const configPath = join(deviceFolder, 'config.ini');
  const deviceConfig = existsSync(configPath) ? readFileSync(configPath, 'utf8') : '';
  const displayWidth = Number(deviceConfig.match(/^hw\.lcd\.width=(\d+)/m)?.[1]);
  const displayHeight = Number(deviceConfig.match(/^hw\.lcd\.height=(\d+)/m)?.[1]);
  // Keep the window usable after changing the emulated screen resolution.
  const longestSide = Math.max(displayWidth || 0, displayHeight || 0);
  const windowScale = longestSide > 0 ? Math.min(0.6, 660 / longestSide).toFixed(6) : '0.220000';
  let settings = existsSync(settingsPath) ? readFileSync(settingsPath, 'utf8') : '';
  if (existsSync(settingsPath)) {
    const backup = join(folder, `${name.replace(/[^a-zA-Z0-9_-]/g, '_')}-window-before-reset.ini`);
    if (!existsSync(backup)) copyFileSync(settingsPath, backup);
  }
  for (const [key, value] of [['window.x', '64'], ['window.y', '64'], ['window.scale', windowScale]]) {
    const line = new RegExp(`^${key.replaceAll('.', '\\.')}\\s*=.*$`, 'm');
    settings = line.test(settings) ? settings.replace(line, `${key} = ${value}`) : `${settings}\n${key} = ${value}\n`;
  }
  writeFileSync(settingsPath, settings, 'utf8');
  console.log('Đã khôi phục cửa sổ giả lập về vị trí và kích thước nhỏ; giữ nguyên dữ liệu Android.');
}

function launchEmulator(emulator, name) {
  const folder = join(root, '.cache');
  mkdirSync(folder, { recursive: true });
  if (resetWindow) restoreWindow(name, folder);
  const out = openSync(join(folder, 'android-launch.log'), 'w');
  const err = openSync(join(folder, 'android-launch-error.log'), 'w');
  try {
    // Redirect both streams: the emulator continues after its launcher exits.
    // A cold boot skips a stale snapshot without deleting app/user data.
    const launchArgs = ['-avd', name, '-no-snapshot-load', '-gpu', graphics, '-crash-report-mode', 'never'];
    if (graphics === 'swiftshader') launchArgs.push('-feature', '-Vulkan');
    const emulatorProcess = spawn(emulator, launchArgs, {
      // This child owns an interactive Qt window. Launch it visibly so that
      // startup dialogs can be brought to the foreground on Windows.
      detached: true, windowsHide: false, stdio: ['ignore', out, err],
    });
    emulatorProcess.on('error', error => console.error(`Không mở được giả lập: ${error.message}`));
    emulatorProcess.unref();
    return emulatorProcess;
  } finally { closeSync(out); closeSync(err); }
}

try {
  const flutter = findFlutter();
  const sdk = sdkFolder();
  const adb = join(sdk, 'platform-tools', process.platform === 'win32' ? 'adb.exe' : 'adb');
  const emulator = join(sdk, 'emulator', process.platform === 'win32' ? 'emulator.exe' : 'emulator');
  let devices = connected(adb);
  let launched;
  if (resetWindow && devices.length) throw new Error('Đóng giả lập đang mở trước khi dùng --reset-window để khôi phục cửa sổ.');
  if (devices.length > 1) throw new Error('Có nhiều giả lập đang mở. Đóng bớt để chọn đúng thiết bị chơi game.');
  if (devices.length && requestedAvd && capture(adb, ['-s', devices[0], 'emu', 'avd', 'name'], 5000).trim().split(/\r?\n/)[0] !== requestedAvd) {
    throw new Error(`Giả lập đang mở không phải ${requestedAvd}. Đóng giả lập đó rồi chạy lại lệnh.`);
  }
  if (!devices.length) {
    if (!existsSync(emulator)) throw new Error('Chưa cài Android Emulator. Mở SDK Manager → SDK Tools để cài.');
    const names = capture(emulator, ['-list-avds']).trim().split(/\r?\n/).filter(Boolean);
    const name = requestedAvd || names.find(n => n === 'Pixel_10_Pro_XL') || (names.length === 1 ? names[0] : undefined);
    if (!name || !names.includes(name)) throw new Error(`Chọn giả lập bằng --avd. Giả lập hiện có: ${names.join(', ') || 'chưa có; tạo trong Device Manager'}.`);
    console.log(`Đang mở ${name} (${graphics}); giữ cửa sổ giả lập mở trong lúc chơi.`);
    launched = launchEmulator(emulator, name);
  }
  console.log('Đang chờ Android khởi động…');
  const deadline = Date.now() + 180000;
  let device;
  while (Date.now() < deadline) {
    if (launched?.exitCode != null) throw new Error(`Giả lập đã dừng (mã ${launched.exitCode}). Xem .cache/android-launch.log và .cache/android-launch-error.log.`);
    devices = connected(adb);
    if (devices.length > 1) throw new Error('Có nhiều giả lập đang mở. Đóng bớt để chọn đúng thiết bị chơi game.');
    if (devices.length === 1) {
      try {
        if (capture(adb, ['-s', devices[0], 'shell', 'getprop', 'sys.boot_completed'], 5000).trim() === '1') {
          device = devices[0]; break;
        }
      } catch { /* Android's transport may reconnect while booting. */ }
    }
    await new Promise(resolve => setTimeout(resolve, 2000));
  }
  if (!device) throw new Error('Android chưa sẵn sàng. Đóng giả lập đang treo rồi chạy lại; xem .cache/android-launch-error.log. Không cần xóa dữ liệu giả lập.');
  console.log(`Đã kết nối ${device}. Đang chuẩn bị game…`);
  child = startFlutter(flutter, ['pub', 'get']);
  if (await waitForExit(child) !== 0) throw new Error('Chưa tải được thư viện Flutter. Kiểm tra mạng rồi chạy lại.');
  child = startFlutter(flutter, ['run', '-d', device, '--no-pub']);
  process.exitCode = await waitForExit(child);
} catch (error) {
  console.error(error.message);
  stopChild(child);
  process.exitCode = 1;
}
