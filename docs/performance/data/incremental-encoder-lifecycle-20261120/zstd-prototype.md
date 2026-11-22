Temporary prospective next-frame borrow prototype

The repository src files remain byte-identical to frozen-source.json. All changes are confined to this directory. prospective-next-frame.patch contains the six reviewable file changes.

Frozen-source before run: 25 passed, 2 failed. Serial returned success after writing its newly configured memory profile, which was also the new raw prefix. Parallel changed the detached old profile limit from 64 MiB to 65 MiB before saving those limit bytes as the new raw prefix. See before.log.

Prospective admission registers the next options observers and the selected next dictionary, including content, standard_bytes and prepared state. It validates all receiver/control/buffer capacities without registering the ended frame external dictionary. Pending prefixes retained into the next frame are still registered as next reads.

Serial exclusive leases replace their profile binding before configure reports, so a detached old observer can become the next prefix in one transition. Shared leases still inherit their external owner observer; that live write span remains protected.

Parallel completed-frame observations are already published by the final step. nextFrame no longer publishes old options before validation, on rejection, or after changing the budget. It publishes only after committing the next options. This preserves detached old profile bytes while allowing one-transition old observer to new prefix reuse. Owned-state checking is separated from the old dictionary binding so an ended prefix can become a new observer.

After narrow run: all 27 tests passed. Both nextFrameWithPresetDictionary and nextFrameExactSizeWithPresetDictionary reject simultaneous future profile/prefix aliases without receiver/caller/profile byte changes. Disjoint retries complete. Serial and parallel old observer to new prefix and ended prefix to new observer reuse complete. Parallel adjacent suite: all 73 tests passed. Incremental adjacent suite: all 91 tests passed. zig fmt --check passed for all six files.

This bounded prototype does not add new metadata validation timing or redesign generic OOM rollback. Prefix metadata validation retains its existing lazy behavior. The exact core alias-rejection paths are checked for byte-level atomicity. No repo production, test, build or docs file was edited, and no commit was created.

Native debug command used (filters differ per log):
zig test /home/passchaos/project-z/vort/.zig-cache/o/d5037e170b7cab0e7d7bdc7c26ae6ce6/vort-zstd-huffman-x2.o -ODebug -Mroot=/tmp/vort-zstd-next-frame-borrows-isolated-20261120/src/zstd.zig --test-filter 'Zstd incremental next-frame borrow' --cache-dir /tmp/vort-zstd-next-frame-borrows-isolated-20261120/.zig-cache
