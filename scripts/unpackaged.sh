# UNMANAGED for use with developer edition or playground

echo "Cleaning previous scratch org..."
sf org delete scratch --no-prompt --target-org QuoteSyncOrg

echo "Creating new scratch org"
sf org create scratch --definition-file config/project-scratch-def.json --duration-days 10 --alias QuoteSyncOrg --no-namespace --set-default
# For use with developer edition or playground
echo "Pushing source..."
sf project deploy start --source-dir force-app

echo "opening org..."
sf org open