# ZumiTok — GitHub Pages (support & privacy)

Static pages for **App Store Connect** and **Google Play** URLs.

## Enable GitHub Pages

1. On GitHub, open the repository that contains this `docs/` folder.
2. **Settings → Pages**
3. Under **Build and deployment**, set **Source** to **Deploy from a branch**.
4. Choose branch **`main`** (or your default branch) and folder **`/docs`**, then **Save**.

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
