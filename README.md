[![On Push](https://github.com/dschach/QuoteCustomSync/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/dschach/QuoteCustomSync/actions/workflows/ci.yml)
[![PR Validation](https://github.com/dschach/QuoteCustomSync/actions/workflows/pr.yml/badge.svg?branch=main)](https://github.com/dschach/QuoteCustomSync/actions/workflows/pr.yml)
[![Release Workflow](https://github.com/dschach/QuoteCustomSync/actions/workflows/release-please.yml/badge.svg?branch=main)](https://github.com/dschach/QuoteCustomSync/actions/workflows/release-please.yml)
[![codecov](https://codecov.io/gh/dschach/QuoteCustomSync/branch/main/graph/badge.svg?token=H2ZFLBGGZR)](https://codecov.io/gh/dschach/QuoteCustomSync)

# Custom Quote Sync

Metadata-driven Quote-Opportunity custom field synchronization

(based on Salesforce Labs [Custom Quote Sync](https://appexchange.salesforce.com/listingDetail?listingId=a0N30000003Iop5EAC))

## [Changelog](./CHANGELOG.md)

## [Installation Instructions](./INSTALLATION.md)

## General Description

This app allows you to configure custom fields mapping between Opportunity and Quote, and custom fields on OpportunityLineItem and QuoteLineItem. The mapped fields will be synchronized automatically similar to the standard Quote Sync process.

## What's Included

This package comes with some code to sync custom fields between Opportunities and Quotes (and their Line Items), but it needs to know which fields to map between the proper objects.

This is achieved via Custom Metadata Types. Indicate the Opportunity and Quote (or Line Item) field names on the correct CMT and the package will do the rest.

## Configuration

### What Salesforce syncs automatically

#### Opportunity-Quote

Some fields do not need to be specified, as Salesforce will synchronize those values automatically between the Opportunity and the syncing Quote. These are the standard fields:

- Price Book

Yes, there is only one field that is synchronized, and all of this assumes that there are line items on the Opportunity or the Quote. If there are no line items, the Opportunity Amount does NOT synchronize with the Quote.GrandTotal field!

There are some Opportunity and Quote fields that do not "line up" with each other. For example, there may be a Tax field on Quote, but there is not one on Opportunity. For these fields, they may be included in syncing configuration, but there could be errors if one of the fields cannot be written to (such a a formula field). This functionality to check that may be released in a future version (SAFE HARBOR).

### Custom Metadata Types

Two CMTs are included: `Quote Sync Field` and `Quote Line Sync Field`. Four fields on each must be filled in:

1. Go to Setup > Custom Metadata Types and click `Manage Records` on one of the metadata types. We will use `Quote Sync Field` as our example.
2. If you are syncing two text fields, named `QuoteText__c` on Quote and `OpportunityText__c` on Opportunity, create a custom metadata type with the following:
   1. Name and DeveloperName are friendly fields and are not used by the app. Perhaps call this entry `Text`. Significantly, the DeveloperName must be unique.
   2. Type the field names into the `Quote Field` (QuoteText**c) and `Opportunity Field` (OpportunityText**c) fields. this single record is used for both directions of synchronization.
3. Save the record and go to the next one.

Again, the same CMT records are used for updating the Opportunity from its syncing Quote, and for updating the syncing Quote from its Opportunity.

# Roadmap (work in progress)

1. Create Unlocked Package Version.
2. Investigate using namespace for package
3. Clean more comments as scratch org tests continue to pass
