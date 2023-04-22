#!/bin/sh

# Run this BEFORE running ApexDox so all your files are set up properly.

#curl -L "https://raw.githubusercontent.com/dschach/salesforce-trigger-framework/main/README.md" -o "doc-assets/files/triggerHandlerReadMe.md"
#npx marked -i doc-assets/files/triggerHandlerReadMe.md --gfm > "doc-assets/files/TriggerHandlerHome.html"
#printf '<link href="assets/styling.css" rel="stylesheet" />' >> "doc-assets/files/TriggerHandlerHome.html"
#rm doc-assets/files/triggerHandlerReadMe.md

#curl -L "https://raw.githubusercontent.com/dschach/record-types/main/doc-assets/RecordTypesHome.html" -o "doc-assets/files/RecordTypesHome.html"
#printf '<link href="assets/styling.css" rel="stylesheet" />'  >> "doc-assets/files/RecordTypesHome.html"

# npx marked -i doc-assets/files/TestDataFactoryReadMe.md --gfm > "doc-assets/files/TestDataFactoryReadMe.html"
# printf '<link href="assets/styling.css" rel="stylesheet" />'  >> "doc-assets/files/TestDataFactoryReadMe.html"

# npx marked -i doc-assets/main.md --gfm > "doc-assets/main.html"

printf '<link href="assets/styling.css" rel="stylesheet" />' > "doc-assets/main.html"
echo >> "doc-assets/main.html"
npx marked -i README.md --gfm >> "doc-assets/main.html"

printf '<link href="assets/styling.css" rel="stylesheet" />' > "doc-assets/files/changelog.html"
echo >> "doc-assets/files/changelog.html"
npx marked -i CHANGELOG.md --gfm >> "doc-assets/files/changelog.html"
sed -i "" "s|CHANGELOG.md|assets/changelog.html|" "doc-assets/main.html"

npm run updateHighlight