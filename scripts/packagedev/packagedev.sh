npm run x2oddevhub

echo "Cleaning previous scratch org..."
sf org delete scratch --no-prompt --target-org QuoteSyncOrg

echo "Clearing namespace"
sed -i "" "s|\"namespace\": \"x2od_qcs\"|\"namespace\": \"\"|" sfdx-project.json

echo "Creating new scratch org"
sf org create scratch --definition-file config/project-scratch-def.json --alias QuoteSyncOrg --set-default --no-ancestors --duration-days 21

# For use with non-namespaced scratch org in package development process
echo "Pushing managed metadata"
sf project deploy start --source-dir sfdx-source/QuoteCustomSync
sf project deploy start --source-dir sfdx-source/unpackaged

#echo "Assigning permission set"
sf org assign permset --name QuoteSyncTester

# To install sample data
echo "Loading sample data"
sf data import tree --plan ./data/data-plan.json

echo "opening org"
sf org open --target-org QuoteSyncOrg