import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type {Options, ThemeConfig} from '@docusaurus/preset-classic';

const config: Config = {
  title: 'Qbit AI Toolkit',
  tagline: 'Versioned AI development tooling, installers, contracts, and reusable assets for the Qbit ecosystem.',
  favicon: 'img/qbit-ai-toolkit-logo.svg',

  future: {
    v4: true,
  },

  url: 'https://ai-toolkit.qbit.click',
  baseUrl: '/',
  organizationName: 'qbit-click',
  projectName: 'qbit-ai-toolkit',
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
      logo: {
        alt: 'Qbit AI Toolkit logo',
        src: 'img/qbit-ai-toolkit-logo.svg',
      },
      items: [
        {to: '/', label: 'Start', position: 'left'},
        {type: 'docSidebar', sidebarId: 'promptEngineering', label: 'Prompt Engineering', position: 'left'},
        {type: 'docSidebar', sidebarId: 'aiTools', label: 'AI Tools', position: 'left'},
        {type: 'docSidebar', sidebarId: 'mcp', label: 'MCP', position: 'left'},
        {type: 'docSidebar', sidebarId: 'agentsAndSkills', label: 'Agents & Skills', position: 'left'},
        {type: 'docSidebar', sidebarId: 'engineering', label: 'Engineering', position: 'left'},
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
            {label: 'Prompt Engineering', to: '/prompt-engineering/'},
            {label: 'AI Tools', to: '/ai-tools/'},
            {label: 'MCP', to: '/mcp/'},
            {label: 'Agents & Skills', to: '/agents/'},
          ],
        },
        {
          title: 'Engineering',
          items: [
            {label: 'Engineering reference', to: '/engineering/'},
            {label: 'Architecture', to: '/architecture'},
            {label: 'Security', to: '/security'},
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
