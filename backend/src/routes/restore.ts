// ---------------------------------------------------------------------------
// POST /v1/purchases/restore — Unified restore flow
// ---------------------------------------------------------------------------

import type { Env, RestoreRequest, RestoreResponse } from "../types.js";
import { AppError, handleError, generateRequestId } from "../errors.js";
import { DodoClient } from "../dodo-client.js";
import { PRODUCT_IDS } from "../types.js";
import { signToken } from "../signing.js";
import { parseTokenTTLSeconds } from "../config.js";
import { verifyInstallProof } from "../install-proof.js";
import { requireEmail, requireNonEmptyString, requireUUID } from "../validation.js";
import { requireAuthSession } from "../auth.js";
import { checkAnomalies } from "../anomaly-detection.js";
import {
    ensureDeviceSeat,
    resolveTierForUser,
    upsertUserEntitlement,
} from "../user-entitlements.js";
import { checkRateLimit } from "../rate-limit.js";

function asRecord(value: unknown): Record<string, unknown> | null {
    if (!value || typeof value !== "object" || Array.isArray(value)) return null;
    return value as Record<string, unknown>;
}

function readString(value: unknown): string | null {
    if (typeof value !== "string") return null;
    const trimmed = value.trim();
    return trimmed || null;
}

function parseLicenseActivationProductId(response: Record<string, unknown>): string | null {
    const direct = readString(response.product_id);
    if (direct) return direct;

    const product = asRecord(response.product);
    const fromProduct = readString(product?.product_id);
    if (fromProduct) return fromProduct;

    const license = asRecord(response.license_key);
    const fromLicense = readString(license?.product_id);
    if (fromLicense) return fromLicense;

    const data = asRecord(response.data);
    const fromData = readString(data?.product_id);
    if (fromData) return fromData;

    const dataLicense = asRecord(data?.license_key);
    const fromDataLicense = readString(dataLicense?.product_id);
    if (fromDataLicense) return fromDataLicense;

    return null;
}

function parseLicenseActivationStatus(response: Record<string, unknown>): string | null {
    const direct = readString(response.status);
    if (direct) return direct.toLowerCase();

    const license = asRecord(response.license_key);
    const nested = readString(license?.status);
    if (nested) return nested.toLowerCase();

    const data = asRecord(response.data);
    const dataStatus = readString(data?.status);
    if (dataStatus) return dataStatus.toLowerCase();

    return null;
}

const SUCCESSFUL_CHECKOUT_PAYMENT_STATUSES: ReadonlySet<string> = new Set<string>([
    "succeeded",
    "paid",
    "completed",
    "active",
]);

interface InstallLinkRow {
    customer_email: string | null;
    checkout_session_id: string | null;
    customer_id: string | null;
}

function normalizeEmailCandidate(value: string | null | undefined): string | null {
    if (!value) return null;
    try {
        return requireEmail(value);
    } catch {
        return null;
    }
}

async function persistLinkedCustomer(
    env: Env,
    installId: string,
    email: string | null,
    customerId: string | null,
): Promise<void> {
    await env.STRATA_DB.prepare(
        `UPDATE purchase_links
         SET customer_email = COALESCE(?, customer_email),
             customer_id = COALESCE(?, customer_id),
             updated_at = datetime('now')
         WHERE install_id = ?`,
    )
        .bind(email, customerId, installId)
        .run();
}

async function loadInstallLinkRow(
    env: Env,
    installId: string,
): Promise<InstallLinkRow | null> {
    return await env.STRATA_DB.prepare(
        `SELECT customer_email, checkout_session_id, customer_id
         FROM purchase_links
         WHERE install_id = ?
         ORDER BY updated_at DESC, id DESC
         LIMIT 1`,
    )
        .bind(installId)
        .first<InstallLinkRow>();
}

async function inferEmailForInstall(
    env: Env,
    installId: string,
    installLink: InstallLinkRow | null,
    dodo: DodoClient,
    requestId: string,
): Promise<string | null> {
    if (!installLink) {
        return null;
    }

    const linkedEmail = normalizeEmailCandidate(installLink.customer_email);
    if (linkedEmail) {
        return linkedEmail;
    }

    const checkoutSessionId = readString(installLink.checkout_session_id);
    if (!checkoutSessionId) {
        return null;
    }

    let checkout = null;
    try {
        checkout = await dodo.getCheckoutSession(checkoutSessionId);
    } catch (error) {
        console.error(
            `[${requestId}] checkout session lookup failed checkout_session_id=${checkoutSessionId}:`,
            error,
        );
        return null;
    }

    if (!checkout) {
        return null;
    }

    const paymentStatus = checkout.paymentStatus || "";
    if (!SUCCESSFUL_CHECKOUT_PAYMENT_STATUSES.has(paymentStatus)) {
        return null;
    }

    const checkoutEmail = normalizeEmailCandidate(checkout.customerEmail);
    const checkoutCustomerId = readString(checkout.customerId);

    if (checkoutEmail) {
        await persistLinkedCustomer(env, installId, checkoutEmail, checkoutCustomerId).catch(() => { });
        return checkoutEmail;
    }

    if (checkoutCustomerId) {
        try {
            const customerEmail = normalizeEmailCandidate(
                await dodo.findCustomerEmailById(checkoutCustomerId),
            );
            if (customerEmail) {
                await persistLinkedCustomer(env, installId, customerEmail, checkoutCustomerId).catch(
                    () => { },
                );
                return customerEmail;
            }
        } catch (error) {
            console.error(
                `[${requestId}] checkout customer lookup failed customer_id=${checkoutCustomerId}:`,
                error,
            );
        }
    }

    return null;
}

async function tryRestoreVipFromLinkedCheckout(
    env: Env,
    installId: string,
    email: string,
    installLink: InstallLinkRow | null,
    dodo: DodoClient,
    requestId: string,
): Promise<boolean> {
    const checkoutSessionId = readString(installLink?.checkout_session_id);
    if (!checkoutSessionId) return false;

    let checkout = null;
    try {
        checkout = await dodo.getCheckoutSession(checkoutSessionId);
    } catch (error) {
        console.error(
            `[${requestId}] restore checkout lookup failed checkout_session_id=${checkoutSessionId}:`,
            error,
        );
        return false;
    }

    if (!checkout?.paymentStatus || !SUCCESSFUL_CHECKOUT_PAYMENT_STATUSES.has(checkout.paymentStatus)) {
        return false;
    }

    const paymentId = readString(checkout.paymentId);
    if (!paymentId) {
        return false;
    }

    let payment = null;
    try {
        payment = await dodo.getPayment(paymentId);
    } catch (error) {
        console.error(
            `[${requestId}] restore payment lookup failed payment_id=${paymentId}:`,
            error,
        );
        return false;
    }

    if (!payment?.status || !SUCCESSFUL_CHECKOUT_PAYMENT_STATUSES.has(payment.status)) {
        return false;
    }

    if (!payment.productIds.includes(PRODUCT_IDS.vipLifetime)) {
        return false;
    }

    const paymentCustomerEmail = normalizeEmailCandidate(payment.customerEmail);
    if (paymentCustomerEmail && paymentCustomerEmail !== email) {
        console.warn(
            `[${requestId}] restore payment customer mismatch email=${email} payment_email=${paymentCustomerEmail}`,
        );
        return false;
    }

    const linkedCustomerId = readString(installLink?.customer_id);
    const paymentCustomerId = readString(payment.customerId);
    if (linkedCustomerId && paymentCustomerId && linkedCustomerId !== paymentCustomerId) {
        console.warn(
            `[${requestId}] restore payment customer mismatch customer_id=${linkedCustomerId} payment_customer_id=${paymentCustomerId}`,
        );
        return false;
    }

    await persistLinkedCustomer(
        env,
        installId,
        paymentCustomerEmail ?? email,
        paymentCustomerId,
    ).catch(() => { });

    await env.STRATA_DB.prepare(
        `INSERT INTO entitlements (subject_type, subject_id, tier, state, source_event_id, effective_from, updated_at)
         VALUES ('email', ?, 'vip', 'active', ?, datetime('now'), datetime('now'))
         ON CONFLICT(subject_type, subject_id) DO UPDATE SET
           tier = 'vip',
           state = 'active',
           source_event_id = excluded.source_event_id,
           effective_from = COALESCE(excluded.effective_from, entitlements.effective_from),
           updated_at = datetime('now')`,
    )
        .bind(email, `restore-payment-${requestId}`)
        .run();

    return true;
}

export async function handleRestore(
    request: Request,
    env: Env,
    ctx: ExecutionContext,
): Promise<Response> {
    const requestId = generateRequestId();

    try {
        // Rate limit by IP — max 20 restore requests per minute
        const clientIp = request.headers.get("CF-Connecting-IP") || "unknown";
        if (!(await checkRateLimit(env, `restore:ip:${clientIp}`, 20, 60))) {
            throw new AppError(429, "RATE_LIMITED", "Too many restore requests");
        }

        let body: RestoreRequest;
        try {
            body = (await request.json()) as RestoreRequest;
        } catch {
            throw new AppError(400, "INVALID_BODY", "Request body must be valid JSON");
        }

        const installId = requireUUID(body.install_id, "install_id", "INVALID_INSTALL_ID");

        // Rate limit by install_id — max 5 restore requests per minute
        if (!(await checkRateLimit(env, `restore:install:${installId}`, 5, 60))) {
            throw new AppError(429, "RATE_LIMITED", "Too many restore requests from this device");
        }
        const challengeId = requireNonEmptyString(
            body.challenge_id,
            "INVALID_CHALLENGE",
            "challenge_id is required",
        );
        const nonceSignature = requireNonEmptyString(
            body.nonce_signature,
            "INVALID_INSTALL_PROOF",
            "nonce_signature is required",
        );

        const proof = await verifyInstallProof(env, installId, challengeId, nonceSignature);

        const principal = await requireAuthSession(request, env);

        const dodo = new DodoClient(env);
        const installLink = await loadInstallLinkRow(env, installId);

        if (typeof body.email === "string" && body.email.trim()) {
            const requestedEmail = requireEmail(body.email);
            if (requestedEmail !== principal.email) {
                throw new AppError(
                    403,
                    "ACCOUNT_MISMATCH",
                    "Restore email must match the signed-in account",
                );
            }
        }
        const email: string = principal.email;

        const ttl = parseTokenTTLSeconds(env);
        let restoreType: RestoreResponse["restore_type"] = "none";
        let tier: "free" | "pro" | "vip" = "free";

        const resolved = await resolveTierForUser(env, {
            userId: principal.userId,
            email: principal.email,
            dodo,
            allowProviderFallback: true,
        });
        tier = resolved.tier;
        if (tier === "vip") {
            restoreType = "lifetime";
        } else if (tier === "pro") {
            restoreType = "subscription";
        }

        // Step 3: VIP fallback for one-time checkout when webhook/license projection is delayed
        if (tier !== "vip") {
            const restoredFromVipPayment = await tryRestoreVipFromLinkedCheckout(
                env,
                installId,
                email,
                installLink,
                dodo,
                requestId,
            );
            if (restoredFromVipPayment) {
                tier = "vip";
                restoreType = "lifetime";
                await upsertUserEntitlement(env, {
                    userId: principal.userId,
                    tier: "vip",
                    state: "active",
                    sourceEventId: `restore-payment-${requestId}`,
                });
            }
        }

        // Step 4: If a license key was provided and we still haven't found VIP, try activating it
        const trimmedLicenseKey = body.license_key?.trim();
        if (tier !== "vip" && trimmedLicenseKey) {
            try {
                const licenseUrl = `${env.DODO_BASE_URL}/licenses/activate`;
                const licenseResponse = await fetch(licenseUrl, {
                    method: "POST",
                    headers: {
                        Authorization: `Bearer ${env.DODO_API_KEY}`,
                        "Content-Type": "application/json",
                    },
                    body: JSON.stringify({
                        license_key: trimmedLicenseKey,
                        name: `restore-${installId}`,
                    }),
                });

                if (licenseResponse.ok) {
                    const activationBody = (await licenseResponse.json()) as Record<string, unknown>;
                    const productId = parseLicenseActivationProductId(activationBody);
                    const status = parseLicenseActivationStatus(activationBody);

                    if (!productId) {
                        console.warn(
                            `[${requestId}] restore license activation succeeded but product_id missing`,
                        );
                    } else if (productId !== PRODUCT_IDS.vipLifetime) {
                        console.warn(
                            `[${requestId}] restore license activation product mismatch product_id=${productId}`,
                        );
                    } else if (status && status !== "active") {
                        console.warn(
                            `[${requestId}] restore license activation status is not active status=${status}`,
                        );
                    } else {
                        tier = "vip";
                        restoreType = "lifetime";

                        // Store in entitlement table
                        await env.STRATA_DB.prepare(
                            `INSERT OR REPLACE INTO entitlements (subject_type, subject_id, tier, state, source_event_id, effective_from, updated_at)
                             VALUES ('email', ?, 'vip', 'active', ?, datetime('now'), datetime('now'))`,
                        )
                            .bind(email, `restore-${requestId}`)
                            .run();

                        await upsertUserEntitlement(env, {
                            userId: principal.userId,
                            tier: "vip",
                            state: "active",
                            sourceEventId: `restore-${requestId}`,
                        });
                    }
                } else {
                    const providerBody = await licenseResponse.text().catch(() => "");
                    console.warn(
                        `[${requestId}] restore license activation rejected status=${licenseResponse.status} body=${providerBody}`,
                    );
                }
            } catch (error) {
                console.error(
                    `[${requestId}] restore license activation failed for ${email}:`,
                    error,
                );
                // Continue with free tier when activation fails.
            }
        }

        if (tier !== "free") {
            await ensureDeviceSeat(env, {
                userId: principal.userId,
                installId,
                tier,
            });
        }

        // Sign token with determined tier
        const token = await signToken({
            tier,
            sub: email,
            uid: principal.userId,
            installId,
            ttlSeconds: ttl,
            privateKeyHex: env.ENTITLEMENT_SIGNING_PRIVATE_KEY,
            installPubkeyHash: proof.installPubkeyHash,
            kid: env.ENTITLEMENT_SIGNING_KEY_ID || "default",
        });

        // Link this install to the email if we found something
        if (tier !== "free") {
            await env.STRATA_DB.prepare(
                `INSERT INTO purchase_links (install_id, customer_email, created_at, updated_at)
                 VALUES (?, ?, datetime('now'), datetime('now'))
                 ON CONFLICT(install_id) DO UPDATE SET
                   customer_email = COALESCE(excluded.customer_email, purchase_links.customer_email),
                   updated_at = datetime('now')`,
            )
                .bind(installId, email)
                .run()
                .catch(() => { }); // Best-effort

            await upsertUserEntitlement(env, {
                userId: principal.userId,
                tier,
                state: "active",
                sourceEventId: `restore-${requestId}`,
            }).catch(() => {
                // Best effort; restore token is still issued.
            });

            ctx.waitUntil(checkAnomalies(env, { userId: principal.userId, installId, action: "restore" }));
        }

        const response: RestoreResponse = {
            token,
            restore_type: restoreType,
            resolved_email: email,
        };
        return new Response(JSON.stringify(response), {
            status: 200,
            headers: { "Content-Type": "application/json" },
        });
    } catch (error) {
        return handleError(error, requestId);
    }
}
