import {readdirSync, readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {describe, expect, it} from 'vitest';

const dist = resolve(process.cwd(), 'build');
const read = (path: string) => readFileSync(resolve(dist, path), 'utf8');
const findSearchIndex = (localeDir = '') => {
  const dir = resolve(dist, localeDir);
  const file = readdirSync(dir).find((entry) => /^search-index-[a-f0-9]+\.json$/.test(entry));
  if (!file) throw new Error(`search index missing for ${localeDir || 'en'}`);
  return readFileSync(resolve(dir, file), 'utf8');
};

describe('Qbit AI Toolkit documentation build', () => {
  it('renders English root and Persian RTL locale', () => {
    const en = read('index.html');
    const fa = read('fa/index.html');
    expect(en).toContain('lang=en-US');
    expect(en).toContain('dir=ltr');
    expect(fa).toContain('lang=fa-IR');
    expect(fa).toContain('dir=rtl');
  });

  it('preserves representative documentation routes', () => {
    expect(read('getting-started.html')).toContain('Getting');
    expect(read('fa/getting-started.html')).toContain('شروع');
    expect(read('ai-tools.html')).toContain('AI Tools');
  });

  it('ships local search indexes for both locales', () => {
    expect(findSearchIndex()).toContain('Prompt Engineering');
    expect(findSearchIndex('fa')).toContain('مهندسی پرامپت');
  });
});
