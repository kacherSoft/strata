#!/usr/bin/env node

// Dodo VIP product helper
// - check: show whether VIP product has license keys enabled
// - enable: enable license keys for VIP product

const ENVIRONMENTS = {
  test: {
    base: "https://test.dodopayments.com",
    apiKeyEnv: "DODO_API_KEY",
    productId: "pdt_0NZEzLgAEu8PcrUBqi8mt",
  },
  live: {
    base: "https://live.dodopayments.com",
    apiKeyEnv: "DODO_LIVE_API_KEY",
    productId: "pdt_0NZEzLgAEu8PcrUBqi8mt",
  },
};

function usage() {
  console.log(
    [
      "Usage:",
      "  node backend/scripts/dodo-vip-license-config.mjs <check|enable> [--env test|live] [--api-key <key>] [--product-id <id>]",
      "",
      "Examples:",
      "  node backend/scripts/dodo-vip-license-config.mjs check --env test",
      "  node backend/scripts/dodo-vip-license-config.mjs enable --env test",
      "",
      "Defaults:",
      "  --env defaults to test",
      "  --api-key defaults to DODO_API_KEY (test) or DODO_LIVE_API_KEY (live)",
      "  --product-id defaults to configured VIP product id",
    ].join("\n"),
  );
}

function parseArgs(argv) {
  if (argv.length === 0 || argv.includes("--help") || argv.includes("-h")) {
    return { help: true };
  }

  const mode = argv[0];
  if (mode !== "check" && mode !== "enable") {
    throw new Error(`invalid mode: ${mode}`);
  }

  let envName = "test";
  let apiKey = "";
  let productId = "";

  for (let i = 1; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = argv[i + 1];

    if (arg === "--env") {
      if (!next) throw new Error("--env requires a value");
      envName = next.trim().toLowerCase();
      i += 1;
      continue;
    }

    if (arg === "--api-key") {
      if (!next) throw new Error("--api-key requires a value");
      apiKey = next.trim();
      i += 1;
      continue;
    }

    if (arg === "--product-id") {
      if (!next) throw new Error("--product-id requires a value");
      productId = next.trim();
      i += 1;
      continue;
    }

    throw new Error(`unknown argument: ${arg}`);
  }

  const env = ENVIRONMENTS[envName];
  if (!env) {
    throw new Error(`invalid env: ${envName} (expected test|live)`);
  }

  const resolvedApiKey = apiKey || process.env[env.apiKeyEnv] || "";
  const resolvedProductId = productId || env.productId;

  if (!resolvedApiKey) {
    throw new Error(
      `${env.apiKeyEnv} is required (or pass --api-key)`,
    );
  }

  if (!resolvedProductId) {
    throw new Error("VIP product id is required");
  }

  return {
    help: false,
    mode,
    envName,
    base: env.base,
    apiKey: resolvedApiKey,
    productId: resolvedProductId,
  };
}

async function request(base, apiKey, path, opts = {}) {
  const response = await fetch(`${base}${path}`, {
    ...opts,
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
      ...(opts.headers || {}),
    },
  });

  const text = await response.text();
  let body = null;
  try {
    body = text ? JSON.parse(text) : null;
  } catch {
    body = text;
  }

  return { status: response.status, body };
}

function printProductSummary(product) {
  const summary = {
    product_id: product?.product_id || "(unknown)",
    name: product?.name || "(unknown)",
    is_recurring: Boolean(product?.is_recurring),
    license_key_enabled: Boolean(product?.license_key_enabled),
    license_key_activations_limit: product?.license_key_activations_limit ?? null,
    license_key_duration: product?.license_key_duration ?? null,
  };

  console.log(JSON.stringify(summary, null, 2));
}

async function fetchProduct(base, apiKey, productId) {
  const result = await request(base, apiKey, `/products/${encodeURIComponent(productId)}`);
  if (result.status >= 300 || !result.body || typeof result.body !== "object") {
    throw new Error(`failed to fetch product (${result.status}): ${JSON.stringify(result.body)}`);
  }
  return result.body;
}

async function checkWebhookFilter(base, apiKey) {
  const result = await request(base, apiKey, "/webhooks");
  if (result.status >= 300) {
    console.log(`webhook check failed (${result.status}): ${JSON.stringify(result.body)}`);
    return;
  }

  const endpoints = Array.isArray(result.body?.data) ? result.body.data : [];
  const strataEndpoint = endpoints.find((endpoint) =>
    typeof endpoint?.url === "string" && endpoint.url.includes("/v1/webhooks/dodo")
  );

  if (!strataEndpoint) {
    console.log("No /v1/webhooks/dodo endpoint found. Verify webhook configuration manually.");
    return;
  }

  const filterTypes = Array.isArray(strataEndpoint.filter_types)
    ? strataEndpoint.filter_types
    : [];
  const hasLicenseEvent = filterTypes.includes("license_key.created");

  console.log(
    `Webhook ${strataEndpoint.id}: license_key.created subscribed = ${hasLicenseEvent ? "yes" : "no"}`,
  );
}

async function main() {
  let options;
  try {
    options = parseArgs(process.argv.slice(2));
  } catch (error) {
    console.error(error.message);
    usage();
    process.exit(1);
  }

  if (options.help) {
    usage();
    return;
  }

  const { mode, base, apiKey, productId, envName } = options;

  console.log(`Environment: ${envName}`);
  console.log(`Base URL: ${base}`);

  if (mode === "enable") {
    const patch = await request(base, apiKey, `/products/${encodeURIComponent(productId)}`, {
      method: "PATCH",
      body: JSON.stringify({ license_key_enabled: true }),
    });

    if (patch.status >= 300) {
      throw new Error(`failed to enable license keys (${patch.status}): ${JSON.stringify(patch.body)}`);
    }

    console.log("Enabled license keys on VIP product.");
  }

  const product = await fetchProduct(base, apiKey, productId);
  printProductSummary(product);
  await checkWebhookFilter(base, apiKey);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
