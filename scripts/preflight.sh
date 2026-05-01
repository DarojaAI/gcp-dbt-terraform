#!/bin/bash
# =============================================================================
# preflight.sh — Consumer-side gcloud validation before terraform apply
# =============================================================================
# Validates that required GCP resources exist and are properly configured
# before running terraform apply in a consuming project.
#
# Usage:
#   bash scripts/preflight.sh --project <PROJECT> --region <REGION> \
#                             --secret <SECRET_REF> --subnet <SUBNET> \
#                             --wif-sa <WIF_SA_EMAIL>
#
# Prerequisites:
#   - gcloud CLI installed and authenticated
#   - Sufficient permissions to check APIs, secrets, VPC, and IAM
#
# Exit codes:
#   0 = All checks passed
#   1 = Arg parsing error or gcloud not found
#   2 = Required API not enabled
#   3 = Referenced resource does not exist
#   4 = Region mismatch or IAM configuration issue
# =============================================================================

set -e

# =============================================================================
# Arg parsing
# =============================================================================

PROJECT=""
REGION=""
SECRET=""
SUBNET=""
WIF_SA=""

usage() {
    echo "Usage: $0 --project <PROJECT> --region <REGION> --secret <SECRET> --subnet <SUBNET> --wif-sa <WIF_SA>"
    echo ""
    echo "Arguments:"
    echo "  --project   GCP project ID (required)"
    echo "  --region    GCP region for Cloud Run (required)"
    echo "  --secret    Secret Manager reference (projects/X/secrets/Y/versions/Z) (required)"
    echo "  --subnet    Subnet self-link (required)"
    echo "  --wif-sa    Workload Identity Federation service account email (required)"
    echo ""
    echo "Example:"
    echo "  $0 \\"
    echo "    --project my-project \\"
    echo "    --region us-central1 \\"
    echo "    --secret projects/my-project/secrets/db-password/versions/latest \\"
    echo "    --subnet https://www.googleapis.com/compute/v1/projects/my-project/regions/us-central1/subnetworks/private \\"
    echo "    --wif-sa my-project@my-project.iam.gserviceaccount.com"
    exit 1
}

if [ $# -eq 0 ]; then
    usage
fi

while [ $# -gt 0 ]; do
    case "$1" in
        --project)
            PROJECT="$2"
            shift 2
            ;;
        --region)
            REGION="$2"
            shift 2
            ;;
        --secret)
            SECRET="$2"
            shift 2
            ;;
        --subnet)
            SUBNET="$2"
            shift 2
            ;;
        --wif-sa)
            WIF_SA="$2"
            shift 2
            ;;
        --help|-h)
            usage
            ;;
        *)
            echo "Error: Unknown argument: $1"
            usage
            ;;
    esac
done

# Validate required args
if [ -z "$PROJECT" ] || [ -z "$REGION" ] || [ -z "$SECRET" ] || [ -z "$SUBNET" ] || [ -z "$WIF_SA" ]; then
    echo "Error: Missing required arguments"
    usage
fi

# Check gcloud is available
if ! command -v gcloud &> /dev/null; then
    echo "Error: gcloud CLI not found. Please install Google Cloud SDK."
    exit 1
fi

echo "Starting preflight validation..."
echo "  Project:  $PROJECT"
echo "  Region:   $REGION"
echo "  Secret:   $SECRET"
echo "  Subnet:   $SUBNET"
echo "  WIF SA:   $WIF_SA"
echo ""

# =============================================================================
# Check 1: Required APIs are enabled
# =============================================================================
echo "=== Check 1: Required APIs ==="

REQUIRED_APIS=(run.googleapis.com secretmanager.googleapis.com compute.googleapis.com iam.googleapis.com)
ENABLED=$(gcloud services list --enabled --project="$PROJECT" --format="value(config.name)" 2>/dev/null)

MISSING_APIS=""
for api in "${REQUIRED_APIS[@]}"; do
    if ! echo "$ENABLED" | grep -q "^${api}$"; then
        MISSING_APIS="$MISSING_APIS $api"
    fi
done

if [ -n "$MISSING_APIS" ]; then
    echo "Error: Missing required APIs:$MISSING_APIS"
    echo "Enable with: gcloud services enable ${REQUIRED_APIS[*]} --project=$PROJECT"
    exit 2
fi

echo "All required APIs enabled"
echo ""

# =============================================================================
# Check 2: Secret reference format and resolution
# =============================================================================
echo "=== Check 2: Secret Manager secret ==="

# Validate format: projects/X/secrets/Y or projects/X/secrets/Y/versions/Z
if ! echo "$SECRET" | grep -qE "^projects/[^/]+/secrets/[^/]+(/versions/[^/]+)?$"; then
    echo "Error: Invalid secret format: $SECRET"
    echo "Expected: projects/PROJECT/secrets/SECRET or projects/PROJECT/secrets/SECRET/versions/VERSION"
    exit 3
fi

# Extract secret name (handle both with and without version)
SECRET_NAME=$(echo "$SECRET" | sed -E 's|projects/[^/]+/secrets/([^/]+)(/versions/.*)?|\1|')

if gcloud secrets describe "$SECRET_NAME" --project="$PROJECT" > /dev/null 2>&1; then
    echo "Secret exists: $SECRET_NAME"
else
    echo "Error: Secret does not exist: $SECRET_NAME"
    exit 3
fi

echo ""

# =============================================================================
# Check 3: Subnet exists and region matches
# =============================================================================
echo "=== Check 3: VPC Subnet ==="

# Validate subnet self-link format
if ! echo "$SUBNET" | grep -qE "https://www.googleapis.com/compute/v1/projects/[^/]+/regions/[^/]+/subnetworks/[^/]+"; then
    echo "Error: Invalid subnet self-link format: $SUBNET"
    echo "Expected: https://www.googleapis.com/compute/v1/projects/PROJECT/regions/REGION/subnetworks/NAME"
    exit 3
fi

# Extract region from subnet self-link
SUBNET_REGION=$(echo "$SUBNET" | sed -E 's|.*/regions/([^/]+)/subnetworks/.*|\1|')

if [ "$SUBNET_REGION" != "$REGION" ]; then
    echo "Error: Region mismatch"
    echo "  Subnet region:  $SUBNET_REGION"
    echo "  Target region:  $REGION"
    exit 4
fi

echo "Subnet region matches: $REGION"

# Extract project and subnet name from self-link
SUBNET_PROJECT=$(echo "$SUBNET" | sed -E 's|https://www.googleapis.com/compute/v1/projects/([^/]+)/.*|\1|')
SUBNET_NAME=$(echo "$SUBNET" | sed -E 's|.*/subnetworks/([^/]+)$|\1|')

if gcloud compute networks subnets describe "$SUBNET_NAME" --region="$REGION" --project="$SUBNET_PROJECT" > /dev/null 2>&1; then
    echo "Subnet exists: $SUBNET_NAME"
else
    echo "Error: Subnet does not exist: $SUBNET_NAME (region: $REGION, project: $SUBNET_PROJECT)"
    exit 3
fi

echo ""

# =============================================================================
# Check 4: WIF service account exists
# =============================================================================
echo "=== Check 4: Workload Identity Service Account ==="

if gcloud iam service-accounts describe "$WIF_SA" --project="$PROJECT" > /dev/null 2>&1; then
    echo "Service account exists: $WIF_SA"
else
    echo "Error: Service account does not exist: $WIF_SA"
    exit 3
fi

echo ""

# =============================================================================
# Summary
# =============================================================================
echo "=================================="
echo "All preflight checks passed."
echo "Safe to run: terraform apply"
echo "=================================="

exit 0
