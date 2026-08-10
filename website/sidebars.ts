import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  docs: [
    'index',
    'getting-started',
    'codex-ai-tooling',
    {
      type: 'category',
      label: 'Architecture & contracts',
      collapsed: false,
      items: ['architecture', 'asset-contract', 'conventions', 'security', 'versioning'],
    },
    {
      type: 'category',
      label: 'Repository AI tooling',
      items: [
        'ai-tooling/README',
        'ai-tooling/architecture',
        'ai-tooling/project-local-vs-installer',
        'ai-tooling/onboarding',
        'ai-tooling/maintenance',
        'ai-tooling/troubleshooting',
        'ai-tooling/versions',
      ],
    },
  ],
};

export default sidebars;
