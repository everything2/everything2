#!/bin/bash
# Update the e2-readonly-query Lambda's *code* (handler.py + pymysql).
#
# The Lambda resource itself (IAM role, SG, VPC config, env vars) lives in
# cf/everything2-production.json. CFN creates it with an inline placeholder.
# This script swaps in the real code via the Lambda API — no S3 round-trip.
#
# Optional env vars:
#   FUNCTION_NAME    default: e2-readonly-query
#   AWS_REGION       default: us-west-2  (matches the production stack)
#   AWS_PROFILE      passes through

set -euo pipefail

FUNCTION_NAME="${FUNCTION_NAME:-e2-readonly-query}"
export AWS_REGION="${AWS_REGION:-us-west-2}"

cd "$(dirname "$0")"

echo "Building deployment package..."
rm -rf build/ function.zip
mkdir -p build/
pip install --quiet --target build/ "pymysql==1.1.0"
cp index.py build/
(cd build && zip -qr ../function.zip .)

SIZE_KB=$(du -k function.zip | cut -f1)
echo "Package: ${SIZE_KB} KB"

echo "Uploading to $FUNCTION_NAME in $AWS_REGION..."
aws lambda update-function-code \
    --function-name "$FUNCTION_NAME" \
    --zip-file fileb://function.zip \
    --no-cli-pager >/dev/null
aws lambda wait function-updated --function-name "$FUNCTION_NAME"

rm -rf build/ function.zip
echo "Done."
echo
echo "Smoke test:"
echo "  aws lambda invoke --function-name $FUNCTION_NAME \\"
echo "    --payload '{\"sql\":\"SELECT 1 AS ok\"}' \\"
echo "    --cli-binary-format raw-in-base64-out /tmp/out.json && cat /tmp/out.json | jq"
