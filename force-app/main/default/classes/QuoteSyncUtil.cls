/**
 * Open-source version of Quote-Opportunity Sync
 *
 * @see [QuoteSync](https://github.com/SalesforceLabs/CustomQuoteSync)
 * @author {@link [Salesforce Labs](https://github.com/SalesforceLabs)}
 * @since  2014 Original Author
 * @author {@link [David Schach](https://github.com/dschach)}
 * @since 2022-10 Converted to Custom Metadata
 * @since 2023 Refine Quote Sync with new Quote fields
 * @group OppQuoteSync
 */
public class QuoteSyncUtil {
	/**
	 * Set of all new Quote Ids, maintained for the trigger handler
	 */
	private static Set<Id> newQuoteIds = new Set<Id>();

	//prettier-ignore
	private static Set<String> standardQuoteFields = new Set<String>{ 
		'IsSyncing',
		'Name',
		'OpportunityId',
		'Pricebook2Id'
	};
	//prettier-ignore
	private static Set<String> standardOppFields = new Set<String>{ 
		'HasOpportunityLineItem', 
		'Name', 
		'Pricebook2Id',
		'SyncedQuoteId'
	};
	//prettier-ignore
	private static Set<String> standardQuoteLineItemFields = new Set<String>{
		'Discount',
		'OpportunityLineItemId',
		'PricebookEntryId',
		'Quantity',
		'QuoteId',
		'ServiceDate',
		'SortOrder',
		'UnitPrice'
	};
	//prettier-ignore
	private static Set<String> standardOppLineItemFields = new Set<String>{ 
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
				System.debug('quoteFieldsCMDT ' + quoteFieldsCMDT);
				for (Quote_Sync_Fields__mdt qsf : quoteFieldsCMDT.values()) {
					quoteFieldMap.put(qsf.Quote_Field__c, qsf.Opportunity_Field__c);
					System.debug('Map ' + qsf.Quote_Field__c + ' to ' + qsf.Opportunity_Field__c);
				}
				if (Test.isRunningTest()) {
					quoteFieldMap.put('description', 'description');
				}
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
				System.debug('quoteLineFieldsCMDT ' + quoteLineFieldsCMDT);
				for (QuoteLineItem_Sync_Fields__mdt qsf : quoteLineFieldsCMDT.values()) {
					quoteLineFieldMap.put(qsf.QuoteLineItem_Field__c, qsf.OpportunityLineItem_Field__c);
					System.debug('Map ' + qsf.QuoteLineItem_Field__c + ' to ' + qsf.OpportunityLineItem_Field__c);
				}
				if (Test.isRunningTest()) {
					quoteLineFieldMap.put('description', 'description');
				}
			}
			return quoteLineFieldMap;
		}
		set;
	}

	/**
	 * @description getter for `newQuoteIds` variable
	 *
	 * @return      `Set<Id>` newQuoteIds
	 */
	public static Set<Id> getNewQuoteIds() {
		return newQuoteIds;
	}

	/**
	 * @description Add an ID to the `newQuoteIds` set
	 *
	 * @param id
	 */
	public static void addNewQuoteId(Id id) {
		newQuoteIds.add(id);
	}

	/**
	 * @description Remove an ID from the `newQuoteIds` set
	 *
	 * @param id
	 */
	public static void removeNewQuoteId(Id id) {
		newQuoteIds.remove(id);
	}

	/**
	 * @description Remove specific Ids from the `newQuoteIds` set
	 *
	 * @param ids
	 */
	public static void removeAllNewQuoteIds(Set<Id> ids) {
		newQuoteIds.removeAll(ids);
	}

	/**
	 * @description Remove all Ids from the `newQuoteIds` set
	 */
	public static void clearNewQuoteIds() {
		newQuoteIds.clear();
	}

	/**
	 * @description Does the set of `newQuoteIds` contain this Id?
	 *
	 * @param id    QuoteId
	 * @return      `Boolean` newQuoteIds.contains(id);
	 */
	public static Boolean isNewQuote(Id id) {
		return newQuoteIds.contains(id);
	}

	public static Set<String> getQuoteLineFields() {
		return quoteLineFieldMap.keySet();
	}

	public static Set<String> getQuoteFields() {
		return quoteFieldMap.keySet();
	}

	public static List<String> getOppLineFields() {
		return quoteLineFieldMap.values();
	}

	public static List<String> getOppFields() {
		return quoteFieldMap.values();
	}

	public static String getQuoteFieldMapTo(String quoteField) {
		return quoteFieldMap.get(quoteField);
	}

	public static String getQuoteLineFieldMapTo(String quoteLineField) {
		return quoteLineFieldMap.get(quoteLineField);
	}

	public static String getQuoteFieldsString() {
		String fields = '';
		for (String field : getQuoteFields()) {
			fields += ', ' + field;
		}
		return fields;
	}

	public static String getOppFieldsString() {
		String fields = '';
		for (String field : getOppFields()) {
			fields += ', ' + field;
		}
		return fields;
	}

	public static String getQuoteLineFieldsString() {
		String fields = '';
		for (String field : getQuoteLineFields()) {
			fields += ', ' + field;
		}
		return fields;
	}

	public static String getOppLineFieldsString() {
		String fields = '';
		for (String field : getOppLineFields()) {
			fields += ', ' + field;
		}
		return fields;
	}

	public static String addQuoteField(String quoteField, String oppField) {
		return quoteFieldMap.put(quoteField, oppField);
	}

	public static String addQuoteLineField(String qliField, String oliField) {
		return quoteLineFieldMap.put(qliField, oliField);
	}

	public static String removeQuoteField(String quoteField) {
		return quoteFieldMap.remove(quoteField);
	}

	public static String removeQuoteLineField(String qliField) {
		return quoteLineFieldMap.remove(qliField);
	}

	private static Map<String, SObjectField> quoteFields = Schema.getGlobalDescribe().get('Quote').getDescribe().fields.getMap();
	private static Map<String, SObjectField> quoteLineFields = Schema.getGlobalDescribe().get('QuoteLineItem').getDescribe().fields.getMap();

	private static Map<String, SObjectField> oppFields = Schema.getGlobalDescribe().get('Opportunity').getDescribe().fields.getMap();
	private static Map<String, SObjectField> oppLineFields = Schema.getGlobalDescribe().get('OpportunityLineItem').getDescribe().fields.getMap();

	public static Schema.DescribeFieldResult getField(String entity, String field) {
		Schema.DescribeFieldResult f = null;

		if (entity == 'Quote') {
			f = quoteFields.get(field).getDescribe();
		} else if (entity == 'QuoteLineItem') {
			f = quoteLineFields.get(field).getDescribe();
		} else if (entity == 'Opportunity') {
			f = oppFields.get(field).getDescribe();
		} else if (entity == 'OpportunityLineItem') {
			f = oppLineFields.get(field).getDescribe();
		} else {
			System.assert(false, 'Unknown entity: ' + entity + ', field: ' + field);
		}

		return f;
	}

	public static Map<String, Schema.DescribeFieldResult> quoteRequiredFields = getCustomRequiredFields('Quote');
	public static Map<String, Schema.DescribeFieldResult> quoteLineRequiredFields = getCustomRequiredFields('QuoteLineItem');
	public static Map<String, Schema.DescribeFieldResult> oppRequiredFields = getCustomRequiredFields('Opportunity');
	public static Map<String, Schema.DescribeFieldResult> oppLineRequiredFields = getCustomRequiredFields('OpportunityLineItem');

	public static Map<String, Schema.DescribeFieldResult> getCustomRequiredFields(String entity) {
		Map<String, SObjectField> fields = null;
		Set<String> excludeFields = new Set<String>();

		if (entity == 'Quote') {
			fields = quoteFields;
			excludeFields.addAll(getQuoteFields());
		} else if (entity == 'QuoteLineItem') {
			fields = quoteLineFields;
			excludeFields.addAll(getQuoteLineFields());
		} else if (entity == 'Opportunity') {
			fields = oppFields;
			excludeFields.addAll(getOppFields());
		} else if (entity == 'OpportunityLineItem') {
			fields = oppLineFields;
			excludeFields.addAll(getOppLineFields());
		} else {
			System.assert(false, 'Unknown entity: ' + entity);
		}

		Map<String, Schema.DescribeFieldResult> requiredFields = new Map<String, Schema.DescribeFieldResult>();

		for (String field : fields.keySet()) {
			Schema.DescribeFieldResult f = fields.get(field).getDescribe();

			if (excludeFields.contains(field) && f.getType() != DisplayType.Boolean) {
				continue;
			}

			if (f.isCustom() && f.isCreateable() && !f.isNillable() && !f.isAutoNumber() && !f.isCalculated() && (!f.isDefaultedOnCreate() || f.getType() == DisplayType.Boolean)) {
				requiredFields.put(field, f);
			}
		}

		return requiredFields;
	}

	public static void populateRequiredFields(SObject sobj) {
		String entity = sobj.getSObjectType().getDescribe().getName();

		Map<String, Schema.DescribeFieldResult> fields = null;

		if (entity == 'Quote') {
			fields = QuoteRequiredFields;
		} else if (entity == 'QuoteLineItem') {
			fields = QuoteLineRequiredFields;
		} else if (entity == 'Opportunity') {
			fields = OppRequiredFields;
		} else if (entity == 'OpportunityLineItem') {
			fields = OppLineRequiredFields;
		} else {
			System.assert(false, 'Unknown entity: ' + entity);
		}

		for (String field : fields.keySet()) {
			if (sobj.get(field) != null) {
				continue;
			}
			Schema.DescribeFieldResult result = fields.get(field);
			sobj.put(field, createValue(sobj, entity, field, result, false));
		}
	}

	public static Object createValue(SObject sobj, String entity, String field, Schema.DescribeFieldResult result, boolean setNullOrFalse) {
		Object value = null;
		String strValue = entity + '_' + field + '_' + System.currentTimeMillis();

		Schema.DisplayType ftype = result.getType();

		if (!setNullOrFalse) {
			if (ftype == DisplayType.Base64) {
				value = Blob.valueOf(strValue);
			} else if (ftype == DisplayType.Boolean) {
				if (sobj.get(field) != null) {
					value = !Boolean.valueOf(sobj.get(field));
				} else if (entity == 'Quote' || entity == 'QuoteLineItem') {
					value = false;
				} else {
					value = true;
				}
			} else if (ftype == DisplayType.Currency) {
				value = Decimal.valueOf(Math.random());
			} else if (ftype == DisplayType.Date) {
				value = Date.today();
			} else if (ftype == DisplayType.DateTime) {
				value = DateTime.now();
			} else if (ftype == DisplayType.Integer) {
				value = Integer.valueOf(Math.random());
			} else if (ftype == DisplayType.Double || ftype == DisplayType.Percent) {
				value = Math.random();
			} else if (ftype == DisplayType.Email) {
				value = System.currentTimeMillis() + '@quotesync.test';
			} else if (ftype == DisplayType.Phone) {
				value = String.valueOf(System.currentTimeMillis());
			} else if (ftype == DisplayType.Picklist) {
				List<Schema.PicklistEntry> values = result.getPicklistValues();
				value = values.get(0).getValue();
			} else if (ftype == DisplayType.MultiPicklist) {
				List<Schema.PicklistEntry> values = result.getPicklistValues();
				value = values.get(0).getValue();
			} else if (ftype == DisplayType.String || ftype == DisplayType.TextArea || ftype == DisplayType.Url) {
				value = strValue;
			} else {
				value = strValue;
			}
		} else {
			if (ftype == DisplayType.Boolean) {
				value = false;
			}
		}

		return value;
	}
}