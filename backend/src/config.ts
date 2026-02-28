// ---------------------------------------------------------------------------
// Backend configuration helpers
// ---------------------------------------------------------------------------

import type { Env } from "./types.js";
import { AppError } from "./errors.js";

const DEFAULT_TOKEN_TTL_SECONDS = 259_200; // 72h
const MIN_TOKEN_TTL_SECONDS = 60;
const MAX_TOKEN_TTL_SECONDS = 60 * 60 * 24 * 30; // 30 days

export function parseTokenTTLSeconds(env: Env): number {
    const raw = (env.TOKEN_TTL_SECONDS || `${DEFAULT_TOKEN_TTL_SECONDS}`).trim();
    const parsed = Number.parseInt(raw, 10);

    if (!Number.isFinite(parsed) || !Number.isInteger(parsed)) {
        throw new AppError(
            500,
            "INVALID_SERVER_CONFIG",
            "Token TTL configuration is invalid",
        );
    }

    if (parsed < MIN_TOKEN_TTL_SECONDS || parsed > MAX_TOKEN_TTL_SECONDS) {
        throw new AppError(
            500,
            "INVALID_SERVER_CONFIG",
            "Token TTL configuration is out of range",
        );
    }

    return parsed;
}
