#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

function stripStringsAndComments(source) {
  const chars = source.split('');
  let state = 'code';

  for (let i = 0; i < chars.length; i += 1) {
    const char = chars[i];
    const next = chars[i + 1] || '';

    if (state === 'code') {
      if (char === '/' && next === '/') {
        chars[i] = ' ';
        chars[i + 1] = ' ';
        i += 1;
        state = 'line-comment';
      } else if (char === '/' && next === '*') {
        chars[i] = ' ';
        chars[i + 1] = ' ';
        i += 1;
        state = 'block-comment';
      } else if (char === '"' || char === "'") {
        chars[i] = ' ';
        state = char === '"' ? 'double-string' : 'single-string';
      }
      continue;
    }

    if (state === 'line-comment') {
      if (char === '\n') state = 'code';
      else chars[i] = ' ';
      continue;
    }

    if (state === 'block-comment') {
      if (char === '*' && next === '/') {
        chars[i] = ' ';
        chars[i + 1] = ' ';
        i += 1;
        state = 'code';
      } else if (char !== '\n') {
        chars[i] = ' ';
      }
      continue;
    }

    if (char === '\\') {
      chars[i] = ' ';
      if (i + 1 < chars.length && chars[i + 1] !== '\n') {
        chars[i + 1] = ' ';
        i += 1;
      }
    } else if ((state === 'double-string' && char === '"') ||
               (state === 'single-string' && char === "'")) {
      chars[i] = ' ';
      state = 'code';
    } else if (char !== '\n') {
      chars[i] = ' ';
    }
  }

  return chars.join('');
}

function lineNumberAt(source, offset) {
  let line = 1;
  for (let i = 0; i < offset; i += 1) {
    if (source[i] === '\n') line += 1;
  }
  return line;
}

function inspectFile(filename) {
  const source = fs.readFileSync(filename, 'utf8');
  const clean = stripStringsAndComments(source);
  const declarations = new Map();
  const declarationPattern = /\bfunction\s+([A-Za-z_$][A-Za-z0-9_$]*)\s*\(/g;
  let match;

  while ((match = declarationPattern.exec(clean)) !== null) {
    const nameOffset = match.index + match[0].indexOf(match[1]);
    declarations.set(match[1], nameOffset);
  }

  const failures = [];
  for (const [name, declarationOffset] of declarations) {
    const callPattern = new RegExp(`\\b${name}\\s*\\(`, 'g');
    while ((match = callPattern.exec(clean)) !== null) {
      const offset = match.index;
      if (offset === declarationOffset) continue;

      const previous = offset > 0 ? clean[offset - 1] : '';
      if (previous === '.') continue;

      const prefix = clean.slice(Math.max(0, offset - 16), offset);
      if (/function\s+$/.test(prefix)) continue;

      if (offset < declarationOffset) {
        failures.push({
          name,
          callLine: lineNumberAt(clean, offset),
          declarationLine: lineNumberAt(clean, declarationOffset),
        });
        break;
      }
    }
  }

  return failures;
}

function collectUcodeFiles(target, result) {
  const stat = fs.statSync(target);
  if (stat.isFile()) {
    if (target.endsWith('.uc')) result.push(target);
    return;
  }

  for (const entry of fs.readdirSync(target, { withFileTypes: true })) {
    collectUcodeFiles(path.join(target, entry.name), result);
  }
}

const targets = process.argv.slice(2);
if (targets.length === 0) {
  process.stderr.write('Usage: check_ucode_declaration_order.js <file-or-directory> [...]\n');
  process.exit(2);
}

const files = [];
for (const target of targets) collectUcodeFiles(target, files);

let failed = false;
for (const filename of files.sort()) {
  for (const failure of inspectFile(filename)) {
    failed = true;
    process.stderr.write(
      `${filename}:${failure.callLine}: ${failure.name}() is called before its declaration on line ${failure.declarationLine}\n`,
    );
  }
}

if (failed) process.exit(1);
process.stdout.write(`ucode declaration order checks passed (${files.length} files)\n`);
