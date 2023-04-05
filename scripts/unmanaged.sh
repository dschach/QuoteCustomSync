# UNMANAGED for use with developer edition or playground

echo "Clearing namespace"
sed -i "" "s|\"namespace\": \"\"|\"namespace\": \"\"|" sfdx-project.json

# For use with developer edition or playground
echo "Pushing source..."
sf deploy metadata

#echo "Assigning Permissions"
#sf org assign permset --name Quote_Sync_Permission

# To install additional sample Accounts/Contacts
# sf data import tree --plan ./data/action-plan-data-plan.json

# To install sample action plan template
echo "Adding sample data"
sf apex run --file ./data/sample-data.apex

echo "opening org..."
sf org open