# NuGet trusted publishing

## Context

The `v8.0.2` release run (Actions run `42986317034`, workflow `release-nuget.yml`) failed at
**Publish to NuGet.org**. All four packages (`Clean`, `Clean.Core`, `Clean.Headless`,
`Umbraco.Community.Templates.Clean`) were rejected with:

> 403 (The specified API key has expired. Please create a new API key at https://www.nuget.org/account/apikeys.)

The workflow pushes with a long-lived API key stored in the `NUGET_API_KEY` repository secret.
Because the publish step failed, **Add packages to release assets** and **Create PR with version
updates** were skipped. Nothing for 8.0.2 reached nuget.org, the release has no assets, and no
version-update PR exists.

Instead of rotating the key, move to nuget.org **trusted publishing**
(https://learn.microsoft.com/en-gb/nuget/nuget-org/trusted-publishing). GitHub Actions gets a
short-lived OIDC token, `NuGet/login` exchanges it for a nuget.org API key that lasts 1 hour, and
the workflow pushes with that key. No long-lived secret is stored or rotated.

Facts checked while planning:

- All four packages are owned on nuget.org by the user `prjseal`, not an organisation.
- `NuGet/login` latest release is `v1.2.0` (2026-04-24). Its inputs are `user` (required: the
  nuget.org **profile name**, not the email address), plus optional `token-service-url` and
  `audience`. Its output is `NUGET_API_KEY`.
- The job needs `permissions: id-token: write`.
- The `v8.0.2` tag points at `dbd559a` (current `main`). Re-running the failed run would use the
  workflow file from that commit, so it would fail the same way. The release has to be re-triggered
  from a commit that contains the new workflow (see the Release recovery section).

## Manual steps on nuget.org and GitHub (repo owner, not the implementing session)

These need the owner's nuget.org login or create remote state, so the owner does them by hand:

1. **Create the trusted publishing policy** on nuget.org: username menu > **Trusted Publishing** >
   add policy:
   - Owner: `prjseal` (the user that owns all four packages)
   - Repository Owner: `prjseal`
   - Repository: `Clean`
   - Workflow File: `release-nuget.yml` (file name only, without `.github/workflows/`)
   - Environment: leave empty
   - Scopes: allow pushing new versions of the existing packages (`Clean`, `Clean.Core`,
     `Clean.Headless`, `Umbraco.Community.Templates.Clean`)
2. **Add a repository secret** `NUGET_USER` with the nuget.org profile name (`prjseal`):
   `gh secret set NUGET_USER --repo prjseal/Clean`
3. **After the first successful trusted publish**, delete the old secret
   (`gh secret delete NUGET_API_KEY --repo prjseal/Clean`) and the expired key at
   https://www.nuget.org/account/apikeys.

The policy may start as "temporarily active" for 7 days until a publish succeeds and locks it to
the repository. Do the release recovery within that window. The window can be restarted from
nuget.org if it lapses.

## Implementation

1. Work on `feature/nuget-trusted-publishing`, which was cut from a freshly pulled `main` (this
   repo has no `develop`) and holds this plan. Bring it up to date with `main` first:
   `git checkout main`, `git pull`, `git checkout feature/nuget-trusted-publishing`,
   `git rebase main`.

2. **`.github/workflows/release-nuget.yml`**
   - Add `id-token: write` to the job's existing `permissions` block, with a comment that it enables
     GitHub OIDC tokens for nuget.org trusted publishing. Keep `contents: write` and
     `pull-requests: write`.
   - Add a step immediately before **Publish to NuGet.org**. It goes there because the key lasts
     1 hour and `CreateNuGetPackages.ps1` runs Umbraco for several minutes:
     ```yaml
     - name: NuGet login (OIDC trusted publishing)
       id: nuget-login
       uses: NuGet/login@v1
       with:
         user: ${{ secrets.NUGET_USER }}
     ```
   - Change **Publish to NuGet.org** to pass the short-lived key instead of the secret:
     `NUGET_API_KEY: ${{ steps.nuget-login.outputs.NUGET_API_KEY }}`. The call to
     `Publish-ToNuGet.ps1 -ApiKey $env:NUGET_API_KEY` stays as it is.
   - Don't keep a fallback to `secrets.NUGET_API_KEY`. A silent fallback to an expired key would
     hide trusted-publishing misconfiguration.

3. **`.github/workflows/powershell/Publish-ToNuGet.ps1`**
   - Keep the `-ApiKey` parameter and the push loop (including `--skip-duplicate`) as they are.
   - Rewrite the missing-key error and its "how to fix" text: the key comes from the
     `NuGet/login` step. Tell the reader to check the nuget.org trusted publishing policy
     (owner/repo/workflow file `release-nuget.yml`), the `NUGET_USER` secret, and the
     `id-token: write` permission, instead of telling them to create an API key and the
     `NUGET_API_KEY` secret.
   - Update the comment-based help (`.PARAMETER ApiKey`, `.EXAMPLE`) to match.

4. **Docs**: replace the API-key setup with trusted publishing setup, matching the manual steps
   above:
   - `.github/workflow-versioning-releases.md`
     - the "Authentication: Requires NuGet API key" section and its numbered API key / secret setup
       steps (around lines 87-115)
     - the step list mentioning `NUGET_API_KEY` (around line 306)
     - the troubleshooting entry "NUGET_API_KEY secret is not set" (around lines 334-341). Replace
       it with troubleshooting for: login step failing (no matching policy, wrong workflow file
       name, policy inactive after the 7-day window, `NUGET_USER` wrong or set to an email), and
       403 on push (policy scopes don't cover the package).
     - the "API Key Permissions" note (around line 377)
   - `.github/script-publish-to-nuget.md`: the parameter table, the validation step, the example,
     and the "Add NUGET_API_KEY to repository secrets" solution.

5. **`CHANGELOG.md`**: the existing `## [8.0.2] - Unreleased` entry stays. Under `### Changed`,
   add "Release workflow publishes to NuGet.org with trusted publishing (OIDC) instead of a
   long-lived API key".

6. Commit with author `Paul Seal <prjseal@gmail.com>`. Don't push. The owner pushes and opens the
   PR to `main`.

## Release recovery for 8.0.2 (owner, after the PR is merged)

The `v8.0.2` release already exists on `dbd559a`, so it has to be re-triggered from the merge
commit:

1. Make sure the manual nuget.org policy and the `NUGET_USER` secret are in place.
2. Delete the GitHub release and tag `v8.0.2`
   (`gh release delete v8.0.2 --repo prjseal/Clean --cleanup-tag`). Nothing was published to
   nuget.org and the release has no assets, so nothing is lost.
3. Create the `v8.0.2` release again against the new `main` (same notes, not a prerelease). This
   fires `release: published` and runs the updated `release-nuget.yml`.
4. Confirm the run publishes all four packages, uploads release assets, and opens the
   "chore: Update versions to 8.0.2" PR. Then merge that PR.
5. Delete the `NUGET_API_KEY` secret and the expired nuget.org key (manual step 3).

## Verification

- `release-nuget.yml` is valid YAML and the job's `permissions` include `id-token: write`.
  Lint with `actionlint` if available, or check with a YAML parser via Node.
- The publish step reads `steps.nuget-login.outputs.NUGET_API_KEY`, and no workflow under
  `.github/workflows` references `secrets.NUGET_API_KEY` any more
  (`grep -rn NUGET_API_KEY .github/workflows` should only show the env var name passed to
  `Publish-ToNuGet.ps1`).
- `Publish-ToNuGet.ps1` parses: `pwsh -NoProfile -Command "$null = [scriptblock]::Create((Get-Content -Raw .github/workflows/powershell/Publish-ToNuGet.ps1))"`.
  Running it with `-ApiKey ''` prints the new trusted-publishing guidance and exits 1.
- The docs no longer tell anyone to create an API key or the `NUGET_API_KEY` secret.
- End-to-end proof is the release recovery run: the **NuGet login** step succeeds, all four
  `Clean*` 8.0.2 packages appear on nuget.org, and the nuget.org policy shows as active (no longer
  temporary).
