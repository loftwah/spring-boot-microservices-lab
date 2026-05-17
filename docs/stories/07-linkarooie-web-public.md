# Story 7: Frontend Public App

## Goal

Build the public React app: home, directory, public profile page, public analytics, login, and signup screens.

## Why

The API becomes easier to reason about when it has a real browser client. This story gives visitors and new users the visible Linkarooie experience.

## Where It Goes

```text
services/linkarooie-web/
  package.json
  bun.lock
  src/
```

## Build Steps

1. Create a Vite React TypeScript app.
2. Add TanStack Router, TanStack Query, Tailwind CSS v4, form tooling, and test tooling.
3. Configure the dev server to proxy `/api` and redirect routes to the Spring Boot API.
4. Build API client helpers from OpenAPI or typed DTOs.
5. Add public layout and theme handling.
6. Add `/directory`.
7. Add `/$username`.
8. Render banner, avatar, name, username, description, bio, social links, tags, links, achievements, and public analytics.
9. Use stable media variant URLs from the API.
10. Add `/analytics` for app-wide public analytics.
11. Add `/login` and `/signup` forms.
12. Add loading, empty, and error states for every route.

## Verification

```bash
cd services/linkarooie-web
bun install
bun run test
bun run dev
```

Open:

```text
http://localhost:3000/directory
http://localhost:3000/loftwah
```

## Tangible Result

- A visitor can browse the directory and open a public profile.
- Public profile UI uses API data rather than local TypeScript profile files.
- Login and signup screens can call the API.

## Test Coverage

- Vitest tests for profile and analytics components.
- Router tests for public route data loading.
- Playwright test for directory to profile navigation.
- Playwright test for signup form validation.
