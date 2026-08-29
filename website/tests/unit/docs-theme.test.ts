import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {describe, expect, it} from 'vitest';

const config = readFileSync(resolve(process.cwd(), 'docusaurus.config.ts'), 'utf8');
const css = readFileSync(resolve(process.cwd(), 'src/css/custom.css'), 'utf8');

describe('documentation platform contract', () => {
  it('keeps bilingual Docusaurus search enabled', () => {
    expect(config).toContain("locales: ['en', 'fa']");
    expect(config).toContain("'@easyops-cn/docusaurus-search-local'");
    expect(config).toContain("indexDocs: true");
    expect(config).toContain("indexPages: true");
  });

  it('uses the shared Qbit visual and RTL contract', () => {
    expect(css).toContain('--ifm-color-primary: #357da1');
    expect(css).toContain('--ifm-font-size-base: 16px');
    expect(css).toContain('"Vazirmatn Variable"');
    expect(css).toContain('padding-inline');
    expect(css).toContain('margin-inline');
    expect(css).toContain('border-inline-end');
    expect(css).toContain('text-align: start');

    for (const pattern of [
      /\bpadding-(?:left|right)\s*:/g,
      /\bmargin-(?:left|right)\s*:/g,
      /\bborder-(?:left|right)(?:-[a-z-]+)?\s*:/g,
      /(?:^|[;{]\s*)(?:left|right)\s*:/gm,
    ]) {
      expect(css.match(pattern) ?? [], pattern.source).toEqual([]);
    }
  });
});
