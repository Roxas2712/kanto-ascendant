# KASC 6.7.4: integrated HD download fix and exportable log

Base: public KASC v6.7.3, commit `a8c9654a47fa4e6c114f5997d53c3f78b35db532`.
The downloaded archive matched the published SHA-256:
`9b93265c9590dfb90db86459cbe18859e9ac6507ba86880030cf740939c35371`.

KASC supplies a source-only background worker using its declared `compute`
and `network` permissions. Only the VASC mod's validated catalog/manifest/blob/
receipt routes on the two existing content origins are intercepted. Windows
uses binary pipes within this worker. No engine file or VASC file is replaced.
The minimum engine is the tested public 0.2.57. Other mods and URLs retain their
original transport; per-loader/mod handle ownership and unload are preserved.

On public VASC 3.0.14, explicit retries after error/cancel reset source choice.
The original downloader still verifies hashes, package sizes and activation,
and retains verified chunks. KASC does not patch gameplay or save formats.

The HD menu gains a log-export row. The unique name on every platform is
`KASC-HD-DOWNLOAD-LOG.txt`; the internal previous-attempt file is
`KASC-HD-DOWNLOAD-LOG-VORHER.txt`. Export includes both attempts in one file.
Desktop opens the export folder; mobile invokes the existing create-file
bridge when available. Export is user initiated, with no upload.

Validation completed:

- KASC integration with the unchanged public VASC downloader: both-source
  failure, HTTP diagnosis, recovered-primary retry, verified-chunk resume,
  cross-mod/loader isolation, late replies after cancel, menu insertion,
  ordinary menu actions, and full hook restoration on unload.
- Actual KASC worker with unchanged 0.2.57 HostShell and simulated Windows CRT
  text mode: the real 812803-byte hosted PNG is preserved exactly by binary
  mode. POSIX retains `r`; unapproved origins fail.
- Bounded 80-event / 32-KiB logs, rotation, redaction, nonfatal write failure,
  fixed export names, encoded Windows folder URL, mobile picker contract,
  and failed export.
- Native macOS LÖVE run using the sandbox's declared permissions, actual
  Thread/Channel and unchanged HostShell: both live origins delivered the
  812803-byte PNG with SHA-256
  `2655878e2e53ff544b6b1dcd00a110c5b52b5c01e1260dab3b8fe7fb7e07c9d0`.
- Full artifact audit: only `entry.lua` and `manifest.json` changed among all
  original 102364 entries. Four Lua helpers and one help document were added.
  Every other original entry remained byte-identical; no duplicate ZIP paths.

No physical Windows, Android or iOS end-to-end test is claimed. No public
release has been uploaded by this task. The complete ZIP and local tests are
in `output/kasc-hd-download-20260909` in the shared workspace.
