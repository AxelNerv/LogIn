import fs from 'fs/promises';

const inputFile = 'locales/calls.json';
const outputFile = 'locales/loghorizon.pot';
const projectId = 'LOGHORIZON';

/**
 * The template is authored by the project, not by whichever machine ran the
 * generator. This used to read `git config user.name/email`, which embedded an
 * upstream contact on machines without a git identity and a personal address
 * on machines with one, making the .pot differ per machine. `.invalid` is the
 * RFC 2606 reserved domain, so it can never belong to anybody.
 */
function getPotAuthor() {
  return {
    name: 'logIn',
    email: 'locales@loghorizon.invalid',
  };
}

function getPotHeader({ name, email }) {
  const now = new Date();
  const date = now.toISOString().replace('T', ' ').slice(0, 16);
  const offset = -now.getTimezoneOffset();
  const sign = offset >= 0 ? '+' : '-';
  const hours = String(Math.floor(Math.abs(offset) / 60)).padStart(2, '0');
  const minutes = String(Math.abs(offset) % 60).padStart(2, '0');
  const timezone = `${sign}${hours}${minutes}`;

  return [
    '# SOME DESCRIPTIVE TITLE.',
    `# Copyright (C) ${now.getFullYear()} THE PACKAGE'S COPYRIGHT HOLDER`,
    `# This file is distributed under the same license as the ${projectId} package.`,
    `# ${name} <${email}>, ${now.getFullYear()}.`,
    '#, fuzzy',
    'msgid ""',
    'msgstr ""',
    `"Project-Id-Version: ${projectId}\\n"`,
    `"Report-Msgid-Bugs-To: \\n"`,
    `"POT-Creation-Date: ${date}${timezone}\\n"`,
    `"PO-Revision-Date: ${date}${timezone}\\n"`,
    `"Last-Translator: ${name} <${email}>\\n"`,
    `"Language-Team: LANGUAGE <LL@li.org>\\n"`,
    `"Language: \\n"`,
    `"MIME-Version: 1.0\\n"`,
    `"Content-Type: text/plain; charset=UTF-8\\n"`,
    `"Content-Transfer-Encoding: 8bit\\n"`,
    '',
  ].join('\n');
}

function escapePoString(str) {
  return str.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
}

function generateEntry(item) {
  const locations = item.places.map((loc) => `#: ${loc}`).join('\n');
  const msgid = escapePoString(item.key);
  return [locations, `msgid "${msgid}"`, `msgstr ""`, ''].join('\n');
}

async function generatePot() {
  const potAuthor = getPotAuthor();
  const raw = await fs.readFile(inputFile, 'utf8');
  const entries = JSON.parse(raw);

  const header = getPotHeader(potAuthor);
  const body = entries.map(generateEntry).join('\n');

  await fs.writeFile(outputFile, `${header}\n${body}`, 'utf8');

  console.log(`✅ POT-файл успешно создан: ${outputFile}`);
}

generatePot().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
