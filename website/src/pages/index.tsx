import type {ReactNode} from 'react';
import Link from '@docusaurus/Link';
import Layout from '@theme/Layout';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import styles from './index.module.css';

type Domain = {
  code: string;
  title: string;
  description: string;
  path: string;
};

type Copy = {
  badge: string;
  title: string;
  subtitle: string;
  primaryCta: string;
  githubCta: string;
  scopeEyebrow: string;
  scopeTitle: string;
  scopeDescription: string;
  domains: Domain[];
  currentEyebrow: string;
  currentTitle: string;
  currentDescription: string;
  currentLink: string;
  principlesEyebrow: string;
  principlesTitle: string;
  principles: Array<{title: string; description: string}>;
  closingTitle: string;
  closingDescription: string;
  closingCta: string;
};

const copy: Record<'en' | 'fa', Copy> = {
  en: {
    badge: 'Documentation-first AI engineering toolkit',
    title: 'Build AI-assisted development workflows that are explicit, reusable, and maintainable.',
    subtitle:
      'Qbit AI Toolkit is the versioned home for prompt-engineering guidance, AI development tooling, MCP usage, reusable agent skills, policies, templates, and the engineering contracts that connect them.',
    primaryCta: 'Start with the documentation',
    githubCta: 'View on GitHub',
    scopeEyebrow: 'One toolkit, clear boundaries',
    scopeTitle: 'Learn the method, use the tools, understand the contracts.',
    scopeDescription:
      'Each documentation domain has its own navigation so operational tooling, prompt design, MCP integrations, agent behavior, and engineering reference do not collapse into one mixed hierarchy.',
    domains: [
      {
        code: 'PE',
        title: 'Prompt Engineering',
        description: 'Learn how to write explicit prompts, use reusable patterns, and evaluate behavior instead of relying on ad-hoc wording.',
        path: '/prompt-engineering/',
      },
      {
        code: 'AI',
        title: 'AI Tools',
        description: 'Setup scripts, reusable assets, Codex AI Tooling, repository-local helpers, verification, maintenance, and troubleshooting.',
        path: '/ai-tools/',
      },
      {
        code: 'MCP',
        title: 'MCP',
        description: 'Configure and use Model Context Protocol integrations with explicit capability, permission, transport, and security boundaries.',
        path: '/mcp/',
      },
      {
        code: 'AS',
        title: 'Agents & Skills',
        description: 'Design reusable skills, publish ready-made workflows, and separate agent policies from task-specific execution logic.',
        path: '/agents/',
      },
      {
        code: 'ENG',
        title: 'Engineering Reference',
        description: 'Architecture, asset contracts, conventions, security boundaries, versioning, and compatibility rules for maintainers.',
        path: '/engineering/',
      },
    ],
    currentEyebrow: 'Current operational asset',
    currentTitle: 'Codex AI Tooling',
    currentDescription:
      'The first implemented catalog asset installs repository-owned AI development tooling through a versioned, cross-platform installer lifecycle with explicit ownership, verification, doctor, recovery, and uninstall behavior.',
    currentLink: 'Explore Codex AI Tooling',
    principlesEyebrow: 'Project principles',
    principlesTitle: 'Designed for production-grade engineering workflows.',
    principles: [
      {
        title: 'Documentation before drift',
        description: 'Architecture and behavior are documented as contracts instead of being reconstructed after implementation changes.',
      },
      {
        title: 'Reusable without hidden coupling',
        description: 'Prompts, skills, templates, installers, and policies have explicit ownership and consumer boundaries.',
      },
      {
        title: 'Validation is part of the asset',
        description: 'Operational tooling is expected to expose verification, failure behavior, and evidence—not just create files.',
      },
    ],
    closingTitle: 'Start from the area that matches the problem you are solving.',
    closingDescription:
      'Use the top navigation to move between learning material, operational tooling, integrations, reusable agent behavior, and engineering reference.',
    closingCta: 'Open the overview',
  },
  fa: {
    badge: 'تولکیت مهندسی AI با رویکرد documentation-first',
    title: 'Workflowهای توسعه مبتنی بر AI را صریح، قابل استفاده مجدد و قابل نگه‌داری بسازید.',
    subtitle:
      'Qbit AI Toolkit مرجع نسخه‌دار برای آموزش مهندسی پرامپت، ابزارهای توسعه AI، استفاده از MCP، skill و policyهای reusable ایجنت، templateها و قراردادهای مهندسی میان آن‌ها است.',
    primaryCta: 'شروع مطالعه مستندات',
    githubCta: 'مشاهده در GitHub',
    scopeEyebrow: 'یک تولکیت، مرزهای روشن',
    scopeTitle: 'روش را یاد بگیرید، ابزار را استفاده کنید و قراردادها را بشناسید.',
    scopeDescription:
      'هر domain مستندات navigation مستقل دارد تا ابزارهای عملیاتی، طراحی prompt، integrationهای MCP، رفتار agent و مرجع مهندسی در یک hierarchy مخلوط نشوند.',
    domains: [
      {
        code: 'PE',
        title: 'مهندسی پرامپت',
        description: 'نوشتن prompt صریح، استفاده از patternهای reusable و ارزیابی behavior به‌جای تکیه بر wording اتفاقی.',
        path: '/prompt-engineering/',
      },
      {
        code: 'AI',
        title: 'ابزارهای AI',
        description: 'اسکریپت‌های راه‌اندازی، assetهای reusable، Codex AI Tooling، helperهای repository، verification و troubleshooting.',
        path: '/ai-tools/',
      },
      {
        code: 'MCP',
        title: 'MCP',
        description: 'پیکربندی و استفاده از Model Context Protocol با boundary روشن برای capability، permission، transport و security.',
        path: '/mcp/',
      },
      {
        code: 'AS',
        title: 'ایجنت‌ها و اسکیل‌ها',
        description: 'طراحی skill reusable، انتشار workflowهای آماده و جدا نگه داشتن policyهای agent از منطق اجرای task.',
        path: '/agents/',
      },
      {
        code: 'ENG',
        title: 'مرجع مهندسی',
        description: 'معماری، قرارداد asset، conventionها، boundaryهای امنیتی، versioning و قواعد compatibility برای maintainerها.',
        path: '/engineering/',
      },
    ],
    currentEyebrow: 'دارایی عملیاتی فعلی',
    currentTitle: 'Codex AI Tooling',
    currentDescription:
      'اولین asset پیاده‌سازی‌شده catalog، tooling توسعه AI متعلق به repository را با lifecycle نسخه‌دار و cross-platform نصب می‌کند و ownership، verification، doctor، recovery و uninstall را صریح نگه می‌دارد.',
    currentLink: 'مشاهده Codex AI Tooling',
    principlesEyebrow: 'اصول پروژه',
    principlesTitle: 'برای workflowهای مهندسی production-grade طراحی شده است.',
    principles: [
      {
        title: 'مستندات قبل از drift',
        description: 'معماری و رفتار به‌صورت contract مستند می‌شوند، نه اینکه بعد از implementation دوباره از روی کد حدس زده شوند.',
      },
      {
        title: 'Reuse بدون coupling پنهان',
        description: 'Prompt، skill، template، installer و policy باید ownership و boundary مصرف روشن داشته باشند.',
      },
      {
        title: 'Validation جزئی از asset است',
        description: 'Tooling عملیاتی باید verification، failure behavior و evidence ارائه دهد؛ صرفاً ساختن چند فایل کافی نیست.',
      },
    ],
    closingTitle: 'از بخشی شروع کنید که با مسئله فعلی شما تطابق دارد.',
    closingDescription:
      'از navigation اصلی میان آموزش، ابزارهای عملیاتی، integrationها، رفتار reusable agent و مرجع مهندسی جابه‌جا شوید.',
    closingCta: 'باز کردن معرفی مستندات',
  },
};

function Arrow(): ReactNode {
  return <span aria-hidden="true">→</span>;
}

export default function Home(): ReactNode {
  const {i18n} = useDocusaurusContext();
  const locale = i18n.currentLocale === 'fa' ? 'fa' : 'en';
  const text = copy[locale];
  const localized = (path: string) => (locale === 'fa' ? `/fa${path}` : path);

  return (
    <Layout
      title="Qbit AI Toolkit"
      description="Qbit AI Toolkit documentation for prompt engineering, AI tooling, MCP, agents, skills, architecture, and reusable engineering assets.">
      <main className={styles.page}>
        <section className={styles.hero}>
          <div className={styles.heroGlow} aria-hidden="true" />
          <div className={styles.shell}>
            <div className={styles.heroGrid}>
              <div className={styles.heroCopy}>
                <img
                  className={styles.heroLogo}
                  src="/img/qbit-ai-toolkit-logo.svg"
                  alt="Qbit AI Toolkit"
                  width="112"
                  height="112"
                />
                <div className={styles.badge}>{text.badge}</div>
                <h1>{text.title}</h1>
                <p>{text.subtitle}</p>
                <div className={styles.actions}>
                  <Link className="button button--primary button--lg" to={localized('/getting-started')}>
                    {text.primaryCta}
                  </Link>
                  <Link
                    className="button button--secondary button--lg"
                    href="https://github.com/qbit-click/qbit-ai-toolkit">
                    {text.githubCta}
                  </Link>
                </div>
              </div>

              <aside className={styles.heroPanel} aria-label={text.currentTitle}>
                <div className={styles.terminalHeader}>
                  <span />
                  <span />
                  <span />
                  <strong>qbit-ai-toolkit</strong>
                </div>
                <div className={styles.terminalBody}>
                  <div><span>$</span> toolkit domains</div>
                  <div className={styles.terminalOutput}>prompt-engineering</div>
                  <div className={styles.terminalOutput}>ai-tools</div>
                  <div className={styles.terminalOutput}>mcp</div>
                  <div className={styles.terminalOutput}>agents-and-skills</div>
                  <div className={styles.terminalOutput}>engineering-reference</div>
                  <div className={styles.terminalStatus}>✓ docs: en / fa</div>
                </div>
              </aside>
            </div>
          </div>
        </section>

        <section className={styles.section}>
          <div className={styles.shell}>
            <div className={styles.sectionHeading}>
              <span>{text.scopeEyebrow}</span>
              <h2>{text.scopeTitle}</h2>
              <p>{text.scopeDescription}</p>
            </div>

            <div className={styles.domainGrid}>
              {text.domains.map((domain) => (
                <Link key={domain.path} className={styles.domainCard} to={localized(domain.path)}>
                  <div className={styles.domainCode}>{domain.code}</div>
                  <h3>{domain.title}</h3>
                  <p>{domain.description}</p>
                  <div className={styles.cardLink}>
                    <span>{locale === 'fa' ? 'مشاهده بخش' : 'Explore section'}</span>
                    <Arrow />
                  </div>
                </Link>
              ))}
            </div>
          </div>
        </section>

        <section className={styles.assetSection}>
          <div className={styles.shell}>
            <div className={styles.assetCard}>
              <div>
                <span className={styles.eyebrow}>{text.currentEyebrow}</span>
                <h2>{text.currentTitle}</h2>
                <p>{text.currentDescription}</p>
              </div>
              <Link className={styles.assetLink} to={localized('/codex-ai-tooling')}>
                {text.currentLink} <Arrow />
              </Link>
            </div>
          </div>
        </section>

        <section className={styles.section}>
          <div className={styles.shell}>
            <div className={styles.sectionHeading}>
              <span>{text.principlesEyebrow}</span>
              <h2>{text.principlesTitle}</h2>
            </div>
            <div className={styles.principleGrid}>
              {text.principles.map((principle, index) => (
                <article key={principle.title} className={styles.principleCard}>
                  <div className={styles.principleNumber}>0{index + 1}</div>
                  <h3>{principle.title}</h3>
                  <p>{principle.description}</p>
                </article>
              ))}
            </div>
          </div>
        </section>

        <section className={styles.closing}>
          <div className={styles.shell}>
            <div className={styles.closingInner}>
              <div>
                <h2>{text.closingTitle}</h2>
                <p>{text.closingDescription}</p>
              </div>
              <Link className="button button--primary button--lg" to={localized('/overview')}>
                {text.closingCta}
              </Link>
            </div>
          </div>
        </section>
      </main>
    </Layout>
  );
}
