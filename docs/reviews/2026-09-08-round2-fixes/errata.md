# Round 2 corrections

## CJTUI-047 sampling description

The limitation recorded for CJTUI-047 in the frozen first-round status file says that a complete transaction lock protects shared sampler state. That description is inaccurate.

The implementation uses separate `ProcFsSampler` instances for interactive and background process sampling in `examples/btm_clone/src/main.cj`. Each instance therefore owns its own previous CPU and process baselines. `completionLock` protects only the completed-result slots used to hand background results back to the foreground.

The finding remains `fixed_static_review`. The validation covered the ordinary example flow and did not include a long-running concurrent measurement. This correction supersedes only the inaccurate limitation sentence; the earlier reports and their manifests remain unchanged.
