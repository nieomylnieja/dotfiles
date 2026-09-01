# Persist an accepted demo

The persistent source repository is
[nieomylnieja/giffs](https://github.com/nieomylnieja/giffs).

Ask one scoped question after the user accepts the GIF:

> Do you want me to persist `<slug>.tape` and `<slug>.gif` as
> `giffs/<slug>/` in `nieomylnieja/giffs` and commit and push it directly to
> `main`?

Do not modify that repository unless the user answers yes. That answer
authorizes only the new-folder commit described in the question.

After confirmation:

1. Use a clean, current `main` checkout whose upstream is `origin/main`.
   Stop on a dirty tree, divergence, authentication failure, or network failure.
2. Choose a unique kebab-case path under `giffs/`. Stop if that path exists.
3. Copy the accepted tape and verified GIF into the new folder. Keep required
   fixtures in the same folder.
4. Verify that every working-tree and staged change is a new path in that
   folder.
5. Follow the Git Commit skill. Commit only the new folder with
   `feat: add <slug> terminal demo`.
6. Push `main` normally. Never force-push. Stop if the remote moved.
7. Report the folder URL and commit hash. Report exact failures and leave
   unrelated paths unchanged.
