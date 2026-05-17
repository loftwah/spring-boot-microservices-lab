# Story 8: Frontend Dashboard

## Goal

Build the authenticated dashboard for workspaces, organisations, profile editing, content editing, media editing, and owner analytics.

## Why

The product needs to be manageable by humans, not just through curl. This story turns the API features into a coherent editing workflow.

## Where It Goes

```text
services/linkarooie-web/src/routes/dashboard/
services/linkarooie-web/src/features/workspaces/
services/linkarooie-web/src/features/profiles/
services/linkarooie-web/src/features/media/
services/linkarooie-web/src/features/analytics/
```

## Build Steps

1. Add authenticated route guards backed by `/api/me`.
2. Add dashboard shell with workspace switcher.
3. Add profile list and create profile flow.
4. Add organisation create, settings, and member management screens.
5. Add profile editor for identity, SEO, public visibility, directory visibility, public analytics visibility, theme, and accent color.
6. Add links editor with create, edit, visibility, hidden toggle, delete, and reorder.
7. Add achievements editor with create, edit, visibility, hidden toggle, delete, and reorder.
8. Add tags editor with related work management.
9. Add media editor for avatar and banner upload.
10. Add owner analytics with range selector for 7 days, 30 days, 90 days, and all time.
11. Add save states: saved, saving, unsaved changes, and failed.
12. Add desktop live preview for profile edits.

## Verification

```bash
cd services/linkarooie-web
bun run test
bun run dev
```

Run Playwright:

```bash
cd services/linkarooie-web
bun run test:e2e
```

## Tangible Result

- A signed-in user can create and edit a profile from the browser.
- Personal and organisation workspaces remain visually and behaviourally separate.
- Owner analytics updates after tracked public interactions.

## Test Coverage

- Component tests for editor forms and validation.
- Integration tests for TanStack Query cache invalidation after mutations.
- Playwright test for signup, create profile, add link, publish, view public profile.
- Playwright test for organisation workspace profile creation.
- Playwright test for analytics range selector.
