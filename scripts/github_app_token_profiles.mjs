// The reviewed installation-token profiles, read from the one registry that
// every consumer of them reads.

import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const REGISTRY_PATH = join(
  dirname(dirname(fileURLToPath(import.meta.url))),
  "spec",
  "github-app-token-profiles.json",
);

const registry = JSON.parse(readFileSync(REGISTRY_PATH, "utf8"));

/** Every reviewed profile name, in registry order. */
export function tokenProfileNames() {
  return Object.keys(registry.profiles);
}

/** One profile's declared permissions, as `{permission: level}`. */
export function tokenProfilePermissions(profileName) {
  return { ...requireProfile(profileName).permissions };
}

function requireProfile(profileName) {
  const profile = registry.profiles[profileName];
  if (profile == null) {
    throw new Error(
      `unknown RELEASE_APP_TOKEN_PROFILE ${JSON.stringify(profileName)}; expected ${tokenProfileNames().join(" or ")}`,
    );
  }
  return profile;
}

/** Return one closed, reviewed installation-token request profile. */
export function installationTokenRequest(profileName) {
  const profile = requireProfile(profileName);
  return {
    ...(profile.repository_names == null
      ? {}
      : { repository_names: [...profile.repository_names] }),
    permissions: { ...profile.permissions },
  };
}
