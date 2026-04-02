import { type CliProfileOverride } from './cli-type.js';
export interface ConfigCounts {
    claudeMdCount: number;
    rulesCount: number;
    mcpCount: number;
    hooksCount: number;
}
export declare function countConfigs(cwd?: string, userProfiles?: Record<string, CliProfileOverride>): Promise<ConfigCounts>;
//# sourceMappingURL=config-reader.d.ts.map