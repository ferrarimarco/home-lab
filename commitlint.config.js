module.exports = {
  extends: ["@commitlint/config-conventional"],
  helpUrl: "https://www.conventionalcommits.org/",
  ignores: [
    // We need this until https://github.com/dependabot/dependabot-core/issues/2445
    // is resolved.
    (msg) => /Signed-off-by: dependabot\[bot]/m.test(msg),
    // Renovate writes commit subjects that exceed the maximum length
    (msg) => /^(chore|fix)\(deps\): /.test(msg),
  ],
  rules: {
    "body-max-line-length": [2, "always", 72],
    "footer-max-line-length": [2, "always", 72],
    "header-max-length": [2, "always", 50],
  },
};
