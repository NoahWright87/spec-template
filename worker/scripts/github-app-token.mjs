#!/usr/bin/env node
// Generates a GitHub App installation access token from environment variables.
//
// Required env vars:
//   GITHUB_APP_ID              — numeric App ID
//   GITHUB_APP_PRIVATE_KEY     — PEM private key (raw or base64-encoded)
//   GITHUB_APP_INSTALLATION_ID — numeric installation ID
//
// Prints the token (ghs_...) to stdout. Errors go to stderr.
// Uses only Node built-ins — no npm dependencies.

import { createSign } from "node:crypto";
import { request } from "node:https";

const { GITHUB_APP_ID, GITHUB_APP_PRIVATE_KEY, GITHUB_APP_INSTALLATION_ID } =
  process.env;

if (!GITHUB_APP_ID || !GITHUB_APP_PRIVATE_KEY || !GITHUB_APP_INSTALLATION_ID) {
  console.error(
    "github-app-token: GITHUB_APP_ID, GITHUB_APP_PRIVATE_KEY, and GITHUB_APP_INSTALLATION_ID are all required"
  );
  process.exit(1);
}

// ── Build a RS256 JWT ─────────────────────────────────────────────────────────
function base64url(data) {
  const buf = typeof data === "string" ? Buffer.from(data) : data;
  return buf.toString("base64url");
}

function post(url, body, headers) {
  return new Promise((resolve, reject) => {
    const req = request(url, { method: "POST", headers, timeout: 30_000 }, (res) => {
      const chunks = [];
      res.on("data", (c) => chunks.push(c));
      res.on("end", () => {
        const text = Buffer.concat(chunks).toString();
        if (res.statusCode >= 200 && res.statusCode < 300) {
          if (!text) {
            reject(new Error("GitHub API returned a 2xx status with an empty response body; expected JSON."));
            return;
          }
          try {
            resolve(JSON.parse(text));
          } catch (e) {
            reject(new Error(`Failed to parse GitHub API response as JSON: ${e.message}. Body (truncated): ${text.slice(0, 500)}`));
          }
        } else {
          reject(
            new Error(
              `GitHub API ${res.statusCode}: ${text.slice(0, 500)}`
            )
          );
        }
      });
    });
    req.on("timeout", () => { req.destroy(); reject(new Error("GitHub API request timed out after 30s")); });
    req.on("error", reject);
    req.end(JSON.stringify(body));
  });
}

try {
  // Decode the private key — accept raw PEM or base64-encoded PEM.
  const privateKey = GITHUB_APP_PRIVATE_KEY.trimStart().startsWith("-----BEGIN")
    ? GITHUB_APP_PRIVATE_KEY
    : Buffer.from(GITHUB_APP_PRIVATE_KEY, "base64").toString("utf8");

  const now = Math.floor(Date.now() / 1000);
  const header = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const payload = base64url(
    JSON.stringify({
      iat: now - 60, // 60s clock skew allowance
      exp: now + 600, // 10 min max lifetime
      iss: GITHUB_APP_ID,
    })
  );

  const signer = createSign("RSA-SHA256");
  signer.update(`${header}.${payload}`);
  const signature = signer.sign(privateKey, "base64url");
  const jwt = `${header}.${payload}.${signature}`;

  // ── Exchange JWT for an installation access token ───────────────────────────
  const data = await post(
    `https://api.github.com/app/installations/${GITHUB_APP_INSTALLATION_ID}/access_tokens`,
    {},
    {
      Authorization: `Bearer ${jwt}`,
      Accept: "application/vnd.github+json",
      "User-Agent": "spec-template-worker",
      "Content-Type": "application/json",
    }
  );

  if (!data.token) {
    console.error("github-app-token: response missing 'token' field:", JSON.stringify(data));
    process.exit(1);
  }

  process.stdout.write(data.token);
} catch (err) {
  console.error(`github-app-token: ${err.message}`);
  process.exit(1);
}
