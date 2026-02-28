#!/usr/bin/env node

import { readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = join(__filename, "..");
const wranglerPath = join(__dirname, "..", "wrangler.jsonc");

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const PLACEHOLDER_DB_ID = "00000000-0000-0000-0000-000000000000";
const REQUIRED_VARS = ["ENVIRONMENT", "DODO_BASE_URL", "TOKEN_TTL_SECONDS"];

function stripJsonComments(input) {
    return input
        .replace(/\/\*[\s\S]*?\*\//g, "")
        .replace(/^\s*\/\/.*$/gm, "");
}

function fail(message) {
    console.error(`Config validation failed: ${message}`);
    process.exit(1);
}

const raw = readFileSync(wranglerPath, "utf8");
let config;
try {
    config = JSON.parse(stripJsonComments(raw));
} catch (error) {
    fail(`unable to parse wrangler.jsonc (${error.message})`);
}

function validateVars(scopeName, vars, expectedEnvironment) {
    if (!vars || typeof vars !== "object") {
        fail(`${scopeName}: vars configuration is missing`);
    }

    for (const key of REQUIRED_VARS) {
        const value = typeof vars[key] === "string" ? vars[key].trim() : "";
        if (!value) {
            fail(`${scopeName}: missing required var "${key}"`);
        }
    }

    const environmentValue = String(vars.ENVIRONMENT).trim().toLowerCase();
    if (environmentValue !== expectedEnvironment) {
        fail(
            `${scopeName}: ENVIRONMENT must be "${expectedEnvironment}" (found "${vars.ENVIRONMENT}")`,
        );
    }
}

function validateDatabases(scopeName, databases) {
    if (!Array.isArray(databases) || !databases.length) {
        fail(`${scopeName}: missing d1_databases configuration`);
    }

    for (const db of databases) {
        const dbName = db?.database_name || "(unknown database)";
        const id = typeof db?.database_id === "string" ? db.database_id.trim() : "";
        if (!id) {
            fail(`${scopeName}:${dbName}: database_id is missing`);
        }
        if (!UUID_RE.test(id)) {
            fail(`${scopeName}:${dbName}: database_id is not a valid UUID`);
        }
        if (id === PLACEHOLDER_DB_ID) {
            fail(`${scopeName}:${dbName}: database_id still uses placeholder value`);
        }
    }
}

validateVars("production", config.vars, "production");
validateDatabases("production", config.d1_databases);

if (!config.env || typeof config.env !== "object") {
    fail("missing env configuration object");
}

if (!config.env.test || typeof config.env.test !== "object") {
    fail("missing env.test configuration");
}

validateVars("test", config.env.test.vars, "test");
validateDatabases("test", config.env.test.d1_databases);

console.log("wrangler.jsonc validation passed");
