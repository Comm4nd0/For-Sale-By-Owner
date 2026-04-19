## Summary

<!-- 1-3 bullets describing the change and why -->

## Feature parity

Per `CLAUDE.md`, every user-facing feature must exist on both the Django web app and the Flutter mobile app. Tick one:

- [ ] This change is behind-the-scenes only (infra / deps / refactor / internal API) — no parity concern.
- [ ] This change is user-facing and is implemented on **both** web (`templates/`, `api/views/`) and mobile (`my_app/lib/`).
- [ ] This change is user-facing but only on one platform — linked follow-up issue/PR for the other platform: `#___`.

## Test plan

<!-- How did you verify this works? -->

- [ ] `USE_SQLITE=True python manage.py test api --verbosity=2`
- [ ] `cd my_app && flutter analyze && flutter test`
- [ ] Manual sanity check in a browser / on a device
- [ ] Migration preview (`makemigrations --check --dry-run`) if models changed
- [ ] Version bump in `my_app/pubspec.yaml` if Flutter code changed
