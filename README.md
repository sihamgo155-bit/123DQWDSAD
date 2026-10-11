# CIA COMMAND PORTAL

A responsive, cinematic fictional intelligence-roleplay recruitment portal. This repository includes a working browser-local demo, candidate QCM, application intake and tracking, demo staff console, member/mission/announcement management, settings, and a Supabase schema starter.

> **Fictional project disclaimer:** This is not an official government website and is not affiliated with or endorsed by the U.S. Government or the Central Intelligence Agency.

## Included files

- `index.html` — single-page app shell and all route views.
- `styles.css` — responsive dark/black/red theme, layout, animations, and mobile rules.
- `app.js` — demo application logic, QCM, local records, staff dashboard, review actions, missions, announcements, settings, and member view.
- `config.js` — public client configuration switches only.
- `supabase/schema.sql` — tables, enums, RLS policies, and first-admin bootstrap notes.

## Run the demo locally

1. Extract `cia-command-portal.zip`.
2. Open `index.html` in a modern browser. For best results, serve the folder through a local static server (for example, VS Code Live Server or `python -m http.server 8000`) and visit `http://localhost:8000`.
3. Click **ADMIN ACCESS** and enter the demo code: **1937**.
4. Complete the assessment, pass the threshold, submit an application, then use the staff console to view and approve/reject it.
5. Create demo missions and announcements and change settings in the staff console.

### Demo limitations

- Demo records are stored in the current browser's `localStorage`; they do not sync to another device and may be removed by clearing browser storage.
- The code `1937` is intentionally public and is **not security**. The demo console is only for local testing. Do not deploy it as a real admin login.
- Browser-local demo approval is not a verified identity or secure member session. Do not use this mode for private information.
- The assessment answer key currently exists in `app.js` because this is a local demo. It is inspectable by anyone and must not be used for a real protected exam.
- The form includes a sample age-range field. Adjust it to your community's actual requirements and applicable rules.

## Supabase: important production note

`config.js` defaults to `mode: "demo"`. Although the SQL schema and optional client bootstrap are included, **this starter does not yet provide the complete secure Edge Functions/Auth integration for production writes and exam grading**. Selecting `mode: "supabase"` deliberately does not pretend that submissions, decisions, or authentication are working remotely; it displays a warning instead. Do not represent it as a live multi-device system until you implement and deploy the server-side functions below.

### Create the Supabase project

1. Create a project at [Supabase](https://supabase.com/).
2. Open **SQL Editor**, paste `supabase/schema.sql`, and run it.
3. In **Project Settings → API**, copy the Project URL and public anon/publishable key.
4. Put those values in `config.js` as `supabaseUrl` and `supabaseAnonKey`. These are public-client values; RLS must still be correct. **Never put the `service_role` key in this project or any browser code.**
5. Keep `mode: "demo"` until the production integration described below is implemented and tested.

### Required production server functions before public launch

Deploy Supabase Edge Functions (or an equivalent trusted backend) and have the browser call them. Use authenticated Supabase sessions and verify authorization inside every function; never trust a client-provided user ID or status.

- `submit-application`: verify a signed-in applicant, validate input server-side, load active exam questions and private answer keys, grade on the server, enforce threshold/retake/reapply settings, then insert a `PENDING` application. Return only a reference code and safe receipt fields.
- `review-application`: require `public.is_admin()`/trusted role validation; accept only `APPROVED` or `REJECTED`; update review metadata transactionally and create/update the profile only on approval. Never accept role or admin permissions from the applicant.
- `track-application`: require authentication or a high-entropy private receipt token. Do not use Discord username alone as proof of identity. Return only that applicant's status.
- `manage-missions` and `manage-announcements`: require staff authorization and validate audience/targeting on the server.
- `admin-bootstrap`: do not expose a public bootstrap endpoint. Assign the first admin manually once, then remove/lock down bootstrap access.

For a real production exam, move answer keys out of public client code. Keep `exam_answer_keys` inaccessible to anon/authenticated clients and have grading run in a trusted function. Consider not exposing raw candidate age information to reviewers unless genuinely necessary.

### Create the first administrator safely

1. In Supabase **Authentication → Users**, create your own account and verify it.
2. Copy that user's UUID from the Auth user list.
3. In the SQL Editor, run the one-time statement shown at the bottom of `supabase/schema.sql`, replacing `YOUR-AUTH-USER-UUID` with the verified UUID.
4. Confirm the row in `public.admin_roles`, sign in with Supabase Auth, and verify the staff-only Edge Functions reject ordinary users.
5. Do not add admin-role assignment to any public signup or browser workflow.

### RLS and testing checklist

Before launch, test with separate anonymous, pending-applicant, rejected-applicant, approved-member, and admin accounts:

- Anonymous clients cannot select applications, profiles, internal missions, answer keys, or admin roles.
- Applicants cannot read another applicant's record or set their own application status.
- Pending/rejected users cannot read member-only missions or announcements.
- Approved members cannot change their role, membership status, or admin roles.
- Non-admin users cannot review applications, change settings, or create/update/delete internal missions.
- Admin functions validate the authenticated JWT and role server-side.
- QCM grading and retake limits are enforced on the server, not in browser JavaScript.

**Security review required:** RLS is defense in depth, not a substitute for reviewing the schema and policies against your exact production flow. Test policies in Supabase's policy tester and with real role-separated accounts before collecting real applicant data.

## Free static hosting with GitHub Pages

GitHub Pages can host the static HTML/CSS/JS front end for free. It **cannot run server-side code or Edge Functions**. Supabase Edge Functions run on Supabase, separately from GitHub Pages.

1. Extract the ZIP on your computer.
2. Sign in to GitHub and create a new repository, e.g. `cia-command-portal`.
3. Upload the contents of this folder to the repository root (so `index.html` is at the root).
4. Open repository **Settings → Pages**.
5. Under build/deployment, choose **Deploy from a branch**, select `main` and `/ (root)`, then save.
6. Wait for GitHub Pages to publish. The URL will be shown in the Pages settings (typically `https://YOUR-USERNAME.github.io/cia-command-portal/`).
7. Set up Supabase separately and deploy the required Edge Functions before enabling real submissions or staff controls.
8. Test the site in a private browser window and on a second device. Verify it does not expose protected data when logged out.

## Browser support

Current Chrome, Edge, Firefox, and Safari. The Supabase JS library is loaded from jsDelivr when available; the demo can still run without a working Supabase connection. Google Fonts and the Supabase CDN require internet access for their remote assets.
