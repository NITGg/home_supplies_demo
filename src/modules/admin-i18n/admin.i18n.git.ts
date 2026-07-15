import { execFile } from "node:child_process";
import path from "node:path";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

/**
 * Best-effort: commit + push the given locale files to the current branch so
 * edits made through the admin i18n dashboard survive the next deploy
 * (`update.sh` does `git pull` then `npm run build`, which would otherwise
 * overwrite these files back to whatever's in git).
 *
 * Failures (no git repo, network down, diverged branch, etc.) are logged and
 * swallowed — the translation save itself must not fail because of this.
 */
export async function commitAndPushLocaleFiles(
  filePaths: string[],
  message: string,
): Promise<void> {
  const cwd = process.cwd();
  const relPaths = filePaths.map((p) => path.relative(cwd, p));
  console.log("cwd:", process.cwd());

  try {
    await execFileAsync("git", ["add", ...relPaths], { cwd });

    const { stdout: staged } = await execFileAsync(
      "git",
      ["diff", "--cached", "--name-only", "--", ...relPaths],
      { cwd },
    );
    if (!staged.trim()) return; // nothing actually changed

    await execFileAsync("git", ["commit", "-m", message], { cwd });

    // `rev-parse --abbrev-ref HEAD` can return an ambiguous "heads/<branch>"
    // when a remote happens to share the branch's name — use `symbolic-ref`
    // for a clean branch name instead.
    const { stdout: branchOut } = await execFileAsync(
      "git",
      ["symbolic-ref", "--short", "HEAD"],
      { cwd },
    );
    const branch = branchOut.trim();

    // The remote isn't always "origin" (e.g. this repo's remote is "adminAPIs");
    // use the branch's configured upstream remote, falling back to "origin".
    let remote = "origin";
    try {
      const { stdout: remoteOut } = await execFileAsync(
        "git",
        ["config", "--get", `branch.${branch}.remote`],
        { cwd },
      );
      if (remoteOut.trim()) remote = remoteOut.trim();
    } catch {
      // no upstream configured — fall back to "origin"
    }

    try {
      await execFileAsync("git", ["push", remote, branch], { cwd });
    } catch {
      // Remote has commits we don't have ("fetch first"). Rebase our single
      // locale commit onto the remote tip and retry once. If that conflicts,
      // abort the rebase to leave the working tree clean — the local commit
      // stays unpushed and will be retried/resolved on the next sync.
      await execFileAsync("git", ["fetch", remote, branch], { cwd });
      try {
        await execFileAsync("git", ["rebase", `${remote}/${branch}`], { cwd });
      } catch (rebaseErr) {
        await execFileAsync("git", ["rebase", "--abort"], { cwd }).catch(() => {});
        throw rebaseErr;
      }
      await execFileAsync("git", ["push", remote, branch], { cwd });
    }
  } catch (err) {
    console.error("[admin-i18n] git sync of locale files failed:", err);
  }
}
