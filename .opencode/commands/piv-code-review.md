---
name: piv-code-review
description: Comprehensive code audit (tests, mocks, modularity, security)
arguments: "[path or scope]"
---

# piv-code-review -- Code Audit

Perform a comprehensive code review focused on quality, security, and adherence to
project conventions.

## Scope

If `$ARGUMENTS` specifies a path or scope, focus on that area. Otherwise, review
recent changes (uncommitted + last 5 commits).

## Review Checklist

### 1. Test Quality
- Are integration tests present and mock-free?
- Do unit tests cover edge cases, not just happy paths?
- Is test coverage at 80% or above?
- Are there disabled or skipped tests?

### 2. Mock Discipline
- Mocks ONLY in unit tests (never in integration or E2E)
- No test doubles that hide real behavior
- Integration tests use real dependencies

### 3. Code Quality
- No dead code or unused imports
- Functions are focused and small
- Error handling is explicit (no swallowed errors)
- Naming is clear and consistent

### 4. Security (OWASP Top 10)
- Input validation at boundaries
- No SQL injection vectors
- No XSS vectors
- No hardcoded secrets or credentials
- Proper authentication/authorization checks

### 5. Architecture
- Module boundaries respected
- No circular dependencies
- Clean separation of concerns
- API contracts honored

### 6. Wiring
- All imports resolve
- Routes/endpoints are registered
- New components are connected to the application

## Output

Present findings in a structured report:

```
## Code Review Report

### Critical Issues (must fix)
- [FILE:LINE] <description>

### Warnings (should fix)
- [FILE:LINE] <description>

### Suggestions (nice to have)
- [FILE:LINE] <description>

### Summary
- Files reviewed: N
- Critical issues: N
- Warnings: N
- Test coverage: N%
```

If critical issues are found, recommend creating stories via `@paivot-sr-pm` to track fixes.
