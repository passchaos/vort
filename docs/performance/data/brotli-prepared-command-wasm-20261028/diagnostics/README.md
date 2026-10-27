# Earlier probe epochs

These logs diagnose fixture development. They are excluded from the successful
64 KiB epoch, its source archives, and its witness counts.

| Epoch | Size | Outcome |
| --- | ---: | --- |
| initial-key-fixture-error | 8 KiB | Compilation exited 1: inferred anonymous Options contained comptime fields. No fixture executed. |
| first-fixture-no-recent | 8 KiB | Probe status 5 / process exit 1. Native output had 178 commands and zero recent copies; execution stopped before complex/shared checks. |
| 8192-below-recent-gate | 8 KiB | Probe status 12 / process exit 1. Native output had 162 commands, 40 command entries, one complex tree, 15 recent copies and zero eligible shared groups. |

The exact source snapshots for these three epochs were not retained. Only their
original diagnostic logs remain, labelled in `epochs.json`. The successful
source snapshot uses concrete runtime Key options and a 64 KiB fixture; its
separate logs show status 0, 1,299 commands and two eligible candidate groups.
