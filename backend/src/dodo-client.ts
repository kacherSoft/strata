// ---------------------------------------------------------------------------
// Server-side Dodo API client
// ---------------------------------------------------------------------------

import type {
    Env,
    DodoCustomerList,
    DodoSubscriptionList,
    DodoPortalSession,
    DodoSubscription,
} from "./types.js";
import { PRO_PRODUCT_IDS as PRO_IDS } from "./types.js";
import { AppError } from "./errors.js";

export interface ActiveSubscriptionResult {
    customerId: string;
    productId: string;
    nextBillingDateISO8601: string;
}

interface DodoCustomerByIdResponse {
    customer_id?: string;
    email?: string;
}

/**
 * Server-side client for Dodo Payments API.
 * Uses the secret API key stored in Worker secrets.
 */
export class DodoClient {
    private baseURL: string;
    private apiKey: string;

    constructor(env: Env) {
        this.baseURL = env.DODO_BASE_URL || "https://test.dodopayments.com";
        this.apiKey = env.DODO_API_KEY;
    }

    /**
     * Find a customer ID by email address.
     */
    async findCustomerId(email: string): Promise<string | null> {
        const url = new URL(`${this.baseURL}/customers`);
        url.searchParams.set("email", email);

        const data = await this.get<DodoCustomerList>(url.toString());
        const match = data.items.find(
            (c) => c.email.trim().toLowerCase() === email,
        );
        return match?.customer_id ?? null;
    }

    /**
     * Find a customer email by customer ID.
     */
    async findCustomerEmailById(customerId: string): Promise<string | null> {
        const normalizedCustomerId = customerId.trim();
        if (!normalizedCustomerId) return null;

        const url = `${this.baseURL}/customers/${encodeURIComponent(normalizedCustomerId)}`;
        try {
            const data = await this.get<DodoCustomerByIdResponse>(url);
            const normalized = (data.email || "").trim().toLowerCase();
            return normalized || null;
        } catch (error) {
            if (error instanceof AppError && error.statusCode === 404) {
                return null;
            }
            throw error;
        }
    }

    /**
     * Find an active Pro subscription for a customer.
     */
    async findActiveSubscription(
        email: string,
    ): Promise<ActiveSubscriptionResult | null> {
        const customerId = await this.findCustomerId(email);
        if (!customerId) return null;

        const url = new URL(`${this.baseURL}/subscriptions`);
        url.searchParams.set("customer_id", customerId);
        url.searchParams.set("status", "active");

        const data = await this.get<DodoSubscriptionList>(url.toString());

        const matched = data.items.find((sub: DodoSubscription) => {
            if (sub.status !== "active") return false;
            if (!PRO_IDS.has(sub.product_id)) return false;

            const returnedEmail = (sub.customer?.email ?? "").trim().toLowerCase();
            const returnedCustomerId = (sub.customer?.customer_id ?? "").trim();
            if (returnedCustomerId && returnedCustomerId !== customerId) return false;
            if (returnedEmail && returnedEmail !== email) return false;
            return true;
        });

        if (!matched?.next_billing_date?.trim()) return null;

        return {
            customerId,
            productId: matched.product_id,
            nextBillingDateISO8601: matched.next_billing_date!,
        };
    }

    /**
     * Create a customer portal session and return the portal URL.
     */
    async createPortalSession(email: string): Promise<string> {
        const customerId = await this.findCustomerId(email);
        if (!customerId) {
            throw new AppError(404, "CUSTOMER_NOT_FOUND", "Customer not found for the provided email");
        }

        const url = `${this.baseURL}/customers/${customerId}/customer-portal/session?send_email=false`;
        const response = await fetch(url, {
            method: "POST",
            headers: {
                Authorization: `Bearer ${this.apiKey}`,
            },
        });

        if (!response.ok) {
            throw new AppError(502, "PROVIDER_ERROR", "Failed to create portal session");
        }

        const data = (await response.json()) as DodoPortalSession;
        if (!data.link || !data.link.startsWith("https://")) {
            throw new AppError(502, "PROVIDER_ERROR", "Invalid portal URL received from provider");
        }

        return data.link;
    }

    // -------------------------------------------------------------------------
    // Private
    // -------------------------------------------------------------------------

    private async get<T>(url: string): Promise<T> {
        const response = await fetch(url, {
            headers: {
                Authorization: `Bearer ${this.apiKey}`,
            },
        });

        if (!response.ok) {
            const status = response.status;
            // Don't propagate provider error details
            if (status === 404) {
                throw new AppError(404, "NOT_FOUND", "Resource not found");
            }
            if (status === 429) {
                throw new AppError(429, "RATE_LIMITED", "Provider rate limit exceeded");
            }
            throw new AppError(502, "PROVIDER_ERROR", "Provider request failed");
        }

        return (await response.json()) as T;
    }
}
