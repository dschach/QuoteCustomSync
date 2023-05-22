# UNMANAGED for use with developer edition or playground

echo "Cleaning previous scratch org..."
sf org delete scratch --no-prompt --target-org QuoteSyncOrg

echo "Creating new scratch org"
sf org create scratch --definition-file config/project-scratch-def.json --duration-days 10 --alias QuoteSyncOrg --no-namespace --set-default

echo "Pushing source..."
sf project deploy start --source-dir sfdx-source/QuoteCustomSync

echo "opening org..."
sf org open