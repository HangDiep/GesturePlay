import { root, findFlutter, startFlutter, waitForExit, stopChild } from './flutter-tools.mjs';

let child;
try {
  child = startFlutter(findFlutter(), ['run', '-d', 'windows', `--dart-define=GESTUREPLAY_ROOT=${root}`, ...process.argv.slice(2)]);
  for (const signal of ['SIGINT', 'SIGTERM']) process.once(signal, () => { stopChild(child); process.exit(0); });
  process.exitCode = await waitForExit(child);
} catch (error) {
  console.error(error.message);
  stopChild(child);
  process.exitCode = 1;
}
