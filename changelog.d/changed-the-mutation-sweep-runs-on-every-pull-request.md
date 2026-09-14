- **The mutation sweep runs on every pull request instead of once a week.** It breaks the game on
  purpose one constant at a time and reports which breakages no check notices — and it was kept off
  pull requests because it "takes the better part of half an hour". That figure was never measured.
  Its last sweep finished in **seven minutes nineteen**, which is about what the checks it audits
  cost, because it runs each of them once and stops at the first that fails.
  - Weekly is not a cadence this repository has. That green sweep ran on a Sunday morning against a
    twenty-six line table; ninety-one commits landed in the day after it, ten of them appending to
    the table, and by the Monday three entries named constants that had been renamed, moved or
    deleted. A guard that goes quiet is now caught by the change that quietened it.
  - `.github/workflows/mutation.yml` is gone and the job lives in `ci.yml`, behind the same CI gate
    as every other job, so a survivor blocks a merge rather than sending a mail on Sunday.
