import {existsSync, readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {describe, expect, it} from 'vitest';

const root = process.cwd();
const read = (path: string) => readFileSync(resolve(root, path), 'utf8');
const en = 'docs/prompt-engineering';
const fa = 'i18n/fa/docusaurus-plugin-content-docs/current/prompt-engineering';

describe('prompt-engineering documentation contract', () => {
  const newDocs = ['multimodal-prompting.md', 'code-prompting.md'];

  it('publishes synchronized English and Persian routes', () => {
    for (const file of newDocs) {
      expect(existsSync(resolve(root, '..', en, file))).toBe(true);
      expect(existsSync(resolve(root, fa, file))).toBe(true);
    }

    const englishIndex = read(`../${en}/index.md`);
    const persianIndex = read(`${fa}/index.md`);
    expect(englishIndex).toContain('Multimodal prompting');
    expect(englishIndex).toContain('Code prompting');
    expect(persianIndex).toContain('پرامپت‌نویسی چندوجهی');
    expect(persianIndex).toContain('پرامپت‌نویسی برای کد');
  });

  it('keeps named one-shot coverage synchronized', () => {
    expect(read(`../${en}/patterns.md`)).toContain('## One-shot prompting');
    expect(read(`${fa}/patterns.md`)).toContain('## One-shot prompting');
    expect(read(`../${en}/glossary-and-references.md`)).toContain('| One-shot |');
    expect(read(`${fa}/glossary-and-references.md`)).toContain('| One-shot |');
  });

  it('exposes both routes through the sidebar and removes stale lifecycle wording', () => {
    const sidebar = read('sidebars.ts');
    expect(sidebar).toContain("'prompt-engineering/multimodal-prompting'");
    expect(sidebar).toContain("'prompt-engineering/code-prompting'");

    for (const controls of [
      read(`../${en}/api-and-model-controls.md`),
      read(`${fa}/api-and-model-controls.md`),
    ]) {
      expect(controls).not.toContain('is scheduled to shut down on');
      expect(controls).not.toContain('shutdown برنامه‌ریزی شده است');
    }
  });
});
