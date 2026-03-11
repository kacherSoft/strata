// ---------------------------------------------------------------------------
// Shared request validation helpers
// ---------------------------------------------------------------------------

import { AppError } from "./errors.js";

export const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function requireUUID(
    value: unknown,
    fieldName: string,
    errorCode: string,
): string {
    if (typeof value !== "string") {
        throw new AppError(400, errorCode, `${fieldName} is required`);
    }

    const normalized = value.trim().toLowerCase();
    if (!UUID_RE.test(normalized)) {
        throw new AppError(400, errorCode, `${fieldName} must be a valid UUID`);
    }
    return normalized;
}

export function requireEmail(value: unknown): string {
    if (typeof value !== "string") {
        throw new AppError(400, "INVALID_EMAIL", "email is required");
    }

    const normalized = value.trim().toLowerCase();
    if (normalized.length > 254) {
        throw new AppError(400, "INVALID_EMAIL", "email exceeds maximum length");
    }
    if (!EMAIL_RE.test(normalized)) {
        throw new AppError(400, "INVALID_EMAIL", "email format is invalid");
    }
    return normalized;
}

export function sanitizeNickname(value: unknown): string | null {
    if (value === null || value === undefined) return null;
    if (typeof value !== "string") return null;
    const trimmed = value.trim().slice(0, 100); // Max 100 chars
    if (trimmed.length === 0) return null;
    // Strip control characters (C0, DEL)
    return trimmed.replace(/[\x00-\x1F\x7F]/g, "");
}

export function requireNonEmptyString(
    value: unknown,
    errorCode: string,
    message: string,
): string {
    if (typeof value !== "string") {
        throw new AppError(400, errorCode, message);
    }

    const normalized = value.trim();
    if (!normalized) {
        throw new AppError(400, errorCode, message);
    }
    return normalized;
}
