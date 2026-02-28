// ---------------------------------------------------------------------------
// Tests for event projection engine
// ---------------------------------------------------------------------------

import { describe, it, expect, vi, beforeEach } from "vitest";
import {
    processWebhookEvent,
    projectEvent,
    TIER_PRECEDENCE,
    isStaleEvent,
} from "../src/projector.js";
import type { Env } from "../src/types.js";

const mockFetch = vi.fn();
vi.stubGlobal("fetch", mockFetch);

describe("projector", () => {
    beforeEach(() => {
        vi.clearAllMocks();
    });

    describe("projectEvent", () => {
        it("should project subscription.active to pro/active", () => {
            const result = projectEvent("subscription.active", {
                data: {
                    customer_email: "pro@example.com",
                    current_period_start: "2026-02-01T00:00:00Z",
                    current_period_end: "2026-03-01T00:00:00Z",
                },
            });
            expect(result).not.toBeNull();
            expect(result!.tier).toBe("pro");
            expect(result!.state).toBe("active");
            expect(result!.subjectType).toBe("email");
            expect(result!.subjectId).toBe("pro@example.com");
        });

        it("should project subscription.cancelled to pro/inactive", () => {
            const result = projectEvent("subscription.cancelled", {
                data: { customer_email: "cancelled@example.com" },
            });
            expect(result).not.toBeNull();
            expect(result!.tier).toBe("pro");
            expect(result!.state).toBe("inactive");
            expect(result!.subjectId).toBe("cancelled@example.com");
        });

        it("should project subscription.expired to pro/inactive", () => {
            const result = projectEvent("subscription.expired", {
                data: { customer_email: "expired@example.com" },
            });
            expect(result).not.toBeNull();
            expect(result!.state).toBe("inactive");
        });

        it("should project subscription.renewed to pro/active", () => {
            const result = projectEvent("subscription.renewed", {
                data: { customer_email: "renewed@example.com", status: "active" },
            });
            expect(result).not.toBeNull();
            expect(result!.tier).toBe("pro");
            expect(result!.state).toBe("active");
        });

        it("should project subscription.failed to pro/inactive", () => {
            const result = projectEvent("subscription.failed", {
                data: { customer_email: "failed@example.com", status: "failed" },
            });
            expect(result).not.toBeNull();
            expect(result!.tier).toBe("pro");
            expect(result!.state).toBe("inactive");
        });

        it("should project license_key.created for VIP product to vip/active", () => {
            const result = projectEvent("license_key.created", {
                data: {
                    customer_email: "vip@example.com",
                    product_id: "pdt_0NZEzLgAEu8PcrUBqi8mt", // vipLifetime
                },
            });
            expect(result).not.toBeNull();
            expect(result!.tier).toBe("vip");
            expect(result!.state).toBe("active");
        });

        it("should return null for license_key.created with non-VIP product", () => {
            const result = projectEvent("license_key.created", {
                data: {
                    customer_email: "user@example.com",
                    product_id: "pdt_something_else",
                },
            });
            expect(result).toBeNull();
        });

        it("should return null for payment.succeeded", () => {
            const result = projectEvent("payment.succeeded", {
                data: { customer_email: "user@example.com" },
            });
            expect(result).toBeNull();
        });

        it("should return null for unknown event types", () => {
            const result = projectEvent("order.created", {
                data: { customer_email: "user@example.com" },
            });
            expect(result).toBeNull();
        });

        it("should normalize email to lowercase", () => {
            const result = projectEvent("subscription.active", {
                data: { customer_email: "  User@Example.COM  " },
            });
            expect(result).not.toBeNull();
            expect(result!.subjectId).toBe("user@example.com");
        });

        it("should extract email from customer object", () => {
            const result = projectEvent("subscription.active", {
                data: {
                    customer: { email: "nested@example.com" },
                },
            });
            expect(result).not.toBeNull();
            expect(result!.subjectId).toBe("nested@example.com");
        });

        it("should return null when no email can be extracted", () => {
            const result = projectEvent("subscription.active", {
                data: {},
            });
            expect(result).toBeNull();
        });
    });

    describe("tier precedence", () => {
        it("should have vip > pro > free", () => {
            expect(TIER_PRECEDENCE.vip).toBeGreaterThan(TIER_PRECEDENCE.pro);
            expect(TIER_PRECEDENCE.pro).toBeGreaterThan(TIER_PRECEDENCE.free);
        });
    });

    describe("event ordering", () => {
        it("should treat older incoming events as stale", () => {
            expect(isStaleEvent("200", "100")).toBe(true);
        });

        it("should accept same-or-newer incoming events", () => {
            expect(isStaleEvent("200", "200")).toBe(false);
            expect(isStaleEvent("200", "300")).toBe(false);
        });
    });

    describe("processWebhookEvent", () => {
        it("should ignore lower-tier events without overwriting entitlement source_event_id", async () => {
            const runSql: string[] = [];

            const env: Env = {
                STRATA_DB: {
                    prepare(sql: string) {
                        let boundArgs: unknown[] = [];

                        return {
                            bind(...args: unknown[]) {
                                boundArgs = args;
                                return this;
                            },
                            async first() {
                                if (sql.includes("FROM entitlements e")) {
                                    return {
                                        id: 1,
                                        tier: "vip",
                                        state: "active",
                                        updated_at: "2026-02-26T00:00:00Z",
                                        source_event_id: "wh_prev",
                                        source_event_ts: "100",
                                    };
                                }
                                return null;
                            },
                            async run() {
                                runSql.push(sql);
                                return { success: true, meta: { changes: 1, boundArgs } };
                            },
                        };
                    },
                } as unknown as D1Database,
                DODO_API_KEY: "test",
                DODO_WEBHOOK_SECRET: "test",
                ENTITLEMENT_SIGNING_PRIVATE_KEY: "test",
                ENVIRONMENT: "test",
                DODO_BASE_URL: "https://test.dodopayments.com",
                TOKEN_TTL_SECONDS: "3600",
            };

            await processWebhookEvent(
                env,
                "wh_new",
                "subscription.cancelled",
                { data: { customer_email: "vip@example.com" } },
                "200",
            );

            expect(runSql.some((sql) => sql.includes("UPDATE entitlements"))).toBe(false);
            expect(runSql.some((sql) => sql.includes("SET status = 'ignored'"))).toBe(true);
        });

        it("should resolve customer email for license_key.created via customer lookup", async () => {
            mockFetch.mockResolvedValueOnce(
                new Response(
                    JSON.stringify({
                        customer_id: "cus_123",
                        email: "vip@example.com",
                    }),
                    { status: 200 },
                ),
            );

            const runSql: string[] = [];
            const env: Env = {
                STRATA_DB: {
                    prepare(sql: string) {
                        return {
                            bind() {
                                return this;
                            },
                            async first() {
                                return null;
                            },
                            async run() {
                                runSql.push(sql);
                                return { success: true, meta: { changes: 1 } };
                            },
                        };
                    },
                } as unknown as D1Database,
                DODO_API_KEY: "test",
                DODO_WEBHOOK_SECRET: "test",
                ENTITLEMENT_SIGNING_PRIVATE_KEY: "test",
                ENVIRONMENT: "test",
                DODO_BASE_URL: "https://test.dodopayments.com",
                TOKEN_TTL_SECONDS: "3600",
            };

            await processWebhookEvent(
                env,
                "wh_license",
                "license_key.created",
                {
                    data: {
                        customer_id: "cus_123",
                        product_id: "pdt_0NZEzLgAEu8PcrUBqi8mt",
                    },
                },
                "200",
            );

            expect(runSql.some((sql) => sql.includes("INSERT INTO entitlements"))).toBe(true);
            expect(runSql.some((sql) => sql.includes("status = 'processed'"))).toBe(true);
        });
    });
});
