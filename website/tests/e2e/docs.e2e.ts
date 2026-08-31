import {expect, test} from '@playwright/test';

async function expectVazirmatnLoaded(page: import('@playwright/test').Page) {
  await page.evaluate(() => document.fonts.ready);
  const font = await page.evaluate(() => ({
    ready: document.fonts.check('16px "Vazirmatn Variable"'),
    heading: getComputedStyle(document.querySelector('h1')!).fontFamily,
  }));
  expect(font.ready).toBe(true);
  expect(font.heading).toContain('Vazirmatn Variable');
}

async function searchGeometry(page: import('@playwright/test').Page) {
  const hint = page.locator('.navbar__search [class*="searchHintContainer"]');
  await expect(hint).toBeVisible();
  return page.locator('.navbar__search').evaluate((root) => {
    const input = root.querySelector<HTMLInputElement>('.navbar__search-input')!;
    const icon = root.querySelector<SVGElement>(':scope > svg')!;
    const shortcut = root.querySelector<HTMLElement>('[class*="searchHintContainer"]')!;
    const inputRect = input.getBoundingClientRect();
    const iconRect = icon.getBoundingClientRect();
    const shortcutRect = shortcut.getBoundingClientRect();
    const style = getComputedStyle(input);
    return {
      direction: style.direction,
      textAlign: style.textAlign,
      backgroundImage: style.backgroundImage,
      inputCenter: inputRect.left + inputRect.width / 2,
      iconCenter: iconRect.left + iconRect.width / 2,
      shortcutCenter: shortcutRect.left + shortcutRect.width / 2,
      separated: iconRect.right <= shortcutRect.left || shortcutRect.right <= iconRect.left,
    };
  });
}

test('English documentation is the default LTR experience', async ({page}) => {
  await page.setViewportSize({width: 1280, height: 720});
  await page.goto('/');
  await expect(page).toHaveTitle(/Qbit AI Toolkit/);
  await expect(page.locator('html')).toHaveAttribute('lang', 'en-US');
  await expect(page.locator('html')).toHaveAttribute('dir', 'ltr');
  await expect(page.locator('.navbar__search-input')).toBeVisible();
  await expectVazirmatnLoaded(page);

  const search = await searchGeometry(page);
  expect(search.direction).toBe('ltr');
  expect(search.backgroundImage).toBe('none');
  expect(search.iconCenter).toBeLessThan(search.inputCenter);
  expect(search.shortcutCenter).toBeGreaterThan(search.inputCenter);
  expect(search.separated).toBe(true);

  const logoSpacing = await page.locator('.navbar__logo').evaluate((node) => {
    const style = getComputedStyle(node);
    return {left: style.marginLeft, right: style.marginRight};
  });
  expect(logoSpacing).toEqual({left: '0px', right: '8px'});
});

test('Persian documentation is available as RTL', async ({page}) => {
  await page.setViewportSize({width: 1280, height: 720});
  await page.goto('/fa/');
  await expect(page.locator('html')).toHaveAttribute('lang', 'fa-IR');
  await expect(page.locator('html')).toHaveAttribute('dir', 'rtl');
  await expect(page.getByText('تولکیت مهندسی AI با رویکرد documentation-first')).toBeVisible();
  await expect(page.locator('.navbar__search-input')).toBeVisible();
  await expectVazirmatnLoaded(page);

  const search = await searchGeometry(page);
  expect(search.direction).toBe('rtl');
  expect(search.textAlign).toBe('right');
  expect(search.backgroundImage).toBe('none');
  expect(search.iconCenter).toBeGreaterThan(search.inputCenter);
  expect(search.shortcutCenter).toBeLessThan(search.inputCenter);
  expect(search.separated).toBe(true);

  const logoSpacing = await page.locator('.navbar__logo').evaluate((node) => {
    const style = getComputedStyle(node);
    return {left: style.marginLeft, right: style.marginRight};
  });
  expect(logoSpacing).toEqual({left: '8px', right: '0px'});
});

test('representative documentation route remains reachable', async ({page}) => {
  await page.goto('/ai-tools/');
  await expect(page.getByRole('heading', {name: 'AI Tools', level: 1})).toBeVisible();
});

test('new prompt-engineering routes are bilingual and preserve RTL', async ({page}) => {
  await page.goto('/prompt-engineering/multimodal-prompting');
  await expect(page.getByRole('heading', {name: 'Multimodal prompting', level: 1})).toBeVisible();

  await page.goto('/fa/prompt-engineering/code-prompting');
  await expect(page.locator('html')).toHaveAttribute('dir', 'rtl');
  await expect(page.getByRole('heading', {name: 'پرامپت‌نویسی برای کد', level: 1})).toBeVisible();
});

test('local search returns English and Persian documentation', async ({page}) => {
  await page.goto('/search?q=Prompt%20Engineering');
  await expect(page.getByRole('link', {name: /Prompt Engineering/i}).first()).toBeVisible();

  await page.goto('/fa/search?q=مهندسی%20پرامپت');
  await expect(page.getByRole('link', {name: /مهندسی پرامپت/}).first()).toBeVisible();

  await page.goto('/search?q=Multimodal%20prompting');
  await expect(page.getByRole('link', {name: /Multimodal prompting/i}).first()).toBeVisible();

  await page.goto('/fa/search?q=Image');
  await expect(page.locator('a[href*="/fa/prompt-engineering/multimodal-prompting"]').first()).toBeVisible();
});
