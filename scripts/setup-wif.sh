#!/usr/bin/env bash
#
# Workload Identity Federation (WIF) bootstrap for GitHub Actions → GCP.
#
# Run ONCE per project. Requires you to be authenticated as a GCP user
# with roles/owner or equivalent on the target project.
#
# Result: a Workload Identity Pool + GitHub OIDC provider + service account
# that GitHub Actions can impersonate without storing static JSON keys.
#
# Outputs at the end:
#   - GCP_WIF_PROVIDER  (paste into GitHub repo Secrets)
#   - GCP_SA_EMAIL      (paste into GitHub repo Secrets)
#
# Usage:
#   ./scripts/setup-wif.sh
#
# Re-running this script is safe: every gcloud step is idempotent
# (uses `describe || create` pattern).

set -euo pipefail

# ─────────────────────────── Config ───────────────────────────
PROJECT_ID="${GCP_PROJECT_ID:-anmates-studio}"
GITHUB_ORG="${GITHUB_ORG:-AnMatesStudio}"
GITHUB_REPO="${GITHUB_REPO:-AnMates}"
POOL_ID="github-pool"
PROVIDER_ID="github-provider"
SA_NAME="github-actions"
SA_DISPLAY_NAME="GitHub Actions deployer"

# ───────────────────────── Helpers ────────────────────────────
log()  { printf "\033[1;34m▶\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m✓\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m!\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m✗\033[0m %s\n" "$*" >&2; }

# ───────────────── Sanity checks ─────────────────────
log "Checking gcloud auth + project access..."
ACTIVE_ACCT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" || true)
if [[ -z "$ACTIVE_ACCT" ]]; then
  err "No active gcloud account. Run: gcloud auth login"
  exit 1
fi
ok "Authenticated as: $ACTIVE_ACCT"

gcloud config set project "$PROJECT_ID" >/dev/null
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
ok "Project: $PROJECT_ID (number: $PROJECT_NUMBER)"

# ───────────────── Enable required APIs ─────────────────────
log "Enabling required APIs (idempotent)..."
gcloud services enable \
  iamcredentials.googleapis.com \
  iam.googleapis.com \
  cloudresourcemanager.googleapis.com \
  sts.googleapis.com \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  --quiet
# cloudbuild.googleapis.com intentionally NOT enabled — images are built on
# the GitHub runner (docker build/push), not Cloud Build. See cd.go-api.yml.
ok "APIs enabled"

# ───────────────── Workload Identity Pool ─────────────────────
log "Creating Workload Identity Pool '$POOL_ID'..."
if gcloud iam workload-identity-pools describe "$POOL_ID" --location=global &>/dev/null; then
  warn "Pool already exists, skipping create"
else
  gcloud iam workload-identity-pools create "$POOL_ID" \
    --location=global \
    --display-name="GitHub Actions pool" \
    --quiet
  ok "Pool created"
fi

POOL_NAME="projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_ID"

# ───────────────── OIDC Provider ─────────────────────
log "Creating OIDC provider '$PROVIDER_ID'..."
if gcloud iam workload-identity-pools providers describe "$PROVIDER_ID" \
    --location=global --workload-identity-pool="$POOL_ID" &>/dev/null; then
  warn "Provider already exists, skipping create"
else
  gcloud iam workload-identity-pools providers create-oidc "$PROVIDER_ID" \
    --location=global \
    --workload-identity-pool="$POOL_ID" \
    --display-name="GitHub OIDC" \
    --issuer-uri="https://token.actions.githubusercontent.com" \
    --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner,attribute.ref=assertion.ref" \
    --attribute-condition="assertion.repository=='$GITHUB_ORG/$GITHUB_REPO'" \
    --quiet
  ok "Provider created"
fi

PROVIDER_NAME="$POOL_NAME/providers/$PROVIDER_ID"

# ───────────────── Service Account ─────────────────────
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
log "Creating service account '$SA_EMAIL'..."
if gcloud iam service-accounts describe "$SA_EMAIL" &>/dev/null; then
  warn "Service account already exists, skipping create"
else
  gcloud iam service-accounts create "$SA_NAME" \
    --display-name="$SA_DISPLAY_NAME" \
    --quiet
  ok "Service account created"
fi

# ───────────────── Allow GitHub repo to impersonate SA ─────────────────────
log "Binding GitHub repo '$GITHUB_ORG/$GITHUB_REPO' → service account..."
gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/$POOL_NAME/attribute.repository/$GITHUB_ORG/$GITHUB_REPO" \
  --quiet >/dev/null
ok "Impersonation binding set"

# ───────────────── Grant minimum roles to SA ─────────────────────
log "Granting deploy roles to service account..."
ROLES=(
  "roles/run.admin"                          # deploy/update Cloud Run services
  "roles/artifactregistry.writer"            # push Docker images (docker push to AR)
  "roles/iam.serviceAccountUser"             # actAs Cloud Run runtime SA
  "roles/firebasehosting.admin"              # Firebase Hosting deploy
  "roles/firebase.viewer"                    # required by firebase-tools auth
  "roles/serviceusage.serviceUsageConsumer"  # firebase-tools API enablement
  # NOTE: cloudbuild.builds.editor + storage.admin removed — we build images
  # on the GitHub runner with `docker build/push`, not `gcloud builds submit`.
  # See .github/workflows/cd.go-api.yml "Build + push image" step for why.
)
for role in "${ROLES[@]}"; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SA_EMAIL" \
    --role="$role" \
    --condition=None \
    --quiet >/dev/null
  ok "Granted $role"
done

# ───────────────── Output GitHub Secrets ─────────────────────
echo
echo "═══════════════════════════════════════════════════════════════════════"
echo " WIF setup complete. Add these to GitHub repo Secrets:"
echo "   Settings → Secrets and variables → Actions → New repository secret"
echo "═══════════════════════════════════════════════════════════════════════"
echo
echo "Secret name:  GCP_WIF_PROVIDER"
echo "Secret value: $PROVIDER_NAME"
echo
echo "Secret name:  GCP_SA_EMAIL"
echo "Secret value: $SA_EMAIL"
echo
echo "Also add these app secrets (for cd-go.yml):"
echo "  DATABASE_URL          (Supabase connection string)"
echo "  JWT_SECRET            (min 32 chars)"
echo "  FIREBASE_WEB_API_KEY  (from Firebase Console)"
echo
echo "═══════════════════════════════════════════════════════════════════════"
