# Nyaya Content Management Portal

Next.js web portal for editors, legal reviewers and publishers, as set out in `docs/planning/`.
Nothing is built yet.

- Authoring, source metadata, review queues, version comparison, approve/publish/retire.
- CSV/XLSX import with row-level errors; imports only ever create drafts.
- Talks to the backend API only (never to the database), with the same roles and permissions.
- The plan's Admin Portal (users, roles, jobs, reports) can live here as role-gated sections
  rather than a separate app, so there is one content domain and one set of views.
