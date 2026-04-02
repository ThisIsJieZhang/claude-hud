/**
 * Built-in CLI profile registry.
 *
 * This is the single place to add or modify support for a CLI tool within the codebase.
 * Each key is the CLI type identifier (used in CLAUDE_HUD_CLI env var and config.json).
 *
 * To add a new CLI tool: append an entry to this object and rebuild.
 * To adjust a built-in at runtime (without rebuilding): use the `cliProfiles` key in config.json.
 *
 * Fields:
 *   configDir       - Home-relative directory name for the CLI's config (e.g. '.claude')
 *   binaryName      - Executable name for version detection (e.g. 'claude')
 *   versionPrefix   - Short label prefix shown in the statusline (e.g. 'CC')
 *   supportsApiKey  - Show the 'API' badge when ANTHROPIC_API_KEY is set
 *   configDirEnvVar - Optional env var that overrides configDir at runtime
 *   legacyConfigJson- Whether the CLI writes an extra `<configDir>.json` file with MCP entries
 */

import type { CliProfile } from './cli-type.js';

export const BUILTIN_CLI_PROFILES: Record<string, CliProfile> = {
  claude: {
    configDir: '.claude',
    binaryName: 'claude',
    versionPrefix: 'CC',
    supportsApiKey: true,
    configDirEnvVar: 'CLAUDE_CONFIG_DIR',
    legacyConfigJson: true,
  },
  'claude-internal': {
    configDir: '.claude-internal',
    binaryName: 'claude-internal',
    versionPrefix: 'CI',
    supportsApiKey: false,
    legacyConfigJson: false,
  },
  codebuddy: {
    configDir: '.codebuddy',
    binaryName: 'codebuddy',
    versionPrefix: 'CB',
    supportsApiKey: false,
    legacyConfigJson: false,
  },
};
