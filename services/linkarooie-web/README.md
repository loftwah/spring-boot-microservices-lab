# linkarooie-web

React service for public Linkarooie pages and the authenticated dashboard.

## Runtime

- Bun for local development commands.
- Node.js LTS in container images.
- Vite.
- React.
- TanStack Router.
- TanStack Query.
- Tailwind CSS v4.

## Owns

- Public home.
- Directory.
- Public profile page.
- Public analytics page.
- Signup and login screens.
- Dashboard shell.
- Workspace switcher.
- Organisation management screens.
- Profile, content, media, and analytics editors.

## Does Not Own

- Auth token storage.
- Analytics aggregation.
- Media processing.
- RustFS/S3 credentials.

The web service uses API routes and HTTP-only cookies.

## First Useful Build

1. Create the Vite React app.
2. Add router and query client.
3. Add `/directory` and `/$username`.
4. Read from the API.
5. Render the seeded `loftwah` profile.

## Verification

```bash
cd services/linkarooie-web
bun install
bun run test
bun run dev
```

Expected local URL:

```text
http://localhost:3000
```
