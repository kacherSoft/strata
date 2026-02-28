// ---------------------------------------------------------------------------
// POST /v1/installs/register — Register install with public key
// ---------------------------------------------------------------------------

import type { Env, InstallRegisterRequest, InstallRegisterResponse } from "../types.js";
import { AppError, handleError, generateRequestId } from "../errors.js";
import { parseInstallPublicKey } from "../install-proof.js";
import { requireUUID } from "../validation.js";

function bytesToBase64(data: Uint8Array): string {
    return btoa(String.fromCharCode(...data));
}

export async function handleInstallRegister(
    request: Request,
    env: Env,
): Promise<Response> {
    const requestId = generateRequestId();

    try {
        let body: InstallRegisterRequest;
        try {
            body = (await request.json()) as InstallRegisterRequest;
        } catch {
            throw new AppError(400, "INVALID_BODY", "Request body must be valid JSON");
        }

        // Validate install_id
        const installId = requireUUID(body.install_id, "install_id", "INVALID_INSTALL_ID");

        // Validate install_pubkey
        if (!body.install_pubkey || typeof body.install_pubkey !== "string") {
            throw new AppError(400, "INVALID_PUBKEY", "install_pubkey is required");
        }
        const pubkey = bytesToBase64(parseInstallPublicKey(body.install_pubkey.trim()));

        // Check for existing registration
        const existing = await env.STRATA_DB.prepare(
            `SELECT install_pubkey
             FROM purchase_links
             WHERE install_id = ? AND install_pubkey IS NOT NULL
             ORDER BY updated_at DESC, id DESC
             LIMIT 1`,
        )
            .bind(installId)
            .first<{ install_pubkey: string }>();

        if (existing) {
            // Already registered — check if it's the same key
            if (existing.install_pubkey === pubkey) {
                const resp: InstallRegisterResponse = { registered: true };
                return new Response(JSON.stringify(resp), {
                    status: 200,
                    headers: { "Content-Type": "application/json" },
                });
            }
            // Different key — reject (install already bound to another key)
            throw new AppError(409, "ALREADY_REGISTERED", "This install is already registered with a different key");
        }

        // Insert or attach a pubkey for this install_id.
        await env.STRATA_DB.prepare(
            `INSERT INTO purchase_links (install_id, install_pubkey, created_at, updated_at)
             VALUES (?, ?, datetime('now'), datetime('now'))
             ON CONFLICT(install_id) DO UPDATE SET
               install_pubkey = COALESCE(purchase_links.install_pubkey, excluded.install_pubkey),
               updated_at = datetime('now')`,
        )
            .bind(installId, pubkey)
            .run();

        const persisted = await env.STRATA_DB.prepare(
            `SELECT install_pubkey
             FROM purchase_links
             WHERE install_id = ?
             ORDER BY updated_at DESC, id DESC
             LIMIT 1`,
        )
            .bind(installId)
            .first<{ install_pubkey: string | null }>();

        if (!persisted?.install_pubkey || persisted.install_pubkey !== pubkey) {
            throw new AppError(409, "ALREADY_REGISTERED", "This install is already registered with a different key");
        }

        const resp: InstallRegisterResponse = { registered: true };
        return new Response(JSON.stringify(resp), {
            status: 200,
            headers: { "Content-Type": "application/json" },
        });
    } catch (error) {
        return handleError(error, requestId);
    }
}
