# ZumiTok — GitHub Pages (support & privacy)

Static pages for **App Store Connect** and **Google Play** URLs.

## Fix “404 — There isn’t a GitHub Pages site here”

Your files on `main` are **not enough** until GitHub is told **how** to publish them.

### Option A — GitHub Actions (recommended; repo includes a workflow)

1. GitHub → **Settings → Pages**
2. **Build and deployment** → **Source** → choose **GitHub Actions** (not “Deploy from a branch”).
3. Push or merge so `.github/workflows/deploy-github-pages.yml` runs (or **Actions** tab → **Deploy GitHub Pages** → **Run workflow**).
4. Wait for the workflow to finish (green check). The job shows the **Page URL**.
5. Open: `https://<user>.github.io/<repo>/privacy.html`

If you do not see **“GitHub Actions”** under Source, update the workflow file from the GitHub “Pages” settings **suggested workflow** once, or use Option B.

### Option B — Deploy from branch

1. **Settings → Pages**
2. **Source** → **Deploy from a branch**
3. Branch **`main`**, folder **`/docs`**, **Save**
4. Wait 1–5 minutes, hard-refresh the page.

---

## Site URL (after it works)

After the first deploy (usually within a few minutes), the site base URL will be:

`https://<your-username>.github.io/<repository-name>/`

## URLs to paste in the stores

Replace `<your-username>` and `<repository-name>` with your GitHub values (example: `ilshapiro60` and `bagels-party`):

| Field | URL |
|--------|-----|
| **Support URL** | `https://<your-username>.github.io/<repository-name>/support.html` |
| **Privacy policy URL** | `https://<your-username>.github.io/<repository-name>/privacy.html` |

Optional landing: `https://<your-username>.github.io/<repository-name>/` (you can add `index.html` later).

## Before launch

- Replace **`support@zumitok.app`** in `support.html` and `privacy.html` with a working inbox (or your personal support email).
- Update **“Who we are”** / operator name in `privacy.html` if a company name is required.
- Align **Service providers** with the exact SDKs you ship (Stripe, AdMob, etc.).
