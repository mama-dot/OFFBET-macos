# CI signing — how to add the secrets (once the Apple account is validated)

The `.github/workflows/release.yml` workflow builds + signs + notarizes the
installer `.pkg` on a `macos-14` runner and uploads it. It needs **6 repo secrets**
(GitHub → repo → Settings → Secrets and variables → Actions → New repository secret).

## 1. The two Developer ID certificates → `.p12`

On a Mac where the certs are installed (Keychain Access), export each as `.p12`
(right-click the cert → Export → Personal Information Exchange `.p12`, set a password):

- **Developer ID Application** → `app.p12`
- **Developer ID Installer** → `inst.p12`

Use the **same export password** for both, then base64 them:

```bash
base64 -i app.p12  | pbcopy   # → paste into secret APP_CERT_P12_BASE64
base64 -i inst.p12 | pbcopy   # → paste into secret INSTALLER_CERT_P12_BASE64
```

Secrets:
- `APP_CERT_P12_BASE64`
- `INSTALLER_CERT_P12_BASE64`
- `CERT_PASSWORD` — the export password

## 2. App Store Connect API key (for notarization)

appstoreconnect.apple.com → Users and Access → **Integrations / Keys** → generate an
API key with the **Developer** role. Download the `AuthKey_XXXX.p8` (once only).

```bash
base64 -i AuthKey_XXXX.p8 | pbcopy   # → NOTARY_KEY_BASE64
```

Secrets:
- `NOTARY_KEY_BASE64` — base64 of the `.p8`
- `NOTARY_KEY_ID` — the Key ID (shown next to the key)
- `NOTARY_ISSUER_ID` — the Issuer ID (UUID, top of the Keys page)

## 3. Ship

```bash
git tag v0.1.0 && git push origin v0.1.0
```

The workflow runs → download the **OFFBET-Installer-pkg** artifact from the run
(signed + notarized, ready to distribute from offbet.app).

> Nothing else is needed — the whole build/sign/notarize path is scripted. Until
> the secrets exist, the workflow fails only at the cert-import step (expected).
