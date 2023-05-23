/**
 * Open-source version of Quote-Opportunity Sync
 *
 * @see [QuoteSync](https://github.com/SalesforceLabs/CustomQuoteSync)
 * @author {@link [Salesforce Labs](https://github.com/SalesforceLabs)}
 * @since 2014 Original Author
 * @author {@link [David Schach](https://github.com/dschach)}
 * @since 2022-10 Converted to Custom Metadata
 * @since 2022-10 Change else if to switch
 * @since 2023 Refine Quote Sync with new Quote fields
 * @group OppQuoteSync
 */
public class QuoteSyncUtil {
	/**
	 * Set of all new `Quote` Ids, maintained for the trigger handler
	 */
	private static Set<Id> newQuoteIds {
		get {
			if (newQuoteIds == null) {
				newQuoteIds = new Set<Id>();
			}
			return newQuoteIds;
		}
		set;
	}

	/**
	 * Standard fields are not synced by this app - Salesforce does that automatically
	 */
	//prettier-ignore
	public static Set<String> standardQuoteFields = new Set<String>{ 
		'IsSyncing',
		'Name',
		'OpportunityId',
		'Pricebook2Id'
	};
	/**
	 * Standard fields are not synced by this app - Salesforce does that automatically
	 */
	//prettier-ignore
	public static Set<String> standardOppFields = new Set<String>{ 
		'HasOpportunityLineItem', 
		'Name', 
		'Pricebook2Id',
		'SyncedQuoteId'
	};
	/**
	 * Standard fields are not synced by this app - Salesforce does that automatically
	 */
	//prettier-ignore
	public static Set<String> standardQuoteLineItemFields = new Set<String>{
		'Discount',
		'OpportunityLineItemId',
		'PricebookEntryId',
		'Quantity',
		'QuoteId',
		'ServiceDate',
		'SortOrder',
		'UnitPrice'
	};
	/**
	 * Standard fields are not synced by this app - Salesforce does that automatically
	 */
	//prettier-ignore
	public static Set<String> standardOppLineItemFields = new Set<String>{ 
		'Discount',
		'OpportunityId',
		'PricebookEntryId',
		'Quantity',
		'ServiceDate',
		'SortOrder',
		'UnitPrice'
	};
	/**
	 * Map `Quote` field => `Opportunity` for syncing
	 */
	private static Map<String, String> quoteFieldMap {
		get {
			if (quoteFieldMap == null) {
				quoteFieldMap = new Map<String, String>();
				Map<String, Quote_Sync_Fields__mdt> quoteFieldsCMDT = Quote_Sync_Fields__mdt.getAll();
				//System.debug('quoteFieldsCMDT ' + quoteFieldsCMDT);
				for (Quote_Sync_Fields__mdt qsf : quoteFieldsCMDT.values()) {
					quoteFieldMap.put(qsf.Quote_Field__c, qsf.Opportunity_Field__c);
					//System.debug('Map ' + qsf.Quote_Field__c + ' to ' + qsf.Opportunity_Field__c);
				}
				if (Test.isRunningTest()) {
					addQuoteField('description', 'description');
				}
				//System.debug('QuoteFieldMap: ' + quoteFieldMap);
			}
			return quoteFieldMap;
		}
		set;
	}

	/**
	 * @description Map `QuoteLineItem` field => `OpportunityLineItem` for syncing
	 */
	private static Map<String, String> quoteLineFieldMap {
		get {
			if (quoteLineFieldMap == null) {
				quoteLineFieldMap = new Map<String, String>();
				Map<String, QuoteLineItem_Sync_Fields__mdt> quoteLineFieldsCMDT = QuoteLineItem_Sync_Fields__mdt.getAll();
				//System.debug('quoteLineFieldsCMDT ' + quoteLineFieldsCMDT);
				for (QuoteLineItem_Sync_Fields__mdt qsf : quoteLineFieldsCMDT.values()) {
					quoteLineFieldMap.put(qsf.QuoteLineItem_Field__c, qsf.OpportunityLineItem_Field__c);
					//System.debug('Map ' + qsf.QuoteLineItem_Field__c + ' to ' + qsf.OpportunityLineItem_Field__c);
				}
				if (Test.isRunningTest()) {
					addQuoteLineField('description', 'description');
				}
				//System.debug('QuoteLineFieldMap: ' + quoteLineFieldMap);
			}

			return quoteLineFieldMap;
		}
		set;
	}

	/**
	 * @description Add an ID to the `newQuoteIds` set
	 *
	 * @param qid    Quote Id to remove
	 */
	public static void addNewQuoteId(Id qid) {
		newQuoteIds.add(qid);
	}

	/**
	 * @description Remove specific Ids from the `newQuoteIds` set
	 *
	 * @param ids   Quote IDs to remove
	 */
	public static void removeAllNewQuoteIds(Set<Id> ids) {
		newQuoteIds.removeAll(ids);
	}

	/**
	 * @description Does the set `newQuoteIds` contain this Id?
	 *
	 * @param qid    QuoteId
	 * @return      `Boolean` newQuoteIds.contains(qid);
	 */
	public static Boolean isNewQuote(Id qid) {
		return newQuoteIds.contains(qid);
	}

	/**
	 * @description Return `quoteLineFieldMap` keyset
	 *
	 * @return      `Set<String>` All `QuoteLineItem` fields in CMT records
	 */
	public static Set<String> getQuoteLineFields() {
		return quoteLineFieldMap.keySet();
	}

	/**
	 * @description Return `quoteFieldMap` keyset
	 *
	 * @return      `Set<String>` All `Quote` fields in CMT records
	 */
	public static Set<String> getQuoteFields() {
		return quoteFieldMap.keySet();
	}

	/**
	 * @description Return `quoteLineFieldMap` values as a set
	 * @since 2023 Return a Set for uniqueness instead of a List
	 *
	 * @return      `Set<String>` all `OpportunityLineItem` fields in CMT records
	 */
	public static Set<String> getOppLineFields() {
		return new Set<String>(quoteLineFieldMap.values());
	}

	/**
	 * @description Return `quoteFieldMap` values as a set
	 * @since 2023 Return a Set for uniqueness instead of a List
	 *
	 * @return      `Set<String>` all Opp fields in CMT records
	 */
	public static Set<String> getOppFields() {
		return new Set<String>(quoteFieldMap.values());
	}

	/**
	 * @description	     Given a `Quote` field, find the mapped `Opportunity` field
	 *
	 * @param quoteField Quote field name
	 * @return           `String` Opportunity field mapped from provided Quote field
	 */
	public static String getQuoteFieldMapTo(String quoteField) {
		return quoteFieldMap.get(quoteField);
	}

	/**
	 * @description          Given a `QuoteLineItem` field, find the mapped `Opportunity` field
	 *
	 * @param quoteLineField `QuoteLineItem` field name
	 * @return               `String` Opportunity field name
	 */
	public static String getQuoteLineFieldMapTo(String quoteLineField) {
		return quoteLineFieldMap.get(quoteLineField);
	}

	/**
	 * @description Join `quoteFieldMap` keyset with commas
	 * @since 2023 Use String.join instead of a loop and concatenating with a comma
	 *
	 * @return      `String` Quote fields separated by commas
	 */
	public static String getQuoteFieldsString() {
		Set<String> fields = getQuoteFields();
		return fields.isEmpty() ? '' : ', ' + String.join(new List<String>(fields), ', ');
	}

	/**
	 * @description Join `quoteFieldMap` values (`Opportunity` fields) with commas
	 * @since 2023 Use String.join instead of a loop and concatenating with a comma
	 *
	 * @return      `String` Opportunity fields separated by commas
	 */
	public static String getOppFieldsString() {
		Set<String> fields = getOppFields();
		return fields.isEmpty() ? '' : ', ' + String.join(new List<String>(fields), ', ');
	}

	/**
	 * @description Concatenate all mapped QuoteLineItem fields with a comma
	 * @since 2023 Use String.join instead of a loop and concatenating with a comma
	 *
	 * @return      `String` Comma-separated list of QuoteLineItem fields
	 */
	public static String getQuoteLineFieldsString() {
		Set<String> fields = getQuoteLineFields();
		return fields.isEmpty() ? '' : ', ' + String.join(new List<String>(fields), ', ');
	}

	/**
	 * @description Concatenate all mapped OpportunityLineItem fields with a comma
	 * @since 2023 Use String.join instead of a loop and concatenating with a comma
	 *
	 * @return      `String` Comma-separated list of OpportunityLineItem fields
	 */
	public static String getOppLineFieldsString() {
		Set<String> fields = getOppLineFields();
		return fields.isEmpty() ? '' : ', ' + String.join(new List<String>(fields), ', ');
	}

	/**
	 * @description      Add a Quote field to the fields to sync
	 *
	 * @param quoteField Quote field name
	 * @param oppField   Opp field name
	 */
	public static void addQuoteField(String quoteField, String oppField) {
		quoteFieldMap.put(quoteField, oppField);
	}

	/**
	 * @description    Add a QuoteLineItem field to the fields to sync
	 *
	 * @param qliField Quote Line field name
	 * @param oliField Opp Line field name
	 */
	public static void addQuoteLineField(String qliField, String oliField) {
		quoteLineFieldMap.put(qliField, oliField);
	}

	/**
	 * @description Remove a QuoteLineItem field from the fields to sync
	 * <br>May be removed, as not asserted in test class
	 *
	 * @param qliField Quote Line field name
	 * @return         `String` The removed field name
	 */
	public static String removeQuoteLineField(String qliField) {
		return quoteLineFieldMap.remove(qliField);
	}

	/**
	 * Global describe - memoized
	 * @since 2023 Lazy load global describe to save resources
	 */
	private static Map<String, Schema.SObjectType> gd {
		get {
			if (gd == null) {
				gd = Schema.getGlobalDescribe();
			}
			return gd;
		}
		set;
	}

	/**
	 * All `Quote` fields
	 */
	private static final Map<String, SObjectField> QUOTE_FIELDS = gd.get('Quote').getDescribe().fields.getMap();
	/**
	 * All `QuoteLineItem` fields
	 */
	private static final Map<String, SObjectField> QUOTE_LINE_FIELDS = gd.get('QuoteLineItem').getDescribe().fields.getMap();
	/**
	 * All `Opportunity` fields
	 */
	private static final Map<String, SObjectField> OPP_FIELDS = gd.get('Opportunity').getDescribe().fields.getMap();
	/**
	 * All `OpportunityLineItem` fields
	 */
	private static final Map<String, SObjectField> OPP_LINE_FIELDS = gd.get('OpportunityLineItem').getDescribe().fields.getMap();

	/**
	 * @description  Given an object and field, return the `Schema.DescribeFieldResult`
	 * @since 2022 Use switch statement
	 *
	 * @param entity Object name
	 * @param field  Field name
	 * @return       `Schema.DescribeFieldResult` for that field
	 */
	public static Schema.DescribeFieldResult getField(String entity, String field) {
		Schema.DescribeFieldResult f = null;

		switch on entity {
			when 'Quote' {
				f = QUOTE_FIELDS.get(field).getDescribe();
			}
			when 'QuoteLineItem' {
				f = QUOTE_LINE_FIELDS.get(field).getDescribe();
			}
			when 'Opportunity' {
				f = OPP_FIELDS.get(field).getDescribe();
			}
			when 'OpportunityLineItem' {
				f = OPP_LINE_FIELDS.get(field).getDescribe();
			}
			when else {
				Assert.fail('Unknown entity: ' + entity + ', field: ' + field);
			}
		}
		return f;
	}

	/**
	 * Custom, non-synced fields
	 */
	public static Map<String, Schema.DescribeFieldResult> quoteRequiredFields = getCustomRequiredFields('Quote');
	/**
	 * Custom, non-synced fields
	 */
	public static Map<String, Schema.DescribeFieldResult> quoteLineRequiredFields = getCustomRequiredFields('QuoteLineItem');
	/**
	 * Custom, non-synced fields
	 */
	public static Map<String, Schema.DescribeFieldResult> oppRequiredFields = getCustomRequiredFields('Opportunity');
	/**
	 * Custom, non-synced fields
	 */
	public static Map<String, Schema.DescribeFieldResult> oppLineRequiredFields = getCustomRequiredFields('OpportunityLineItem');

	/**
	 * @description  Collect all custom fields for an object, and skip fields we need to sync.
	 * <br>We may be able to memoize this, but since it's not called directly, there's low risk
	 * @since 2022 Use switch statement
	 *
	 * @param entity Object name - Quote, Opportunity, QuoteLineItem, or OpportunityLineItem
	 * @return       `Map<String, Schema.DescribeFieldResult>` For the given object, a list of field describe results (minus our synced non-Boolean fields)
	 */
	public static Map<String, Schema.DescribeFieldResult> getCustomRequiredFields(String entity) {
		Map<String, SObjectField> fields = null;
		Set<String> excludeFields = new Set<String>();

		switch on entity {
			when 'Quote' {
				fields = QUOTE_FIELDS;
				excludeFields.addAll(getQuoteFields());
			}
			when 'QuoteLineItem' {
				fields = QUOTE_LINE_FIELDS;
				excludeFields.addAll(getQuoteLineFields());
			}
			when 'Opportunity' {
				fields = OPP_FIELDS;
				excludeFields.addAll(getOppFields());
			}
			when 'OpportunityLineItem' {
				fields = OPP_LINE_FIELDS;
				excludeFields.addAll(getOppLineFields());
			}
			when else {
				Assert.fail('Unknown entity: ' + entity);
			}
		}

		Map<String, Schema.DescribeFieldResult> requiredFields = new Map<String, Schema.DescribeFieldResult>();

		for (String field : fields.keySet()) {
			Schema.DescribeFieldResult f = fields.get(field).getDescribe();

			if (excludeFields.contains(field) && f.getType() != DisplayType.Boolean) {
				continue;
			}

			if (
				f.isCustom() &&
				!f.isNillable() &&
				!f.isAutoNumber() &&
				!f.isCalculated() &&
				(!f.isDefaultedOnCreate() || f.getType() == DisplayType.Boolean)
			) {
				requiredFields.put(field, f);
			}
		}

		return requiredFields;
	}

	/**
	 * @description Create a value for each custom field we are not syncing
	 *
	 * @param sobj  Sobject record - `Quote`, `Opportunity`, `QuoteLineItem`, or `OpportunityLineItem`
	 */
	public static void populateRequiredFields(SObject sobj) {
		String entity = sobj.getSObjectType().getDescribe().getName();

		Map<String, Schema.DescribeFieldResult> fields = null;

		switch on entity {
			when 'Quote' {
				fields = quoteRequiredFields;
			}
			when 'QuoteLineItem' {
				fields = quoteLineRequiredFields;
			}
			when 'Opportunity' {
				fields = oppRequiredFields;
			}
			when 'OpportunityLineItem' {
				fields = oppLineRequiredFields;
			}
			when else {
				Assert.fail('Unknown entity: ' + entity);
			}
		}

		for (String field : fields.keySet()) {
			if (sobj.get(field) != null) {
				continue;
			}
			Schema.DescribeFieldResult result = fields.get(field);
			sobj.put(field, createValue(sobj, entity, field, result, false));
		}
	}

	/**
	 * @description          Create a standard value for each field in our org. This could be done more elegantly with fewer parameters,
	 * but it is effective like this.
	 * @since 2022 Use switch statement
	 *
	 * @param sobj           SObject (not the object name)
	 * @param entity         Object Name
	 * @param field          Field Name
	 * @param result         Passed DescribeFieldResult
	 * @param setNullOrFalse If true, set field to null (or Boolean to false)
	 * @return               `Object` Object with fields filled
	 */
	public static Object createValue(SObject sobj, String entity, String field, Schema.DescribeFieldResult result, Boolean setNullOrFalse) {
		Object value = null;
		String strValue = System.currentTimeMillis() + '_' + entity + '_' + field;

		Map<String, SObjectField> fieldsMap = gd.get(entity).getDescribe().fields.getMap();

		Schema.DisplayType ftype = result.getType();

		if (!setNullOrFalse) {
			switch on ftype {
				when Base64 {
					value = Blob.valueOf(strValue);
				}
				when Boolean {
					if (sobj.get(field) != null) {
						value = !Boolean.valueOf(sobj.get(field));
					} else if (entity.equalsIgnoreCase('Quote') || entity.equalsIgnoreCase('QuoteLineItem')) {
						value = false;
					} else {
						value = true;
					}
				}
				when Combobox {
					value = strValue;
				}
				when Currency {
					value = Decimal.valueOf(Math.random());
				}
				when Date {
					if (entity.equalsIgnoreCase('Quote') || entity.equalsIgnoreCase('QuoteLineItem')) {
						value = Date.today().addDays(Integer.valueof(Math.random() * 30));
					} else {
						value = Date.today().addDays(Integer.valueof(Math.random() * -30));
					}
				}
				when DateTime {
					if (entity.equalsIgnoreCase('Quote') || entity.equalsIgnoreCase('QuoteLineItem')) {
						value = DateTime.now().addMinutes(Integer.valueof(Math.random() * 60));
					} else {
						value = DateTime.now().addMinutes(Integer.valueof(Math.random() * -60));
					}
				}
				when Integer {
					value = Integer.valueOf(Math.random());
				}
				when Double {
					value = Math.random();
				}
				when Percent {
					value = 10 * Math.random();
				}
				when Email {
					value = System.currentTimeMillis() + '@' + entity.toLowerCase() + 'sync.test';
				}
				when Phone {
					value = String.valueOf(System.currentTimeMillis());
				}
				when Picklist, MultiPicklist {
					List<Schema.PicklistEntry> values = result.getPicklistValues();
					if (entity.equalsIgnoreCase('Quote') || entity.equalsIgnoreCase('QuoteLineItem')) {
						value = values.get(0).getValue();
					} else {
						values.get(1).getValue();
					}
				}
				when String, TextArea, Url {
					Integer fieldLength = fieldsMap.get(field).getDescribe().length;
					value = strValue.left(fieldLength - 1);
				}
				when Time {
					value = DateTime.now().time();
				}
				when else {
					value = strValue;
				}
			}
		} else {
			if (ftype == DisplayType.Boolean) {
				value = false;
			} else {
				value = null;
			}
		}

		return value;
	}

	// UNUSED METHODS TO BE DELETED

	/**
	 * @description Getter for `newQuoteIds` variable
	 *
	 * @return      `Set<Id>` newQuoteIds
	 */
	/* public static Set<Id> getNewQuoteIds() {
		return newQuoteIds;
	} */

	/**
	 * @description Remove all Ids from the `newQuoteIds` set
	 * @deprecated Unused
	 */
	/* public static void clearNewQuoteIds() {
		newQuoteIds.clear();
	} */

	/**
	 * @description Remove an ID from the `newQuoteIds` set
	 *
	 * @param id Quote Id
	 * @deprecated Unused
	 */
	/* public static void removeNewQuoteId(Id id) {
		newQuoteIds.remove(id);
	} */
	/**
	 * @description      Remove a Quote field from the Quote fields to sync
	 * <br>May be removed, as not asserted in test class
	 *
	 * @param quoteField Quote field name
	 * @return           `String` The field name
	 * @deprecated       Unused
	 */
	/* public static String removeQuoteField(String quoteField) {
		return quoteFieldMap.remove(quoteField);
	} */
}