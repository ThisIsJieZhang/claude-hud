import * as path from 'node:path';
import { type CliType, type CliProfileOverride, getCliType, getCliProfile } from './cli-type.js';

function expandHomeDirPrefix(inputPath: string, homeDir: string): string {
  if (inputPath === '~') {
    return homeDir;
  }
  if (inputPath.startsWith('~/') || inputPath.startsWith('~\\')) {
    return path.join(homeDir, inputPath.slice(2));
  }
  return inputPath;
}

/**
 * Returns the config base directory for the Claude CLI specifically.
 * Respects CLAUDE_CONFIG_DIR env var for backward compatibility.
 *
 * @deprecated Prefer getCliConfigDir(homeDir, 'claude') which handles
 * the env var via the profile's configDirEnvVar field.
 */
export function getClaudeConfigDir(homeDir: string): string {
  const envConfigDir = process.env.CLAUDE_CONFIG_DIR?.trim();
  if (!envConfigDir) {
    return path.join(homeDir, '.claude');
  }
  return path.resolve(expandHomeDirPrefix(envConfigDir, homeDir));
}

/**
 * Returns the path to the legacy ~/.claude.json file used by the Claude CLI.
 */
export function getClaudeConfigJsonPath(homeDir: string): string {
  return `${getClaudeConfigDir(homeDir)}.json`;
}

/**
 * Returns the HUD plugin dir for the Claude CLI specifically.
 * @deprecated Prefer getCliHudPluginDir(homeDir)
 */
export function getHudPluginDir(homeDir: string): string {
  return path.join(getClaudeConfigDir(homeDir), 'plugins', 'claude-hud');
}

/**
 * Returns the config base directory for the given CLI type.
 *
 * Resolution:
 *   1. Look up the CLI profile (built-in → user override → derived default).
 *   2. If the profile declares a configDirEnvVar, honour that env var.
 *   3. Otherwise join homeDir with profile.configDir.
 */
export function getCliConfigDir(
  homeDir: string,
  cliType?: CliType,
  userProfiles?: Record<string, CliProfileOverride>
): string {
  const resolvedType = cliType ?? getCliType();
  const profile = getCliProfile(resolvedType, userProfiles);

  if (profile.configDirEnvVar) {
    const envConfigDir = process.env[profile.configDirEnvVar]?.trim();
    if (envConfigDir) {
      return path.resolve(expandHomeDirPrefix(envConfigDir, homeDir));
    }
  }

  return path.join(homeDir, profile.configDir);
}

/**
 * Returns the HUD plugin data directory for the given CLI type.
 * Stored inside the CLI's config directory so each CLI has its own cache/config.
 */
export function getCliHudPluginDir(
  homeDir: string,
  cliType?: CliType,
  userProfiles?: Record<string, CliProfileOverride>
): string {
  return path.join(getCliConfigDir(homeDir, cliType, userProfiles), 'plugins', 'claude-hud');
}
