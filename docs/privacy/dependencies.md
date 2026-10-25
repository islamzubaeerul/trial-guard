# Dependencies

Policy: MIT, Apache-2.0 or BSD licences only; every runtime dependency needs a Privacy review. Prefer writing 50 lines over adding a package.

## Runtime (shipped to users)

None. The TypeScript parser and the Swift package use only the standard library / Foundation.

## Development only (never shipped)

| Package | Why | Licence |
| --- | --- | --- |
| typescript | Type checking | Apache-2.0 |
| vitest | Unit and fixture tests | MIT |
| tsx | Run TypeScript scripts (report, validator) | MIT |
| @types/node | Node types for scripts and tests | MIT |
