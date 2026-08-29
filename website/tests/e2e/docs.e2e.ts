import {expect, test} from '@playwright/test';

test('English documentation is the default LTR experience', async ({page}) => {
  await page.setViewportSize({width: 1280, height: 720});
  await page.goto('/');
  await expect(page).toHaveTitle(/Qbit AI Toolkit/);
  await expect(page.locator('html')).toHaveAttribute('lang', 'en-US');
  await expect(page.locator('html')).toHaveAttribute('dir', 'ltr');
  await expect(page.locator('.navbar__search-input')).toBeVisible();

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

test('local search returns English and Persian documentation', async ({page}) => {
  await page.goto('/search?q=Prompt%20Engineering');
  await expect(page.getByRole('link', {name: /Prompt Engineering/i}).first()).toBeVisible();

  await page.goto('/fa/search?q=مهندسی%20پرامپت');
  await expect(page.getByRole('link', {name: /مهندسی پرامپت/}).first()).toBeVisible();
});
