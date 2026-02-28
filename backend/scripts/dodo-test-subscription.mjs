#!/usr/bin/env node

// Dodo test subscription helper
// - check: show active test subscriptions for an email
// - cancel: immediately cancel all active test subscriptions for an email

const DEFAULT_BASE_URL = "https://test.dodopayments.com";

function usage() {
  console.log(
    [
      "Usage:",
      "  node backend/scripts/dodo-test-subscription.mjs <check|cancel> --email <email> [--api-key <key>] [--base <url>]",
      "",
      "Examples:",
      "  node backend/scripts/dodo-test-subscription.mjs check --email kacher@kachersoft.com",
      "  node backend/scripts/dodo-test-subscription.mjs cancel --email kacher@kachersoft.com",
      "",
      "Defaults:",
      "  --base defaults to https://test.dodopayments.com",
      "  --api-key defaults to DODO_API_KEY env var",
    ].join("\n")
  );
}

function parseArgs(argv) {
  if (argv.length === 0 || argv.includes("--help") || argv.includes("-h")) {
    return { help: true };
  }

  const mode = argv[0];
  if (mode !== "check" && mode !== "cancel") {
    throw new Error(`invalid mode: ${mode}`);
  }

  const options = {
    mode,
    email: "",
    apiKey: process.env.DODO_API_KEY || "",
    base: DEFAULT_BASE_URL,
  };

  for (let i = 1; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = argv[i + 1];

    if (arg === "--email") {
      if (!next) throw new Error("--email requires a value");
      options.email = next.trim().toLowerCase();
      i += 1;
      continue;
    }
    if (arg === "--api-key") {
      if (!next) throw new Error("--api-key requires a value");
      options.apiKey = next.trim();
      i += 1;
      continue;
    }
    if (arg === "--base") {
      if (!next) throw new Error("--base requires a value");
      options.base = next.trim().replace(/\/+$/, "");
      i += 1;
      continue;
    }

    throw new Error(`unknown argument: ${arg}`);
  }

  if (!options.email) {
    throw new Error("--email is required");
  }
  if (!options.apiKey) {
    throw new Error("DODO_API_KEY is required (env or --api-key)");
  }

  return options;
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

async function findCustomer(base, apiKey, email) {
  const customers = await request(base, apiKey, `/customers?email=${encodeURIComponent(email)}`);
  if (customers.status >= 300) {
    throw new Error(`customers lookup failed (${customers.status}): ${JSON.stringify(customers.body)}`);
  }

  const items = Array.isArray(customers.body?.items) ? customers.body.items : [];
  return items.find((item) => (item.email || "").trim().toLowerCase() === email) || null;
}

async function listActiveSubscriptions(base, apiKey, customerId) {
  const subscriptions = await request(
    base,
    apiKey,
    `/subscriptions?customer_id=${encodeURIComponent(customerId)}&status=active`
  );
  if (subscriptions.status >= 300) {
    throw new Error(
      `subscriptions lookup failed (${subscriptions.status}): ${JSON.stringify(subscriptions.body)}`
    );
  }

  return Array.isArray(subscriptions.body?.items) ? subscriptions.body.items : [];
}

async function cancelSubscriptionNow(base, apiKey, subscriptionId) {
  let result = await request(base, apiKey, `/subscriptions/${encodeURIComponent(subscriptionId)}`, {
    method: "PATCH",
    body: JSON.stringify({ status: "cancelled" }),
  });

  if (result.status >= 300) {
    result = await request(base, apiKey, `/subscriptions/${encodeURIComponent(subscriptionId)}`, {
      method: "PATCH",
      body: JSON.stringify({ cancel_at_next_billing_date: false, status: "cancelled" }),
    });
  }

  return result;
}

async function main() {
  let parsed;
  try {
    parsed = parseArgs(process.argv.slice(2));
  } catch (error) {
    console.error(error.message);
    usage();
    process.exit(1);
  }

  if (parsed.help) {
    usage();
    return;
  }

  const { mode, email, apiKey, base } = parsed;
  const customer = await findCustomer(base, apiKey, email);

  if (!customer?.customer_id) {
    console.log(`No customer found for ${email} in ${base}.`);
    return;
  }

  const customerId = customer.customer_id;
  const activeSubscriptions = await listActiveSubscriptions(base, apiKey, customerId);

  if (mode === "check") {
    console.log(`Customer: ${customerId}`);
    console.log(`Active subscriptions: ${activeSubscriptions.length}`);
    for (const sub of activeSubscriptions) {
      const id = sub.subscription_id || sub.id || "(unknown)";
      const product = sub.product_id || "(unknown)";
      console.log(`- ${id} (${product})`);
    }
    return;
  }

  if (activeSubscriptions.length === 0) {
    console.log(`No active subscriptions for ${email} (customer ${customerId}).`);
    return;
  }

  console.log(
    `Found ${activeSubscriptions.length} active subscription(s) for ${email} (customer ${customerId}).`
  );

  let hasError = false;
  for (const sub of activeSubscriptions) {
    const id = sub.subscription_id || sub.id;
    if (!id) {
      console.log("- Skipped one subscription without id");
      hasError = true;
      continue;
    }

    const cancelled = await cancelSubscriptionNow(base, apiKey, id);
    if (cancelled.status >= 300) {
      console.log(`- Failed to cancel ${id}: ${cancelled.status} ${JSON.stringify(cancelled.body)}`);
      hasError = true;
      continue;
    }

    const newStatus = cancelled.body?.status || "(unknown)";
    console.log(`- Cancelled ${id}. New status: ${newStatus}`);
  }

  const remaining = await listActiveSubscriptions(base, apiKey, customerId);
  console.log(`Active subscriptions after cancel: ${remaining.length}`);

  if (hasError) process.exit(1);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
