import assert from "node:assert/strict";
import test from "node:test";

import { installationTokenRequest } from "./github_app_token_profiles.mjs";

test("release profile is confined to Harn", () => {
  assert.deepEqual(installationTokenRequest("harn-release"), {
    repository_names: ["harn"],
    permissions: { actions: "write", contents: "write", pull_requests: "write" },
  });
});

test("fleet profile is organization-wide but permission-minimal", () => {
  assert.deepEqual(installationTokenRequest("fleet-orchestration"), {
    permissions: {
      actions: "write",
      contents: "write",
      pull_requests: "write",
      workflows: "write",
    },
  });
});

test("unknown profiles fail closed", () => {
  assert.throws(() => installationTokenRequest("all-access"), /unknown RELEASE_APP_TOKEN_PROFILE/);
});
