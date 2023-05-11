npm run x2oddevhub

echo "set managed package"
sed -i "" "s|\"namespace\": \"\"|\"namespace\": \"\"|" sfdx-project.json

sf package version create --code-coverage --package QuoteCustomSync_Managed --path force-app --installation-key-bypass --wait 20

echo "unset namespace"
sed -i "" "s|\"namespace\": \"\"|\"namespace\": \"\"|" sfdx-project.json