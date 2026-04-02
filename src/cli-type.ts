/**
 * CLI type detection and per-CLI profile resolution.
 *
 * Built-in CLI profiles live in cli-profiles.ts — that is the only file
 * that needs to change when adding or modifying a supported CLI tool.
 *
 * Users can also override or extend profiles at runtime via the `cliProfiles`
 * key in config.json without touching source code.
 *
 * Set CLAUDE_HUD_CLI env var to select the active CLI type.
 * If not set, defaults to 'claude'.
 */

import { BUILTIN_CLI_PROFILES } from './cli-profiles.js';

/** String identifier for an active CLI tool (built-in or user-defined). */
export type CliType = string;

/**
 * Per-CLI profile describing directory layout, binary name, and feature flags.
 */
export interface CliProfile {
  /** Home-relative config base directory (e.g. '.claude', '.codebuddy'). */
  configDir: string;
  /** Binary executable name used for version detection (e.g. 'claude'). */
  binaryName: string;
  /** Short prefix shown in the version label (e.g. 'CC', 'CB'). */
  versionPrefix: string;
  /**
   * Whether this CLI supports showing an API key badge.
   * When true and ANTHROPIC_API_KEY is set, the 'API' badge is shown.
   */
  supportsApiKey: boolean;
  /**
   * Environment variable name that overrides the config directory path.
   * e.g. 'CLAUDE_CONFIG_DIR' for the official Claude CLI.
   * Undefined means no env override is supported.
   */
  configDirEnvVar?: string;
  /**
   * Whether this CLI writes an additional `<configDir>.json` file alongside
   * the config directory (e.g. ~/.claude.json next to ~/.claude/).
   * When true, that file is also scanned for MCP server definitions.
   */
  legacyConfigJson: boolean;
}

/**
 * User-supplied partial profile for overriding or defining a CLI.
 * All fields are optional so users only need to specify what differs.
 * For fully custom (non-built-in) CLIs, configDir is required so the
 * HUD knows where to look.
 */
export type CliProfileOverride = Partial<CliProfile>;

/**
 * Derives a best-effort default profile for an unknown CLI key.
 * Uses the key itself as directory / binary name and uppercased initials as prefix.
 */
function deriveDefaultProfile(cliType: string): CliProfile {
  const prefix = cliType
    .split(/[-_\s]+/)
    .map((w) => w.charAt(0).toUpperCase())
    .join('')
    .slice(0, 4) || 'CLI';
  return {
    configDir: `.${cliType}`,
    binaryName: cliType,
    versionPrefix: prefix,
    supportsApiKey: false,
    legacyConfigJson: false,
  };
}

/**
 * Returns the resolved CliProfile for the given CLI type.
 *
 * Resolution order:
 *   1. Start with the built-in profile from cli-profiles.ts (if registered),
 *      or derive a default from the key name.
 *   2. Merge user-supplied override from `userProfiles` (if provided).
 */
export function getCliProfile(
  cliType: string,
  userProfiles?: Record<string, CliProfileOverride>
): CliProfile {
  const builtin = BUILTIN_CLI_PROFILES[cliType] ?? deriveDefaultProfile(cliType);
  const override = userProfiles?.[cliType];
  if (!override) {
    return builtin;
  }
  return { ...builtin, ...override };
}

/**
 * Returns the active CLI type.
 * Reads CLAUDE_HUD_CLI env var; falls back to 'claude'.
 */
export function getCliType(): CliType {
  return process.env.CLAUDE_HUD_CLI?.trim().toLowerCase() || 'claude';
}

// ---------------------------------------------------------------------------
// Backward-compatible helper wrappers (delegate to getCliProfile)
// ---------------------------------------------------------------------------

/**
 * Returns the home-relative config base directory name for the given CLI type.
 * @deprecated Prefer getCliProfile(cliType).configDir
 */
export function getCliConfigDirName(cliType: CliType): string {
  return getCliProfile(cliType).configDir;
}

/**
 * Returns the binary name for the given CLI type.
 * @deprecated Prefer getCliProfile(cliType).binaryName
 */
export function getCliBinaryName(cliType: CliType): string {
  return getCliProfile(cliType).binaryName;
}

/**
 * Returns the short version label prefix shown in the statusline.
 * @deprecated Prefer getCliProfile(cliType).versionPrefix
 */
export function getCliVersionPrefix(cliType: CliType | null | undefined): string {
  if (!cliType) return getCliProfile('claude').versionPrefix;
  return getCliProfile(cliType).versionPrefix;
}
