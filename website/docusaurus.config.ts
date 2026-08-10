import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type {Options, ThemeConfig} from '@docusaurus/preset-classic';

const config: Config = {
  title: 'Qbit AI Toolkit',
  tagline: 'Versioned AI development tooling, installers, contracts, and reusable assets for the Qbit ecosystem.',
  favicon: 'img/favicon.ico',

  future: {
    v4: true,
  },

  url: 'https://ai-toolkit.qbit.click',
  baseUrl: '/',
  organizationName: 'qbit-click',
  projectName: 'qbit-ai-toolkit',
  deploymentBranch: 'gh-pages',
  trailingSlash: false,
  onBrokenLinks: 'throw',

  i18n: {
    defaultLocale: 'en',
    locales: ['en', 'fa'],
    localeConfigs: {
      en: {
        label: 'English',
        direction: 'ltr',
        htmlLang: 'en-US',
      },
      fa: {
        label: 'فارسی',
        direction: 'rtl',
        htmlLang: 'fa-IR',
        calendar: 'persian',
      },
    },
  },

  presets: [
    [
      'classic',
      {
        docs: {
          path: '../docs',
          routeBasePath: '/',
          sidebarPath: './sidebars.ts',
          editUrl: 'https://github.com/qbit-click/qbit-ai-toolkit/edit/main/docs/',
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Options,
    ],
  ],

  themeConfig: {
    metadata: [
      {name: 'description', content: 'Qbit AI Toolkit documentation for AI development tooling, installers, architecture, security, and maintenance.'},
    ],
    navbar: {
      title: 'Qbit AI Toolkit',
      items: [
        {to: '/', label: 'Docs', position: 'left'},
        {to: '/codex-ai-tooling', label: 'Codex AI Tooling', position: 'left'},
        {to: '/architecture', label: 'Architecture', position: 'left'},
        {type: 'localeDropdown', position: 'right'},
        {
          href: 'https://github.com/qbit-click/qbit-ai-toolkit',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Documentation',
          items: [
            {label: 'Getting started', to: '/getting-started'},
            {label: 'Codex AI Tooling', to: '/codex-ai-tooling'},
            {label: 'Security', to: '/security'},
          ],
        },
        {
          title: 'Engineering',
          items: [
            {label: 'Architecture', to: '/architecture'},
            {label: 'Asset contract', to: '/asset-contract'},
            {label: 'Versioning', to: '/versioning'},
          ],
        },
        {
          title: 'Project',
          items: [
            {label: 'GitHub', href: 'https://github.com/qbit-click/qbit-ai-toolkit'},
            {label: 'Qbit', href: 'https://qbit.click'},
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} Qbit.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ['bash', 'powershell', 'json'],
    },
  } satisfies ThemeConfig,
};

export default config;
