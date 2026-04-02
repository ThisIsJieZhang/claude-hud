import { type CliType, type CliProfileOverride } from './cli-type.js';
/**
 * Returns the config base directory for the Claude CLI specifically.
 * Respects CLAUDE_CONFIG_DIR env var for backward compatibility.
 *
 * @deprecated Prefer getCliConfigDir(homeDir, 'claude') which handles
 * the env var via the profile's configDirEnvVar field.
 */
export declare function getClaudeConfigDir(homeDir: string): string;
/**
 * Returns the path to the legacy ~/.claude.json file used by the Claude CLI.
 */
export declare function getClaudeConfigJsonPath(homeDir: string): string;
/**
 * Returns the HUD plugin dir for the Claude CLI specifically.
 * @deprecated Prefer getCliHudPluginDir(homeDir)
 */
export declare function getHudPluginDir(homeDir: string): string;
/**
 * Returns the config base directory for the given CLI type.
 *
 * Resolution:
 *   1. Look up the CLI profile (built-in → user override → derived default).
 *   2. If the profile declares a configDirEnvVar, honour that env var.
 *   3. Otherwise join homeDir with profile.configDir.
 */
export declare function getCliConfigDir(homeDir: string, cliType?: CliType, userProfiles?: Record<string, CliProfileOverride>): string;
/**
 * Returns the HUD plugin data directory for the given CLI type.
 * Stored inside the CLI's config directory so each CLI has its own cache/config.
 */
export declare function getCliHudPluginDir(homeDir: string, cliType?: CliType, userProfiles?: Record<string, CliProfileOverride>): string;
//# sourceMappingURL=claude-config-dir.d.ts.map