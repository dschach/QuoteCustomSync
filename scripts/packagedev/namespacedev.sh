npm run x2oddevhub

echo "Cleaning previous scratch org..."
sf org delete scratch --no-prompt --target-org QuoteSyncOrg

echo "Using namespace"
sed -i "" "s|\"namespace\": \"\"|\"namespace\": \"x2od_qcs\"|" sfdx-project.json

echo "Creating new scratch org"
sf org create scratch --definition-file config/project-scratch-def.json --alias QuoteSyncOrg --set-default --no-ancestors --duration-days 21

# For use with namespaced scratch org in package development process
echo "Pushing managed metadata"
sf deploy metadata  --source-dir force-app

#echo "Assigning permission set"
#sf org assign permset --name Quote_Sync_Permission

# To install sample action plan template
echo "Loading sample data"
sf apex run --file ./data/sample-data.apex
#sf apex run --apex-code-file "data/sample-data.apex" —-target-org QuoteSyncOrg

echo "Clearing namespace"
sed -i "" "s|\"namespace\": \"x2od_qcs\"|\"namespace\": \"\"|" sfdx-project.json

echo "opening org"
sf org open --target-org QuoteSyncOrg