const PROFILES = Object.freeze({
  "harn-release": Object.freeze({
    repositoryNames: Object.freeze(["harn"]),
    permissions: Object.freeze({
      actions: "write",
      contents: "write",
      pull_requests: "write",
      // The certification branch is pushed from `at_sha`, which may carry
      // `.github/workflows` changes not yet on the default branch. GitHub
      // refuses that push from any token without `workflows: write`, even
      // when the installation itself holds it.
      workflows: "write",
    }),
  }),
  "fleet-orchestration": Object.freeze({
    repositoryNames: null,
    permissions: Object.freeze({
      actions: "write",
      contents: "write",
      pull_requests: "write",
      workflows: "write",
    }),
  }),
});

/** Return one closed, reviewed installation-token request profile. */
export function installationTokenRequest(profileName) {
  const profile = PROFILES[profileName];
  if (profile == null) {
    throw new Error(
      `unknown RELEASE_APP_TOKEN_PROFILE ${JSON.stringify(profileName)}; expected ${Object.keys(PROFILES).join(" or ")}`,
    );
  }
  return {
    ...(profile.repositoryNames == null
      ? {}
      : { repository_names: [...profile.repositoryNames] }),
    permissions: { ...profile.permissions },
  };
}
