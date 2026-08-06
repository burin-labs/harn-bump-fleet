#!/usr/bin/env node
// Mint a short-lived GitHub App installation token for burin-labs/harn.
//
// Installation tokens expire after one hour. Long hosted ship-pr runs
// (certification alone is ~40m) outlive a token minted at job start, so the
// credential helper and GH_TOKEN must be refreshed before late git pushes.
//
// Inputs (env):
//   RELEASE_APP_CLIENT_ID   — App client id (JWT iss)
//   RELEASE_APP_PRIVATE_KEY — PEM private key
//   RELEASE_APP_OWNER       — org/user that owns the installation (default burin-labs)
//   RELEASE_APP_REPO        — repository name (default harn)
//
// Prints the token on stdout and nothing else.

import crypto from "node:crypto";
import process from "node:process";

function requireEnv(name) {
  const value = process.env[name];
  if (value == null || String(value).trim() === "") {
    console.error(`${name} is required`);
    process.exit(2);
  }
  return String(value);
}

function b64url(input) {
  return Buffer.from(input)
    .toString("base64")
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

function mintJwt(clientId, privateKeyPem) {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const payload = b64url(
    JSON.stringify({
      iat: now - 60,
      exp: now + 9 * 60,
      iss: clientId,
    }),
  );
  const data = `${header}.${payload}`;
  const sign = crypto.createSign("RSA-SHA256");
  sign.update(data);
  sign.end();
  const signature = sign
    .sign(privateKeyPem)
    .toString("base64")
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
  return `${data}.${signature}`;
}

async function githubJson(url, token, init = {}) {
  const response = await fetch(url, {
    ...init,
    headers: {
      Accept: "application/vnd.github+json",
      Authorization: `Bearer ${token}`,
      "X-GitHub-Api-Version": "2022-11-28",
      "User-Agent": "harn-bump-fleet-hosted-release",
      ...(init.headers ?? {}),
    },
  });
  const text = await response.text();
  let body = null;
  try {
    body = text ? JSON.parse(text) : null;
  } catch {
    body = { message: text };
  }
  if (!response.ok) {
    const message = body?.message ?? text ?? response.statusText;
    throw new Error(`${init.method ?? "GET"} ${url} -> ${response.status}: ${message}`);
  }
  return body;
}

const clientId = requireEnv("RELEASE_APP_CLIENT_ID");
const privateKey = requireEnv("RELEASE_APP_PRIVATE_KEY").replace(/\\n/g, "\n");
const owner = process.env.RELEASE_APP_OWNER?.trim() || "burin-labs";
const repo = process.env.RELEASE_APP_REPO?.trim() || "harn";

const jwt = mintJwt(clientId, privateKey);
const installation = await githubJson(
  `https://api.github.com/repos/${owner}/${repo}/installation`,
  jwt,
);
if (installation?.id == null) {
  console.error(`no installation id for ${owner}/${repo}`);
  process.exit(1);
}
const access = await githubJson(
  `https://api.github.com/app/installations/${installation.id}/access_tokens`,
  jwt,
  { method: "POST" },
);
const token = access?.token;
if (typeof token !== "string" || token.trim() === "") {
  console.error("installation token response omitted token");
  process.exit(1);
}
process.stdout.write(token.trim());
