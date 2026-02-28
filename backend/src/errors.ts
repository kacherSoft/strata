// ---------------------------------------------------------------------------
// Structured error handling for Strata Backend
// ---------------------------------------------------------------------------

import type { ErrorResponse } from "./types.js";

export class AppError extends Error {
    constructor(
        public readonly statusCode: number,
        public readonly errorCode: string,
        message: string,
    ) {
        super(message);
        this.name = "AppError";
    }
}

/** Generate a short request ID for correlation */
export function generateRequestId(): string {
    const bytes = new Uint8Array(12);
    crypto.getRandomValues(bytes);
    return Array.from(bytes)
        .map((b) => b.toString(16).padStart(2, "0"))
        .join("");
}

/** Build a JSON error response */
export function errorResponse(
    statusCode: number,
    errorCode: string,
    message: string,
    requestId: string,
): Response {
    const body: ErrorResponse = {
        error_code: errorCode,
        message,
        request_id: requestId,
    };
    return new Response(JSON.stringify(body), {
        status: statusCode,
        headers: { "Content-Type": "application/json" },
    });
}

/** Catch AppError instances and return structured responses */
export function handleError(error: unknown, requestId: string): Response {
    if (error instanceof AppError) {
        return errorResponse(
            error.statusCode,
            error.errorCode,
            error.message,
            requestId,
        );
    }

    // Never leak internal errors
    console.error(`[${requestId}] Unhandled error:`, error);
    return errorResponse(
        500,
        "INTERNAL_ERROR",
        "An unexpected error occurred",
        requestId,
    );
}
