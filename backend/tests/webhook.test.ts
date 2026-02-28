// ---------------------------------------------------------------------------
// Tests for POST /v1/webhooks/dodo
// ---------------------------------------------------------------------------

import { describe, it, expect } from "vitest";
import { timingSafeEqual } from "../src/routes/webhook.js";

describe("webhook", () => {
    describe("timingSafeEqual", () => {
        it("should return true for equal strings", () => {
            expect(timingSafeEqual("abc", "abc")).toBe(true);
            expect(timingSafeEqual("", "")).toBe(true);
        });

        it("should return false for different strings", () => {
            expect(timingSafeEqual("abc", "def")).toBe(false);
            expect(timingSafeEqual("abc", "ab")).toBe(false);
        });

        it("should return false for different lengths", () => {
            expect(timingSafeEqual("short", "longer")).toBe(false);
        });
    });

    // Note: Full webhook handler integration tests require a D1 mock
    // which is complex to set up in unit tests. The signature verification,
    // idempotency, and projection logic are tested through their respective
    // modules (projector.test.ts, signing.test.ts).
});
