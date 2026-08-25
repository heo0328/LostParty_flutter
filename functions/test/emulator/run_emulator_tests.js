import {
  existsSync,
  readFileSync,
  readdirSync,
  unlinkSync,
  writeFileSync,
} from 'node:fs';
import {resolve} from 'node:path';
import {spawnSync} from 'node:child_process';

const workspace = resolve(import.meta.dirname, '..', '..', '..');
const javaRoot = resolve(workspace, '.tools', 'temurin21');
const javaDirectory = readdirSync(javaRoot, {withFileTypes: true})
  .find((entry) => entry.isDirectory());
if (javaDirectory === undefined) {
  throw new Error('Portable Java 21 is missing from .tools/temurin21.');
}

const integrationCommand =
  'node functions/test/emulator/account_verification.integration.test.js';
const firebaseArgs = [
  'emulators:exec',
  '--project',
  'lost-party-emulator',
  '--only',
  'auth,firestore,functions',
  integrationCommand,
];
const command = process.platform === 'win32' ? process.execPath : 'firebase';
const commandArgs = process.platform === 'win32' ? [
  resolve(process.env.APPDATA, 'npm', 'node_modules', 'firebase-tools', 'lib',
    'bin', 'firebase.js'),
  ...firebaseArgs,
] : firebaseArgs;
const javaHome = resolve(javaRoot, javaDirectory.name);
const environmentFile = resolve(workspace, 'functions', '.env.local');
const secretFile = resolve(workspace, 'functions', '.secret.local');
const previousEnvironment = readOptionalFile(environmentFile);
const previousSecret = readOptionalFile(secretFile);
writeFileSync(environmentFile, 'LOST_ARK_API_BASE_URL=http://127.0.0.1:9999\n');
writeFileSync(secretFile, 'LOST_ARK_API_JWT=emulator-only-token\n');
let result;
try {
  const childEnvironment = {...process.env};
  delete childEnvironment.CODEX_SANDBOX_NETWORK_DISABLED;
  result = spawnSync(
    command,
    commandArgs,
    {
      cwd: workspace,
      stdio: 'inherit',
      env: {
        ...childEnvironment,
        JAVA_HOME: javaHome,
        PATH: `${resolve(javaHome, 'bin')}${process.platform === 'win32' ? ';' : ':'}${process.env.PATH}`,
        XDG_CONFIG_HOME: resolve(workspace, '.firebase-config'),
        FIREBASE_CLI_DISABLE_UPDATE_CHECK: 'true',
      },
    },
  );
} finally {
  restoreOptionalFile(environmentFile, previousEnvironment);
  restoreOptionalFile(secretFile, previousSecret);
}
if (result.error !== undefined) throw result.error;
if (result.status !== 0) {
  throw new Error(`Firebase Emulator exited with code ${result.status}.`);
}

function readOptionalFile(path) {
  return existsSync(path) ? readFileSync(path) : null;
}

function restoreOptionalFile(path, contents) {
  if (contents === null) {
    if (existsSync(path)) unlinkSync(path);
    return;
  }
  writeFileSync(path, contents);
}
