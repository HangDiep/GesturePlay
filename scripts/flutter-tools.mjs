import { existsSync, readdirSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn, spawnSync } from 'node:child_process';

export const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
export const appRoot = join(root, 'flutter_app');

export function findFlutter() {
  const executable = process.platform === 'win32' ? 'flutter.bat' : 'flutter';
  const candidates = [];
  if (process.env.FLUTTER_ROOT) candidates.push(join(process.env.FLUTTER_ROOT, 'bin', executable));
  const located = spawnSync(process.platform === 'win32' ? 'where.exe' : 'which', [executable], {
    encoding: 'utf8', windowsHide: true,
  });
  if (located.status === 0) candidates.push(...located.stdout.trim().split(/\r?\n/));
  const downloads = join(homedir(), 'Downloads');
  if (existsSync(downloads)) {
    for (const name of readdirSync(downloads).filter(n => n.startsWith('flutter_windows_')).sort().reverse()) {
      candidates.push(join(downloads, name, 'flutter', 'bin', executable));
    }
  }
  const flutter = candidates.find(path => existsSync(path));
  if (!flutter) throw new Error('Chưa tìm thấy Flutter. Thêm Flutter/bin vào PATH hoặc đặt FLUTTER_ROOT.');
  return flutter;
}

export function startFlutter(flutter, args, stdio = 'inherit') {
  if (process.platform === 'win32') {
    const prepared = spawnSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
      '-File', join(root, 'scripts', 'prepare-windows-plugins.ps1'), '-ProjectDirectory', appRoot], {
      windowsHide: true, encoding: 'utf8',
    });
    if (prepared.status !== 0) throw new Error(prepared.stderr || 'Không chuẩn bị được thư viện Windows.');
  }
  // PowerShell passes an argument array to flutter.bat without composing shell
  // text from paths or user input. This also supports project paths with spaces.
  if (process.platform === 'win32') {
    return spawn(join(process.env.SystemRoot || 'C:\\Windows', 'System32', 'WindowsPowerShell', 'v1.0', 'powershell.exe'), [
      '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
      '-File', join(root, 'scripts', 'invoke-flutter.ps1'), '-FlutterExecutable', flutter,
    ], {
      cwd: appRoot, stdio, windowsHide: true,
      env: { ...process.env, GESTUREPLAY_FLUTTER_ARGUMENTS: JSON.stringify(args) },
    });
  }
  return spawn(flutter, args, { cwd: appRoot, stdio });
}

export function waitForExit(child) {
  return new Promise((resolve, reject) => {
    child.once('error', reject);
    child.once('exit', code => resolve(code ?? 1));
  });
}

export function stopChild(child) {
  if (!child || child.exitCode !== null || child.signalCode !== null) return;
  if (process.platform === 'win32') {
    spawnSync('taskkill.exe', ['/PID', String(child.pid), '/T', '/F'], { windowsHide: true, stdio: 'ignore' });
  } else {
    child.kill('SIGTERM');
  }
}
