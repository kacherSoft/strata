// ---------------------------------------------------------------------------
// POST /v1/checkout-sessions — Create a pre-linked checkout session
// ---------------------------------------------------------------------------

import type { Env, CheckoutSessionRequest, CheckoutSessionResponse } from "../types.js";
import { AppError, handleError, generateRequestId } from "../errors.js";
import { PRODUCT_IDS } from "../types.js";
import { requireEmail, requireUUID } from "../validation.js";
import { authRequiredForCheckout, optionalAuthSession, requireAuthSession } from "../auth.js";

const ALLOWED_PRODUCT_IDS: ReadonlySet<string> = new Set<string>(
    Object.values(PRODUCT_IDS),
);

function readTrimmedString(value: unknown): string | null {
    if (typeof value !== "string") return null;
    const trimmed = value.trim();
    return trimmed || null;
}

function buildReturnURL(returnURL: string | undefined, installId: string): string {
    const configured = (returnURL || "strata://checkout-complete").trim();
    let parsed: URL;
    try {
        parsed = new URL(configured);
    } catch {
        throw new AppError(400, "INVALID_RETURN_URL", "return_url must be a valid URL");
    }

    const scheme = parsed.protocol.replace(":", "").toLowerCase();
    const host = parsed.hostname.trim().toLowerCase();
    if (scheme !== "strata" || host !== "checkout-complete") {
        throw new AppError(
            400,
            "INVALID_RETURN_URL",
            "return_url must use strata://checkout-complete",
        );
    }

    parsed.searchParams.set("install_id", installId);
    return parsed.toString();
}

export async function handleCheckoutSession(
    request: Request,
    env: Env,
): Promise<Response> {
    const requestId = generateRequestId();

    try {
        let body: CheckoutSessionRequest;
        try {
            body = (await request.json()) as CheckoutSessionRequest;
        } catch {
            throw new AppError(400, "INVALID_BODY", "Request body must be valid JSON");
        }

        // Validate product_id
        if (!body.product_id || typeof body.product_id !== "string") {
            throw new AppError(400, "INVALID_PRODUCT_ID", "product_id is required");
        }
        const productId = body.product_id.trim();
        if (!ALLOWED_PRODUCT_IDS.has(productId)) {
            throw new AppError(400, "INVALID_PRODUCT_ID", "product_id is not allowed");
        }

        // Validate install_id
        const installId = requireUUID(body.install_id, "install_id", "INVALID_INSTALL_ID");

        const principal = authRequiredForCheckout(env)
            ? await requireAuthSession(request, env)
            : await optionalAuthSession(request, env);

        let email = body.email ? requireEmail(body.email) : null;
        if (principal) {
            if (email && email !== principal.email) {
                throw new AppError(
                    403,
                    "ACCOUNT_MISMATCH",
                    "Checkout email must match the signed-in account",
                );
            }
            email = principal.email;
        }

        if (authRequiredForCheckout(env) && !principal) {
            throw new AppError(401, "AUTH_REQUIRED", "Sign in is required before checkout");
        }

        // Build the success URL with install binding
        const successUrl = buildReturnURL(body.return_url, installId);

        // Create checkout session via Dodo API.
        const checkoutPayload: Record<string, unknown> = {
            product_cart: [
                {
                    product_id: productId,
                    quantity: 1,
                },
            ],
            return_url: successUrl,
            metadata: {
                install_id: installId,
            },
        };

        if (email) {
            checkoutPayload.customer = {
                email,
            };
        }

        const response = await fetch(`${env.DODO_BASE_URL}/checkouts`, {
            method: "POST",
            headers: {
                Authorization: `Bearer ${env.DODO_API_KEY}`,
                "Content-Type": "application/json",
            },
            body: JSON.stringify(checkoutPayload),
        });

        if (!response.ok) {
            const providerBody = await response.text().catch(() => "");
            console.error(
                `[${requestId}] checkout provider error status=${response.status} body=${providerBody}`,
            );
            throw new AppError(502, "PROVIDER_ERROR", "Failed to create checkout session");
        }

        const data = (await response.json()) as Record<string, unknown>;
        const paymentLink =
            readTrimmedString(data.payment_link) ||
            readTrimmedString(data.checkout_url) ||
            readTrimmedString(data.url);
        const checkoutSessionId =
            readTrimmedString(data.checkout_session_id) ||
            readTrimmedString(data.session_id) ||
            readTrimmedString(data.payment_id);

        if (!paymentLink) {
            throw new AppError(502, "PROVIDER_ERROR", "No payment link returned");
        }
        if (!checkoutSessionId) {
            throw new AppError(502, "PROVIDER_ERROR", "No checkout session id returned");
        }

        // Pre-link install_id to this checkout session
        await env.STRATA_DB.prepare(
            `INSERT INTO purchase_links (install_id, checkout_session_id, customer_email, created_at, updated_at)
             VALUES (?, ?, ?, datetime('now'), datetime('now'))
             ON CONFLICT(install_id) DO UPDATE SET
               checkout_session_id = excluded.checkout_session_id,
               customer_email = COALESCE(excluded.customer_email, purchase_links.customer_email),
               updated_at = datetime('now')`,
        )
            .bind(installId, checkoutSessionId, email)
            .run();

        const result: CheckoutSessionResponse = {
            checkout_url: paymentLink,
            session_id: checkoutSessionId,
        };

        return new Response(JSON.stringify(result), {
            status: 200,
            headers: { "Content-Type": "application/json" },
        });
    } catch (error) {
        return handleError(error, requestId);
    }
}
