// ---------------------------------------------------------------------------
// Shared TypeScript types for Strata Backend
// ---------------------------------------------------------------------------

/** Cloudflare Worker environment bindings */
export interface Env {
    // D1 database
    STRATA_DB: D1Database;

    // Secrets (set via `wrangler secret put`)
    DODO_API_KEY: string;
    DODO_WEBHOOK_SECRET: string;
    ENTITLEMENT_SIGNING_PRIVATE_KEY: string; // hex-encoded Ed25519 seed
    ENTITLEMENT_SIGNING_PRIVATE_KEY_PREV?: string; // hex-encoded Ed25519 seed (previous key during rotation)
    ENTITLEMENT_SIGNING_KEY_ID?: string; // identifier for current signing key (e.g. "v2")
    ENTITLEMENT_SIGNING_KEY_ID_PREV?: string; // identifier for previous signing key (e.g. "v1")

    // Environment variables (set in wrangler.jsonc)
    ENVIRONMENT: string;
    DODO_BASE_URL: string;
    TOKEN_TTL_SECONDS: string;

    // Auth/account hardening flags
    ENFORCE_DEVICE_SEATS?: string;
    FREE_DEVICE_LIMIT?: string;
    PRO_DEVICE_LIMIT?: string;
    VIP_DEVICE_LIMIT?: string;

    // OTP/session config
    AUTH_OTP_TTL_SECONDS?: string;
    AUTH_OTP_MAX_ATTEMPTS?: string;
    AUTH_SESSION_TTL_SECONDS?: string;
    AUTH_RATE_LIMIT_WINDOW_SECONDS?: string;
    AUTH_START_MAX_PER_EMAIL?: string;
    AUTH_START_MAX_PER_IP?: string;
    AUTH_EMAIL_FROM?: string;
    RESEND_API_KEY?: string;
}

/** Entitlement tier */
export type Tier = "free" | "pro" | "vip";

/** Entitlement state */
export type EntitlementState = "active" | "inactive";

// ---------------------------------------------------------------------------
// Token claims
// ---------------------------------------------------------------------------

export interface TokenClaims {
    /** Entitlement tier */
    tier: Tier;
    /** Subject (email, normalized lowercase) */
    sub: string;
    /** Internal user id (account-based flow) */
    uid?: string;
    /** Install ID that requested the token */
    install_id: string;
    /** Issued-at (Unix seconds) */
    iat: number;
    /** Expiration (Unix seconds) */
    exp: number;
    /** Unique token ID */
    jti: string;
    /** Key ID for rotation support — identifies which public key to verify against */
    kid?: string;
    /** Reserved for Phase 3 install binding */
    install_pubkey_hash?: string;
}

// ---------------------------------------------------------------------------
// API request / response shapes
// ---------------------------------------------------------------------------

export interface ResolveRequest {
    email?: string;
    install_id: string;
    challenge_id: string;
    nonce_signature: string;
}

export interface ResolveResponse {
    token: string;
}

export interface PortalSessionRequest {
    email?: string;
    install_id: string;
    challenge_id: string;
    nonce_signature: string;
}

export interface PortalSessionResponse {
    portal_url: string;
}

export interface InstallRegisterRequest {
    install_id: string;
    install_pubkey: string;
}

export interface InstallRegisterResponse {
    registered: boolean;
}

export interface InstallChallengeRequest {
    install_id: string;
}

export interface InstallChallengeResponse {
    challenge_id: string;
    nonce: string;
    expires_at: number;
}

export interface CheckoutSessionRequest {
    product_id: string;
    install_id: string;
    email?: string;
    return_url?: string;
}

export interface CheckoutSessionResponse {
    checkout_url: string;
    session_id: string;
}

export interface RestoreRequest {
    email?: string;
    install_id: string;
    challenge_id: string;
    nonce_signature: string;
    license_key?: string;
}

export interface RestoreResponse {
    token: string;
    restore_type: "subscription" | "lifetime" | "none";
    resolved_email?: string;
}

export interface AuthStartRequest {
    email: string;
}

export interface AuthStartResponse {
    challenge_id: string;
    expires_at: number;
    delivery: "email" | "dev-log";
}

export interface AuthVerifyRequest {
    email: string;
    challenge_id: string;
    code: string;
}

export interface AuthVerifyResponse {
    session_token: string;
    session_expires_at: number;
    user_id: string;
    email: string;
}

export interface DeviceInfo {
    install_id: string;
    nickname?: string | null;
    first_seen_at: number;
    last_seen_at: number;
    revoked_at?: number | null;
    active: boolean;
}

export interface DevicesListResponse {
    devices: DeviceInfo[];
}

export interface RevokeDeviceRequest {
    install_id: string;
}

// ---------------------------------------------------------------------------
// Structured error response
// ---------------------------------------------------------------------------

export interface ErrorResponse {
    error_code: string;
    message: string;
    request_id: string;
}

// ---------------------------------------------------------------------------
// Dodo API types
// ---------------------------------------------------------------------------

export interface DodoCustomer {
    customer_id: string;
    email: string;
}

export interface DodoCustomerList {
    items: DodoCustomer[];
}

export interface DodoSubscriptionCustomer {
    customer_id?: string;
    email?: string;
}

export interface DodoSubscription {
    status: string;
    product_id: string;
    next_billing_date?: string;
    customer?: DodoSubscriptionCustomer;
}

export interface DodoSubscriptionList {
    items: DodoSubscription[];
}

export interface DodoPortalSession {
    link: string;
}

// ---------------------------------------------------------------------------
// Known Dodo product IDs (mirrored from Swift DodoPaymentsClient)
// ---------------------------------------------------------------------------

export const PRODUCT_IDS = {
    proMonthly: "pdt_0NZEvu9tI0aecVEYkmxOH",
    proYearly: "pdt_0NZEzxFzK5RRekOJXQHpZ",
    vipLifetime: "pdt_0NZEzLgAEu8PcrUBqi8mt",
} as const;

export const PRO_PRODUCT_IDS: ReadonlySet<string> = new Set<string>([
    PRODUCT_IDS.proMonthly,
    PRODUCT_IDS.proYearly,
]);
