import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  overview: ['index', 'getting-started'],

  promptEngineering: [
    'prompt-engineering/index',
    {
      type: 'category',
      label: 'Foundations',
      collapsed: false,
      items: [
        'prompt-engineering/fundamentals',
        'prompt-engineering/writing-prompts',
      ],
    },
    {
      type: 'category',
      label: 'Techniques',
      collapsed: false,
      items: [
        'prompt-engineering/patterns',
        'prompt-engineering/reasoning-and-agents',
      ],
    },
    {
      type: 'category',
      label: 'Systems & workflows',
      collapsed: false,
      items: [
        'prompt-engineering/prompt-systems-and-orchestration',
        'prompt-engineering/clarification-and-verification-loops',
      ],
    },
    {
      type: 'category',
      label: 'Production & APIs',
      collapsed: false,
      items: [
        'prompt-engineering/api-and-model-controls',
        'prompt-engineering/context-and-grounding',
        'prompt-engineering/security',
      ],
    },
    {
      type: 'category',
      label: 'Examples & practice',
      collapsed: false,
      items: [
        'prompt-engineering/templates',
        'prompt-engineering/evaluation',
        'prompt-engineering/exercises',
        'prompt-engineering/glossary-and-references',
      ],
    },
  ],

  aiTools: [
    'ai-tools/index',
    {
      type: 'category',
      label: 'Implementation guides',
      collapsed: false,
      items: ['ai-tools/repository-owned-ai-tooling'],
    },
    {
      type: 'category',
      label: 'CodexPro',
      collapsed: false,
      items: ['ai-tools/codexpro/index', 'ai-tools/codexpro/windows-setup'],
    },
    'codex-ai-tooling',
    {
      type: 'category',
      label: 'Setup & reusable assets',
      collapsed: false,
      items: ['ai-tools/setup-scripts', 'ai-tools/reusable-assets'],
    },
    {
      type: 'category',
      label: 'Repository tooling',
      items: [
        'ai-tooling/README',
        'ai-tooling/onboarding',
        'ai-tooling/project-local-vs-installer',
        'ai-tooling/maintenance',
        'ai-tooling/troubleshooting',
        'ai-tooling/versions',
        'ai-tooling/architecture',
      ],
    },
  ],

  mcp: [
    'mcp/index',
    {
      type: 'category',
      label: 'Using MCP',
      collapsed: false,
      items: ['mcp/using-mcp', 'mcp/security'],
    },
  ],

  agentsAndSkills: [
    'agents/index',
    {
      type: 'category',
      label: 'Skills',
      collapsed: false,
      items: ['agents/building-skills', 'agents/ready-made-skills'],
    },
    {
      type: 'category',
      label: 'Agent policies',
      items: ['agents/policies'],
    },
  ],

  engineering: [
    'engineering/index',
    {
      type: 'category',
      label: 'Architecture & contracts',
      collapsed: false,
      items: ['architecture', 'asset-contract', 'conventions'],
    },
    {
      type: 'category',
      label: 'Security & versioning',
      collapsed: false,
      items: ['security', 'versioning'],
    },
  ],
};

export default sidebars;
