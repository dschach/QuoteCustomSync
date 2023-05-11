/**
 * Test class for Quote/Opportunity sync
 *
 * @author {@link [Salesforce Labs](https://github.com/SalesforceLabs)}
 * @since 2014
 * @author {@link [David Schach](https://github.com/dschach)}
 * @since 2022-10 Converted to Custom Metadata
 * @since 2023-04 Lazy load and memoize Standard Pricebook Id
 * @see [QuoteSync](https://github.com/SalesforceLabs/CustomQuoteSync)
 * @see QuoteSyncUtil
 * @see QuoteSyncHandler
 * @group OppQuoteSync
 */
@SuppressWarnings('PMD.ApexDoc')
@isTest
private without sharing class QuoteSyncTest {
	/**
	 * Store the standard Price Book Id
	 */
	private static Id standardPricebookId;

	/**
	 * Memoized version of `Test.getStandardPricebookId()` so we call it once and not again
	 *
	 * @return `Id` Standard Pricebook Id
	 */
	public static Id getStandardPricebookId() {
		if (standardPricebookId == null) {
			standardPricebookId = Test.getStandardPricebookId();
		}
		return standardPricebookId;
	}

	@TestSetup
	private static void makeData() {
		Product2 prod = new Product2(Name = 'test product', IsActive = true);
		insert prod;

		Pricebook2 standardPB = new Pricebook2(Id = getStandardPricebookId(), IsActive = true);
		Database.update(standardPB, false);

		PricebookEntry pbe = new PricebookEntry(Pricebook2Id = getStandardPricebookId(), Product2Id = prod.Id, IsActive = true, UnitPrice = 10);
		insert pbe;

		Account acc = new Account(name = 'test acc');
		insert acc;
	}

	private static Boolean assertQuoteSync(Id oppId, Id quoteId) {
		return assertQuoteSync(oppId, quoteId, true, false);
	}

	private static Boolean assertQuoteNotSync(Id oppId, Id quoteId, Boolean isCreate) {
		return assertQuoteSync(oppId, quoteId, false, isCreate);
	}

	private static Boolean assertQuoteNotSync(Id oppId, Id quoteId) {
		return assertQuoteSync(oppId, quoteId, false, false);
	}

	private static Boolean assertQuoteSync(Id oppId, Id quoteId, Boolean sync, Boolean isCreate) {
		String quoteFields = QuoteSyncUtil.getQuoteFieldsString();
		String oppFields = QuoteSyncUtil.getOppFieldsString();

		String oppQuery = 'SELECT Id, SyncedQuoteId' + oppFields + ' FROM Opportunity WHERE Id = \'' + oppId + '\'';
		String quoteQuery = 'SELECT Id, OpportunityId' + quoteFields + ' FROM Quote WHERE Id = \'' + quoteId + '\'';

		Opportunity opp = ((List<Opportunity>) Database.query(oppQuery))[0];
		Quote quote = ((List<Quote>) Database.query(quoteQuery))[0];

		for (String quoteField : QuoteSyncUtil.getQuoteFields()) {
			String oppField = QuoteSyncUtil.getQuoteFieldMapTo(quoteField);
			Object oppValue = opp.get(oppField);
			Object quoteValue = quote.get(quoteField);

			// Boolean field is equal even is not synced because of trigger on Quote creation copy values from Opp
			if (sync || (oppValue instanceof Boolean && quoteValue instanceof Boolean && isCreate)) {
				//prettier-ignore
				System.assertEquals(oppValue, quoteValue, 'Opportunity.' + oppField + ' value does not match Quote.' + quoteField + ' value');
			} else {
				//prettier-ignore
				System.assertNotEquals(oppValue, quoteValue, 'Opportunity.' + oppField + ' value should not match Quote.' + quoteField + ' value');
			}
		}
		return true;
	}

	private static Boolean assertQuoteLineSync(Id oppId, Id quoteId) {
		return assertQuoteLineSync(oppId, quoteId, true, false);
	}

	private static Boolean assertQuoteLineNotSync(Id oppId, Id quoteId) {
		return assertQuoteLineSync(oppId, quoteId, false, false);
	}

	private static Boolean assertQuoteLineNotSync(Id oppId, Id quoteId, Boolean isCreate) {
		return assertQuoteLineSync(oppId, quoteId, false, isCreate);
	}

	private static Boolean assertQuoteLineSync(Id oppId, Id quoteId, Boolean sync, Boolean isCreate) {
		String qliFields = QuoteSyncUtil.getQuoteLineFieldsString();
		String oliFields = QuoteSyncUtil.getOppLineFieldsString();

		//prettier-ignore
		String qliQuery = 'SELECT Id, QuoteId, OpportunityLineItemId, PricebookEntryId, UnitPrice, Quantity, Discount, ServiceDate, SortOrder' + qliFields + ' FROM QuoteLineItem WHERE QuoteId = \'' + quoteId + '\'';
		//prettier-ignore
		String oliQuery = 'SELECT Id, OpportunityId, PricebookEntryId, UnitPrice, Quantity, Discount, ServiceDate, SortOrder' + oliFields + ' FROM OpportunityLineItem WHERE OpportunityId  = \'' + oppId + '\'';
		List<OpportunityLineItem> olis = Database.query(oliQuery);
		List<QuoteLineItem> qlis = Database.query(qliQuery);

		if (sync) {
			String errorMsg = '';
			if (olis.size() != qlis.size()) {
				Integer n = 0;
				for (OpportunityLineItem oli : olis) {
					n++;
					String oliString = printSObject(
						oli,
						'#################   OppLine ' + n + ': Id=' + oli.Id,
						QuoteSyncUtil.standardOppLineItemFields,
						QuoteSyncUtil.getOppLineFields(),
						false
					);
					errorMsg += oliString + '\n';
				}

				n = 0;
				for (QuoteLineItem qli : qlis) {
					n++;
					String qliString = printSObject(
						qli,
						'#################   QuoteLine ' + n + ': Id=' + qli.Id,
						QuoteSyncUtil.standardQuoteLineItemFields,
						QuoteSyncUtil.getQuoteLineFields(),
						false
					);
					errorMsg += qliString + '\n';
				}
			}
			//prettier-ignore
			System.assertEquals(olis.size(), qlis.size(), 'Number of OpportunityLineItems: ' + olis.size() + ' does not match number of QuoteLineItems: ' + qlis.size() + '\n' + errorMsg);
		}

		for (QuoteLineItem qli : qlis) {
			Boolean match = false;
			for (OpportunityLineItem oli : olis) {
				if (
					(oli.PricebookEntryId == qli.PricebookEntryId &&
					oli.UnitPrice == qli.UnitPrice &&
					oli.Quantity == qli.Quantity &&
					oli.Discount == qli.Discount &&
					oli.ServiceDate == qli.ServiceDate &&
					oli.SortOrder == qli.SortOrder) ||
					// prettier-ignore
					(qli.OpportunityLineItemId != null && oli.Id == qli.OpportunityLineItemId)
				) {
					for (String qliField : QuoteSyncUtil.getQuoteLineFields()) {
						String oliField = QuoteSyncUtil.getQuoteLineFieldMapTo(qliField);
						Object oliValue = oli.get(oliField);
						Object qliValue = qli.get(qliField);
						if (oliValue instanceof Boolean && oliValue == null) {
							oliValue = false;
						}
						if (qliValue instanceof Boolean && qliValue == null) {
							qliValue = false;
						}

						// Boolean field is equal even is not synced because of trigger on QuoteLineItem creation copy values from OppLineItem
						if (sync || (oliValue instanceof Boolean && qliValue instanceof Boolean && isCreate)) {
							//prettier-ignore
							System.assertEquals(oliValue, qliValue, 'OpportunityLineItem.' + oliField + ' value does not match QuoteLineItem.' + qliField + ' value');
						} else {
							//prettier-ignore
							System.assertNotEquals(oliValue, qliValue, 'OpportunityLineItem.' + oliField + ' value should not match QuoteLineItem.' + qliField + ' value');
						}
					}

					match = true;
					break;
				}
			}
			if (sync) {
				System.assert(match, 'No matching oppline');
			}
		}
		return true;
	}

	private static Boolean assertQuoteFields(Id quoteId, Quote expectedQuote) {
		String quoteFields = QuoteSyncUtil.getQuoteFieldsString();
		String quoteQuery = 'SELECT Id, OpportunityId' + quoteFields + ' FROM Quote WHERE Id = \'' + quoteId + '\'';

		Quote quote = ((List<Quote>) Database.query(quoteQuery))[0];

		for (String quoteField : QuoteSyncUtil.getQuoteFields()) {
			Object quoteValue = quote.get(quoteField);
			Object expectedValue = expectedQuote.get(quoteField);
			System.assertEquals(expectedValue, quoteValue, 'Quote.' + quoteField + ' value does not match');
		}
		return true;
	}

	private static Boolean assertOppFields(Id oppId, Opportunity expectedOpp) {
		String oppFields = QuoteSyncUtil.getOppFieldsString();
		String oppQuery = 'SELECT Id, SyncedQuoteId' + oppFields + ' FROM Opportunity WHERE Id = \'' + oppId + '\'';

		Opportunity opp = ((List<Opportunity>) Database.query(oppQuery))[0];

		for (String oppField : QuoteSyncUtil.getOppFields()) {
			Object oppValue = opp.get(oppField);
			Object expectedValue = expectedOpp.get(oppField);
			System.assertEquals(expectedValue, oppValue, 'Opportunity.' + oppField + ' value does not match');
		}
		return true;
	}

	private static Boolean assertQuoteLineFields(Id quoteId, List<QuoteLineItem> quoteLines) {
		String qliFields = QuoteSyncUtil.getQuoteLineFieldsString();
		//prettier-ignore
		String qliQuery = 'SELECT Id, UnitPrice, Quantity, Discount, ServiceDate, SortOrder' + qliFields + ' FROM QuoteLineItem WHERE QuoteId = \'' + quoteId + '\'';
		List<QuoteLineItem> qlis = Database.query(qliQuery);

		System.assertEquals(quoteLines.size(), qlis.size(), 'Number of line items does not match');

		for (QuoteLineItem qli : qlis) {
			for (QuoteLineItem qline : quoteLines) {
				if (qli.Id == qline.Id) {
					for (String qliField : QuoteSyncUtil.getQuoteLineFields()) {
						Object qliValue = qli.get(qliField);
						Object expectedValue = qline.get(qliField);

						System.assertEquals(expectedValue, qliValue, 'QuoteLineItem.' + qliField + ' value does not match');
					}
					break;
				}
			}
		}
		return true;
	}

	private static Boolean assertOppLineFields(Id oppId, List<OpportunityLineItem> oppLines) {
		String oliFields = QuoteSyncUtil.getOppLineFieldsString();
		//prettier-ignore
		String oliQuery = 'SELECT Id, UnitPrice, Quantity, Discount, ServiceDate, SortOrder' + oliFields + ' FROM OpportunityLineItem WHERE OpportunityId = \'' + oppId + '\'';
		List<OpportunityLineItem> olis = Database.query(oliQuery);
		//System.debug(olis);

		System.assertEquals(oppLines.size(), olis.size(), 'Number of line items does not match');

		for (OpportunityLineItem oli : olis) {
			for (OpportunityLineItem oppline : oppLines) {
				if (oli.Id == oppline.Id) {
					for (String oliField : QuoteSyncUtil.getOppLineFields()) {
						Object oliValue = oli.get(oliField);
						Object expectedValue = oppline.get(oliField);

						System.assertEquals(expectedValue, oliValue, 'OpportunityLineItem.' + oliField + ' value does not match');
					}
					break;
				}
			}
		}
		return true;
	}

	/**
	 * Debug method for use in checking unit tests.
	 *
	 * @param oppId The `Opportunity` to debug
	 * @example
	 * printOpp(opp.Id);
	 */
	private static void printOpp(Id oppId) {
		String oppFields = QuoteSyncUtil.getOppFieldsString();
		String oppQuery = 'SELECT Id, SyncedQuoteId' + oppFields + ' FROM Opportunity WHERE Id = \'' + oppId + '\'';

		Opportunity opp = ((List<Opportunity>) Database.query(oppQuery))[0];

		printSObject(opp, 'Opportunity: ' + opp.Id, QuoteSyncUtil.standardOppFields, QuoteSyncUtil.getOppFields(), true);
	}

	/**
	 * Debug method for use in checking unit tests.
	 *
	 * @param quoteId The `Quote` to debug
	 * @example
	 * printQuote(quote.Id);
	 */
	private static void printQuote(Id quoteId) {
		String quoteFields = QuoteSyncUtil.getQuoteFieldsString();
		String quoteQuery = 'SELECT Id, OpportunityId' + quoteFields + ' FROM Quote WHERE Id = \'' + quoteId + '\'';

		Quote quote = ((List<Quote>) Database.query(quoteQuery))[0];

		printSObject(quote, 'QuoteId: ' + quote.Id, QuoteSyncUtil.standardQuoteFields, QuoteSyncUtil.getQuoteFields(), true);
	}

	/**
	 * Debug method for use in checking unit tests.
	 *
	 * @param oppId The `Opportunity` to debug
	 * @example
	 * printOppLines(opp.Id);
	 */
	private static void printOppLines(Id oppId) {
		String oliFields = QuoteSyncUtil.getOppLineFieldsString();
		//prettier-ignore
		String oliQuery = 'SELECT Id, OpportunityId, PricebookEntryId, UnitPrice, Quantity, Discount, ServiceDate, SortOrder' + 
		//prettier-ignore
		oliFields + ' FROM OpportunityLineItem WHERE OpportunityId  = \'' + oppId + '\'';
		List<OpportunityLineItem> olis = Database.query(oliQuery);

		Integer n = 0;
		for (OpportunityLineItem oli : olis) {
			n++;

			printSObject(
				oli,
				'*******************   OppLine ' + n + ': ' + 'Id=' + oli.Id,
				QuoteSyncUtil.standardOppLineItemFields,
				QuoteSyncUtil.getOppLineFields(),
				true
			);
		}
	}

	/**
	 * Debug method for use in checking unit tests.
	 *
	 * @param quoteId The `Quote` to debug
	 * @example
	 * printQuoteLines(quote.Id)
	 */
	private static void printQuoteLines(Id quoteId) {
		String qliFields = QuoteSyncUtil.getQuoteLineFieldsString();
		//prettier-ignore
		String qliQuery = 'SELECT Id, QuoteId, PricebookEntryId, UnitPrice, Quantity, Discount, ServiceDate, SortOrder' + 
		//prettier-ignore
		qliFields + ' FROM QuoteLineItem WHERE QuoteId = \'' + quoteId + '\'';
		List<QuoteLineItem> qlis = Database.query(qliQuery);

		Integer n = 0;
		for (QuoteLineItem qli : qlis) {
			n++;

			printSObject(
				qli,
				'*******************   QuoteLine ' + n + ': ' + 'Id=' + qli.Id,
				QuoteSyncUtil.standardQuoteLineItemFields,
				QuoteSyncUtil.getQuoteLineFields(),
				true
			);
		}
	}

	/**
	 * @description          This method generates the debug string for use in testing. It uses a set of strings hard-coded as standard object fields and the synced fields specified in our metadata.
	 *
	 * @param so             SObject to print
	 * @param leader         Leading part of describe string
	 * @param standardFields Set of standard fields
	 * @param customFields   All synced custom fields
	 * @example
	 * printSObject(oli, #################   OppLine ' + n +': Id=' + oli.Id, QuoteSyncUtil.standardOppLineItemFields, QuoteSyncUtil.getOppLineFields());
	 */
	private static String printSObject(SObject so, String leader, Set<String> standardFields, Set<String> customFields, Boolean doDebug) {
		String soString = leader;
		for (String s : standardFields) {
			soString += ', ' + s + '=' + so.get(s);
		}
		for (String s : customFields) {
			soString += ', ' + s + '=' + so.get(s);
		}
		if (doDebug) {
			System.debug(soString);
		}
		return soString;
	}

	/**
	 * @description          Given an SObject and a field, fill it
	 *
	 * @param sobj           The SObject record
	 * @param entity         The name of the SObject (its type)
	 * @param field          The field to populate/update
	 */
	private static void populateField(SObject sobj, String entity, String field) {
		Set<String> fields = new Set<String>();
		fields.add(field);
		populateFields(sobj, entity, fields);
	}

	/**
	 * @description          Given an SObject and fields, fill them all
	 *
	 * @param sobj           The SObject record
	 * @param entity         The name of the SObject (its type)
	 * @param fields         All fields to populate/update
	 */
	private static void populateFields(SObject sobj, String entity, Set<String> fields) {
		populateFields(sobj, entity, fields, false);
	}

	/**
	 * @description          Given an SObject and fields, fill them
	 *
	 * @param sobj           The SObject record
	 * @param entity         The name of the SObject (its type)
	 * @param fields         All fields to populate/update
	 * @param setNullOrFalse If true, set field to null (or Boolean to false)
	 */
	private static void populateFields(SObject sobj, String entity, Set<String> fields, Boolean setNullOrFalse) {
		for (String field : fields) {
			Schema.DescribeFieldResult result = QuoteSyncUtil.getField(entity, field);
			sobj.put(field, QuoteSyncUtil.createValue(sobj, entity, field, result, setNullOrFalse));
		}
	}

	private static Opportunity createOpp() {
		return createOpp(false);
	}

	private static Opportunity createOpp(Boolean setNullOrFalse) {
		/* Pricebook2 standardPB = new Pricebook2(Id = getStandardPricebookId(), IsActive = true);
		 Database.update(standardPB, false); */

		Opportunity opp = new Opportunity(
			Name = 'test opp',
			Amount = 100,
			TotalOpportunityQuantity = 10,
			StageName = 'Prospecting',
			CloseDate = System.today(),
			Pricebook2Id = getStandardPricebookId(),
			AccountId = [SELECT Id FROM Account LIMIT 1]
			.Id
		);
		populateFields(opp, 'Opportunity', QuoteSyncUtil.getOppFields(), setNullOrFalse);

		QuoteSyncUtil.populateRequiredFields(opp);

		insert opp;
		return opp;
	}

	private static List<OpportunityLineItem> createOppLines(Opportunity opp, Integer num) {
		return createOppLines(opp, num, false, false);
	}

	private static List<OpportunityLineItem> createOppLines(Opportunity opp, Integer num, Boolean unique, Boolean setNullOrFalse) {
		List<OpportunityLineItem> olis = new List<OpportunityLineItem>();
		PricebookEntry currPbe = [SELECT Id FROM PricebookEntry LIMIT 1];
		List<Product2> prodsToInsert = new List<Product2>();
		List<PricebookEntry> pbesToInsert = new List<PricebookEntry>();
		for (Integer i = 1; i <= num; i++) {
			if (unique) {
				Product2 p = new Product2(Name = 'test product ' + i, IsActive = true);
				prodsToInsert.add(p);
			}
		}
		insert prodsToInsert;
		for (Integer i = 1; i <= num; i++) {
			if (unique) {
				currPbe = new PricebookEntry(Pricebook2Id = opp.Pricebook2Id, Product2Id = prodsToInsert[i - 1].Id, IsActive = true, UnitPrice = 10);
				pbesToInsert.add(currPbe);
			}
		}
		insert pbesToInsert;
		for (Integer i = 1; i <= num; i++) {
			OpportunityLineItem oli = new OpportunityLineItem(
				OpportunityId = opp.Id,
				UnitPrice = i * 10,
				Quantity = i,
				Discount = i,
				ServiceDate = System.today(),
				PricebookEntryId = currPbe.Id
			);
			populateFields(oli, 'OpportunityLineItem', QuoteSyncUtil.getOppLineFields(), setNullOrFalse);

			QuoteSyncUtil.populateRequiredFields(oli);

			olis.add(oli);
		}
		insert olis;
		return olis;
	}

	private static List<OpportunityLineItem> createOppLinesNoSync(Opportunity opp, Integer num) {
		List<OpportunityLineItem> olis = new List<OpportunityLineItem>();
		PricebookEntry currPbe = [SELECT Id FROM PricebookEntry LIMIT 1];
		for (Integer i = 1; i <= num; i++) {
			OpportunityLineItem oli = new OpportunityLineItem(
				OpportunityId = opp.Id,
				UnitPrice = i * 10,
				Quantity = i * 1,
				Discount = i * 1,
				ServiceDate = System.today(),
				PricebookEntryId = currPbe.Id
			);

			QuoteSyncUtil.populateRequiredFields(oli);

			olis.add(oli);
		}
		insert olis;
		return olis;
	}
	/**
	 * @description Given an Opportunity, create a Quote with a value in every standard and synced field
	 *
	 * @param opp   The parent Opportunity record
	 * @return      `Quote` The created record
	 */
	private static Quote createQuote(Opportunity opp) {
		return createQuote(opp, false);
	}

	/**
	 * @description          Given an Opportunity, create a Quote
	 *
	 * @param opp            The parent Opportunity record
	 * @param setNullOrFalse Put null in custom fields if true. Put a value if false.
	 * @return               `Quote` The created record
	 */
	private static Quote createQuote(Opportunity opp, Boolean setNullOrFalse) {
		Quote quote = new Quote(Name = 'test quote', OpportunityId = opp.Id, Pricebook2Id = opp.Pricebook2Id);
		populateFields(quote, 'Quote', QuoteSyncUtil.getQuoteFields(), setNullOrFalse);

		QuoteSyncUtil.populateRequiredFields(quote);

		insert quote;

		String quoteFields = QuoteSyncUtil.getQuoteFieldsString();
		//prettier-ignore
		String quoteQuery = 'SELECT Id, Name, OpportunityId, Pricebook2Id' + quoteFields + ' FROM Quote WHERE Id = \'' + quote.Id + '\'';
		quote = ((List<Quote>) Database.query(quoteQuery))[0];
		return quote;
	}

	private static List<QuoteLineItem> createQuoteLines(Quote quote, Integer num) {
		return createQuoteLines(quote, num, false, false);
	}

	private static List<QuoteLineItem> createQuoteLines(Quote quote, Integer num, Boolean unique, Boolean setNullOrFalse) {
		List<QuoteLineItem> qlis = new List<QuoteLineItem>();
		PricebookEntry currPbe = [SELECT Id FROM PricebookEntry LIMIT 1];
		List<Product2> prodsToInsert = new List<Product2>();
		List<PricebookEntry> pbesToInsert = new List<PricebookEntry>();
		for (Integer i = 1; i <= num; i++) {
			if (unique) {
				Product2 p = new Product2(Name = 'test product ' + i, IsActive = true);
				prodsToInsert.add(p);
			}
		}
		insert prodsToInsert;
		for (Integer i = 1; i <= num; i++) {
			if (unique) {
				currPbe = new PricebookEntry(Pricebook2Id = quote.Pricebook2Id, Product2Id = prodsToInsert[i - 1].Id, IsActive = true, UnitPrice = 10);
				pbesToInsert.add(currPbe);
			}
		}
		insert pbesToInsert;
		for (Integer i = 1; i <= num; i++) {
			QuoteLineItem qli = new QuoteLineItem(
				QuoteId = quote.Id,
				UnitPrice = i * 10,
				Quantity = i,
				Discount = i,
				ServiceDate = System.today(),
				PricebookEntryId = currPbe.Id
			);
			if (unique) {
				qli.PricebookEntryId = pbesToInsert[i - 1].Id;
			}
			populateFields(qli, 'QuoteLineItem', QuoteSyncUtil.getQuoteLineFields(), setNullOrFalse);

			QuoteSyncUtil.populateRequiredFields(qli);

			qlis.add(qli);
		}
		insert qlis;
		return qlis;
	}

	private static List<QuoteLineItem> createQuoteLinesNoSync(Quote quote, Integer num) {
		List<QuoteLineItem> qlis = new List<QuoteLineItem>();
		PricebookEntry currPbe = [SELECT Id FROM PricebookEntry LIMIT 1];
		for (Integer i = 1; i <= num; i++) {
			QuoteLineItem qli = new QuoteLineItem(
				QuoteId = quote.Id,
				UnitPrice = i * 10,
				Quantity = i * 1,
				Discount = i * 1,
				ServiceDate = System.today(),
				PricebookEntryId = currPbe.Id
			);

			QuoteSyncUtil.populateRequiredFields(qli);

			qlis.add(qli);
		}
		insert qlis;
		return qlis;
	}

	private static Opportunity updateOpp(Id oppId) {
		return updateOpp(oppId, false);
	}

	private static Opportunity updateOpp(Id oppId, Boolean updateNullOrFalse) {
		String oppFields = QuoteSyncUtil.getOppFieldsString();
		String oppQuery = 'SELECT Id' + oppFields + ' FROM Opportunity WHERE Id = \'' + oppId + '\'';

		Opportunity opp = ((List<Opportunity>) Database.query(oppQuery))[0];
		populateFields(opp, 'Opportunity', QuoteSyncUtil.getOppFields(), updateNullOrFalse);

		update opp;
		return opp;
	}

	/**
	 * @description             Re-fill `Quote` fields and updateOpp(oppId)
	 *
	 * @param quoteId           Quote Id
	 * @return                  `Quote` The updated Quote
	 * @see updateQuote[0]
	 * @see updateOpp[0]
	 */
	private static Quote updateQuote(Id quoteId) {
		return updateQuote(quoteId, false);
	}

	/**
	 * @description             Re-fill Quote fields and updateOpp(oppId)
	 *
	 * @param quoteId           Quote Id
	 * @param updateNullOrFalse
	 * @return                  `Quote` The updated Quote
	 * @see updateQuote[0]
	 * @see updateOpp[0]
	 */
	private static Quote updateQuote(Id quoteId, Boolean updateNullOrFalse) {
		String quoteFields = QuoteSyncUtil.getQuoteFieldsString();
		String quoteQuery = 'SELECT Id' + quoteFields + ' FROM Quote WHERE Id = \'' + quoteId + '\'';

		Quote quote = ((List<Quote>) Database.query(quoteQuery))[0];
		populateFields(quote, 'Quote', QuoteSyncUtil.getQuoteFields(), updateNullOrFalse);

		update quote;
		return quote;
	}

	private static List<OpportunityLineItem> updateOppLines(Id oppId) {
		return updateOppLines(oppId, true, true);
	}

	/**
	 * @description Update only standard fields on `OpportunityLineItem` records
	 *
	 * @param oppId Opportunity Id
	 * @return      `List<OpportunityLineItem>` Updated Opportunity Product records
	 */
	private static List<OpportunityLineItem> updateOppLinesStdSyncFields(Id oppId) {
		return updateOppLines(oppId, true, false);
	}

	/**
	 * @description Update only custom fields on `OpportunityLineItem` records
	 *
	 * @param oppId Opportunity Id
	 * @return      `List<OpportunityLineItem>` Updated Opportunity Product records
	 */
	private static List<OpportunityLineItem> updateOppLinesCustomSyncFields(Id oppId) {
		return updateOppLines(oppId, false, true);
	}

	/**
	 * @description           Update all standard and synced fields on `OpportunityLineItem` records and put a value in each field
	 *
	 * @param oppId           OpportunityId
	 * @param stdSyncField    Update standard fields?
	 * @param customSyncField Update custom sync fields?
	 * @return                `List<OpportunityLineItem>` Updated Opportunity Product records
	 */
	private static List<OpportunityLineItem> updateOppLines(Id oppId, Boolean stdSyncField, Boolean customSyncField) {
		return updateOppLines(oppId, stdSyncField, customSyncField, false);
	}

	/**
	 * @description             Update fields on `OpportunityLineItem` records
	 *
	 * @param oppId             OpportunityId
	 * @param stdSyncField      Update standard fields?
	 * @param customSyncField   Update custom sync fields?
	 * @param updateNullOrFalse Put null in custom fields if true. Put values if false.
	 * @return                  `List<OpportunityLineItem>` Updated Opportunity Product records
	 */
	private static List<OpportunityLineItem> updateOppLines(Id oppId, Boolean stdSyncField, Boolean customSyncField, Boolean updateNullOrFalse) {
		String oliFields = QuoteSyncUtil.getOppLineFieldsString();
		//prettier-ignore
		String oliQuery = 'SELECT Id, UnitPrice, Quantity, Discount, ServiceDate, SortOrder' + oliFields + ' FROM OpportunityLineItem WHERE OpportunityId  = \'' + oppId + '\'';
		List<OpportunityLineItem> olis = Database.query(oliQuery);

		for (OpportunityLineItem oli : olis) {
			if (stdSyncField) {
				oli.UnitPrice += 1;
				oli.Quantity += 1;
				oli.Discount += 1;
				oli.ServiceDate = oli.ServiceDate.addDays(1);
			}

			if (customSyncField) {
				populateFields(oli, 'OpportunityLineItem', QuoteSyncUtil.getOppLineFields(), updateNullOrFalse);
			}
		}
		update olis;
		return olis;
	}

	/**
	 * @description             Update all standard and synced fields on `QuoteLineItem` records and put a value in each field
	 *
	 * @param quoteId           Quote Id
	 * @return                `List<QuoteLineItem>` Updated Opportunity Product records
	 */
	private static List<QuoteLineItem> updateQuoteLines(Id quoteId) {
		return updateQuoteLines(quoteId, true, true);
	}
	/**
	 * @description             Update all standard fields on `QuoteLineItem` records and put a value in each field
	 *
	 * @param quoteId           Quote Id
	 * @return                `List<QuoteLineItem>` Updated Opportunity Product records
	 */
	private static List<QuoteLineItem> updateQuoteLinesStdSyncFields(Id quoteId) {
		return updateQuoteLines(quoteId, true, false);
	}
	/**
	 * @description             Update custom sync fields on `QuoteLineItem` records and put a value in each field
	 *
	 * @param quoteId             Quote Id
	 * @return                  `List<QuoteLineItem>` Updated Quote Line Item records
	 */
	private static List<QuoteLineItem> updateQuoteLinesCustomSyncFields(Id quoteId) {
		return updateQuoteLines(quoteId, false, true);
	}
	/**
	 * @description             Update fields on `QuoteLineItem` records and put a value in each field
	 *
	 * @param quoteId             Quote Id
	 * @param stdSyncField      Update standard fields?
	 * @param customSyncField   Update custom sync fields?
	 * @return                  `List<QuoteLineItem>` Updated Quote Line Item records
	 */
	private static List<QuoteLineItem> updateQuoteLines(Id quoteId, Boolean stdSyncField, Boolean customSyncField) {
		return updateQuoteLines(quoteId, stdSyncField, customSyncField, false);
	}

	/**
	 * @description             Update fields on `QuoteLineItem` records
	 *
	 * @param quoteId             Quote Id
	 * @param stdSyncField      Update standard fields?
	 * @param customSyncField   Update custom sync fields?
	 * @param updateNullOrFalse Put null in fields if true. Put values if false.
	 * @return                  `List<QuoteLineItem>` Updated Quote Line Item records
	 */
	private static List<QuoteLineItem> updateQuoteLines(Id quoteId, Boolean stdSyncField, Boolean customSyncField, Boolean updateNullOrFalse) {
		String qliFields = QuoteSyncUtil.getQuoteLineFieldsString();
		//prettier-ignore
		String qliQuery = 'SELECT Id, UnitPrice, Quantity, Discount, ServiceDate, SortOrder' + qliFields + ' FROM QuoteLineItem WHERE QuoteId = \'' + quoteId + '\'';
		List<QuoteLineItem> qlis = Database.query(qliQuery);

		for (QuoteLineItem qli : qlis) {
			if (stdSyncField) {
				qli.UnitPrice += 1;
				qli.Quantity += 1;
				qli.Discount += 1;
				qli.ServiceDate = qli.ServiceDate.addDays(1);
			}

			if (customSyncField) {
				populateFields(qli, 'QuoteLineItem', QuoteSyncUtil.getQuoteLineFields(), updateNullOrFalse);
			}
		}
		update qlis;
		return qlis;
	}

	private static Opportunity updateOppNoSync(Id oppId) {
		String oppQuery = 'SELECT Id, CloseDate from Opportunity WHERE Id = \'' + oppId + '\'';

		Opportunity opp = ((List<Opportunity>) Database.query(oppQuery))[0];
		opp.CloseDate = System.today();

		update opp;
		return opp;
	}

	private static Quote updateQuoteNoSync(Id quoteId) {
		String quoteQuery = 'SELECT Id, ExpirationDate from Quote WHERE Id = \'' + quoteId + '\'';

		Quote quote = ((List<Quote>) Database.query(quoteQuery))[0];
		quote.ExpirationDate = System.today();

		update quote;
		return quote;
	}

	private static List<OpportunityLineItem> updateOppLinesNoSync(Id oppId, String field) {
		String oliFields = QuoteSyncUtil.getOppLineFieldsString();
		//prettier-ignore
		String oliQuery = 'SELECT Id, ' + field + oliFields + ' FROM OpportunityLineItem WHERE OpportunityId  = \'' + oppId + '\'';
		if (field == null) {
			oliQuery = 'SELECT Id ' + oliFields + ' FROM OpportunityLineItem WHERE OpportunityId  = \'' + oppId + '\'';
		}

		List<OpportunityLineItem> olis = Database.query(oliQuery);

		if (field != null) {
			for (OpportunityLineItem oli : olis) {
				populateField(oli, 'OpportunityLineItem', field);
			}
			update olis;
		}
		return olis;
	}

	private static List<QuoteLineItem> updateQuoteLinesNoSync(Id quoteId, String field) {
		String qliFields = QuoteSyncUtil.getQuoteLineFieldsString();
		//prettier-ignore
		String qliQuery = 'SELECT Id, ' + field + qliFields + ' FROM QuoteLineItem WHERE QuoteId = \'' + quoteId + '\'';
		if (field == null) {
			//prettier-ignore
			qliQuery = 'SELECT Id ' + qliFields + ' FROM QuoteLineItem WHERE QuoteId = \'' + quoteId + '\'';
		}

		List<QuoteLineItem> qlis = (List<QuoteLineItem>) Database.query(qliQuery);

		if (field != null) {
			for (QuoteLineItem qli : qlis) {
				populateField(qli, 'QuoteLineItem', field);
			}
			update qlis;
		}
		return qlis;
	}

	/**
	 * @description   Set a specific Quote as the syncing quote
	 *
	 * @param oppId   Opportunity Id
	 * @param quoteId Quote Id (to set as syncing quote)
	 */
	private static void startSync(Id oppId, Id quoteId) {
		Opportunity opp = [SELECT Id, SyncedQuoteId FROM Opportunity WHERE Id = :oppId];
		opp.SyncedQuoteId = quoteId;
		update opp;
	}

	/**
	 * @description Set no Quote to synd with this Opportunity
	 *
	 * @param oppId Opportunity Id
	 */
	private static void stopSync(Id oppId) {
		Opportunity opp = [SELECT Id, SyncedQuoteId FROM Opportunity WHERE Id = :oppId];
		opp.SyncedQuoteId = null;
		update opp;
	}

	/**
	 * Create quote from `Opportunity`. Verify `Quote` sync fields are copied from opp.
	 */
	@isTest
	private static void testCreateQuote() {
		Test.startTest();
		Opportunity opp = createOpp();
		Quote quote = createQuote(opp);
		System.assert(assertQuoteNotSync(opp.Id, quote.Id, true));
	}

	/**
	 * Create quote from opp with `Opportunity Product`. Verify `Quote Line Item` sync fields are copied from `Opportunity Product`.
	 */
	@isTest
	private static void testCreateQuoteWithQuoteLine() {
		Test.startTest();
		Opportunity opp = createOpp();
		List<OpportunityLineItem> oppLines = createOppLines(opp, 2, false, false);
		System.assert(!oppLines.isEmpty());

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2, false, false);
		System.assert(!quoteLines.isEmpty());

		//FIXME: Cannot force picklist value to be different
		//System.assert(assertQuoteNotSync(opp.Id, quote.Id));
		//System.assert(assertQuoteLineNotSync(opp.Id, quote.Id));
	}

	/**
	 * Start sync from `Quote`. Verify opp fields are synced from `Quote`.
	 */
	@isTest
	private static void testStartSyncQuote() {
		Test.startTest();
		Opportunity opp = createOpp();
		Quote quote = createQuote(opp);

		quote = updateQuote(quote.Id);
		System.assert(assertQuoteNotSync(opp.Id, quote.Id));

		startSync(opp.Id, quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteFields(quote.Id, quote));
	}

	/**
	 * Start sync from `Quote`. Verify opp fields are synced from `Quote`.
	 */
	@isTest
	private static void testStartSyncQuoteSetNull() {
		Test.startTest();
		Opportunity opp = createOpp();
		Quote quote = createQuote(opp, true);

		startSync(opp.Id, quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteFields(quote.Id, quote));
	}

	/**
	 * Start sync from `Quote` with `Quote Line Item`. Verify `Opportunity Product` fields are synced from `Quote Line Item`.
	 */
	@isTest
	private static void testStartSyncWithQuoteLine() {
		Test.startTest();
		Opportunity opp = createOpp();
		List<OpportunityLineItem> oppLines = createOppLines(opp, 2);
		System.assert(!oppLines.isEmpty());

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2);

		quoteLines = updateQuoteLines(quote.Id);

		startSync(opp.Id, quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}

	/**
	 * Start sync from `Quote` with `Quote Line Item`. Verify `Opportunity Product` fields are synced from `Quote Line Item`.
	 */
	@isTest
	private static void testStartSyncWithQuoteLineSetNull() {
		Test.startTest();
		Opportunity opp = createOpp();
		//FIXME
		//List<OpportunityLineItem> oppLines = createOppLines(opp, 2);

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2, false, true);

		startSync(opp.Id, quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}

	/**
	 * Start sync from another quote. Verify opp and `Opportunity Product` fields are synced from new quote and `Quote Line Item`.
	 */
	@isTest
	private static void testStartSyncOtherQuote() {
		Test.startTest();
		Opportunity opp = createOpp();

		Quote quote1 = createQuote(opp);
		List<QuoteLineItem> quoteLines1 = createQuoteLines(quote1, 2);
		System.assert(!quoteLines1.isEmpty());
		Quote quote2 = createQuote(opp);
		List<QuoteLineItem> quoteLines2 = createQuoteLines(quote2, 2);
		System.assert(!quoteLines2.isEmpty());

		startSync(opp.Id, quote1.Id);

		Quote updatedQuote = updateQuote(quote2.Id);
		List<QuoteLineItem> quoteLines = updateQuoteLines(quote2.Id);

		startSync(opp.Id, quote2.Id);

		System.assert(assertQuoteSync(opp.Id, quote2.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote2.Id));

		System.assert(assertQuoteFields(quote2.Id, updatedQuote));
		System.assert(assertQuoteLineFields(quote2.Id, quoteLines));
	}

	/**
	 * Start sync from `Quote` with `Quote Line Items` create new `Opportunity Products` on `Opportunity`. Verify `Opportunity Product` fields are synced.
	 */
	@isTest
	private static void testStartSyncInsertOppLine() {
		Test.startTest();
		Opportunity opp = createOpp();

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2);

		startSync(opp.Id, quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}

	/**
	 * Start sync from `Quote` with `Quote Line Items` create new `Opportunity Products` on `Opportunity`. Verify `Opportunity Product` fields are synced.
	 */
	@isTest
	private static void testStartSyncInsertOppLineSetNull() {
		Test.startTest();
		Opportunity opp = createOpp();

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2, false, true);

		startSync(opp.Id, quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}

	/**
	 * Start sync from `Quote` with `Quote Line Items` update existing `Opportunity Products` on `Opportunity`. Verify `Opportunity Product` fields are synced.
	 */
	@isTest
	private static void testStartSyncUpdateOppLine() {
		Test.startTest();
		Opportunity opp = createOpp();
		List<OpportunityLineItem> oppLines = createOppLines(opp, 2);
		System.assert(!oppLines.isEmpty());

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2);
		quoteLines = updateQuoteLines(quote.Id);

		startSync(opp.Id, quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}

	/**
	 * Start sync from `Quote` with `Quote Line Items`. Update existing `Opportunity Products` on `Opportunity`. Verify `Opportunity Product` fields are synced.
	 */
	@isTest
	private static void testStartSyncUpdateOppLineSetNull() {
		Test.startTest();
		Opportunity opp = createOpp();
		//List<OpportunityLineItem> oppLines =
		createOppLines(opp, 2);

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2);
		quoteLines = updateQuoteLines(quote.Id, true, true, true);

		startSync(opp.Id, quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}

	/**
	 * Start sync from `Quote` with `Quote Line Items` that match existing `Opportunity Products` on `Opportunity`. Verify `Opportunity Product` fields are synced.
	 */
	@isTest
	private static void testStartSyncMatchOppLine1() {
		Integer numLine = 2;

		Opportunity opp = createOpp();

		QuoteSyncHandler.bypassAll();
		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, numLine);
		QuoteSyncHandler.clearAllBypasses();

		startSync(opp.Id, quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineFields(quote.Id, quoteLines));

		stopSync(opp.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineFields(quote.Id, quoteLines));

		quoteLines = updateQuoteLinesCustomSyncFields(quote.Id);

		printOppLines(opp.Id);
		printQuoteLines(quote.Id);

		startSync(opp.Id, quote.Id);

		printOppLines(opp.Id);
		printQuoteLines(quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}

	/**
	 * Start sync from `Quote` with `Quote Line Items` that match existing `Opportunity Products` on `Opportunity`. Verify `Opportunity Product` fields are synced.
	 */
	@isTest
	private static void testStartSyncMatchOppLine1a() {
		Integer numLine = 2;

		Opportunity opp = createOpp();

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, numLine);

		startSync(opp.Id, quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineFields(quote.Id, quoteLines));

		stopSync(opp.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineFields(quote.Id, quoteLines));

		updateOppLinesCustomSyncFields(opp.Id);

		printOppLines(opp.Id);
		printQuoteLines(quote.Id);

		startSync(opp.Id, quote.Id);

		printOppLines(opp.Id);
		printQuoteLines(quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}

	/**
	 * Start sync from `Quote` with `Quote Line Items` that match existing `Opportunity Products` on `Opportunity`. Verify `Opportunity Product` fields are synced.
	 */
	@isTest
	private static void testStartSyncMatchOppLine2() {
		Integer numLine = 2;

		Opportunity opp = createOpp();

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, numLine);

		startSync(opp.Id, quote.Id);
		stopSync(opp.Id);

		quoteLines = updateQuoteLinesStdSyncFields(quote.Id);

		startSync(opp.Id, quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}

	/**
	 * Start sync from `Quote` with `Quote Line Items` that match existing `Opportunity Products` on `Opportunity`. Verify `Opportunity Product` fields are synced.
	 */
	@isTest
	private static void testStartSyncMatchOppLine2a() {
		Integer numLine = 2;

		Opportunity opp = createOpp();

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, numLine);

		startSync(opp.Id, quote.Id);
		stopSync(opp.Id);

		updateOppLinesStdSyncFields(opp.Id);

		startSync(opp.Id, quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}

	/**
	 * Start sync from `Quote` with `Quote Line Items` that match existing `Opportunity Products` on `Opportunity`. Verify `Opportunity Product` fields are synced.
	 */
	@isTest
	private static void testStartSyncMatchOppLine3() {
		Integer numLine = 2;

		Opportunity opp = createOpp();

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, numLine);

		startSync(opp.Id, quote.Id);
		stopSync(opp.Id);

		quoteLines = updateQuoteLines(quote.Id);

		startSync(opp.Id, quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}

	/**
	 * Start sync from `Quote` with `Quote Line Items` that match existing `Opportunity Products` on `Opportunity`. Verify `Opportunity Product` fields are synced.
	 */
	@isTest
	private static void testStartSyncMatchOppLine3a() {
		Integer numLine = 2;

		Opportunity opp = createOpp();

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, numLine);

		startSync(opp.Id, quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineFields(quote.Id, quoteLines));

		stopSync(opp.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineFields(quote.Id, quoteLines));

		//FIXME
		//updateOppLines(opp.Id);

		printOppLines(opp.Id);
		printQuoteLines(quote.Id);

		startSync(opp.Id, quote.Id);

		printOppLines(opp.Id);
		printQuoteLines(quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}

	/**
	 * Start sync from `Quote` with `Quote Line Items` that match existing `Opportunity Products` on `Opportunity`. Verify `Opportunity Product` fields are synced.
	 */
	@isTest
	private static void testStartSyncMatchOppLine4() {
		Integer numLine = 2;

		Opportunity opp = createOpp();
		//List<OpportunityLineItem> oppLines =
		createOppLines(opp, numLine);

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, numLine);

		quoteLines = updateQuoteLinesCustomSyncFields(quote.Id);

		printOppLines(opp.Id);
		printQuoteLines(quote.Id);

		startSync(opp.Id, quote.Id);

		printOppLines(opp.Id);
		printQuoteLines(quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}

	/**
	 * Start sync from `Quote` with `Quote Line Items` that match existing `Opportunity Products` on `Opportunity`. Verify `Opportunity Product` fields are synced.
	 */
	@isTest
	private static void testStartSyncMatchOppLine4a() {
		Integer numLine = 2;

		Opportunity opp = createOpp();
		//List<OpportunityLineItem> oppLines =
		createOppLines(opp, numLine, true, false);

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, numLine, true, false);

		quoteLines = updateQuoteLinesCustomSyncFields(quote.Id);

		startSync(opp.Id, quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}

	/**
	 * Start sync from `Quote` with `Quote Line Items` that match existing `Opportunity Products` on `Opportunity`. Verify `Opportunity Product` fields are synced.
	 */
	@isTest
	private static void testStartSyncMatchOppLine5() {
		Integer numLine = 2;

		Opportunity opp = createOpp();
		//List<OpportunityLineItem> oppLines =
		createOppLines(opp, numLine);

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, numLine);

		quoteLines = updateQuoteLinesStdSyncFields(quote.Id);

		startSync(opp.Id, quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}

	/**
	 * Start sync from `Quote` with `Quote Line Items` that match existing `Opportunity Products` on `Opportunity`. Verify `Opportunity Product` fields are synced.
	 */
	@isTest
	private static void testStartSyncMatchOppLine6() {
		Integer numLine = 2;

		Opportunity opp = createOpp();
		//List<OpportunityLineItem> oppLines =
		createOppLines(opp, numLine);

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, numLine);

		quoteLines = updateQuoteLines(quote.Id);

		startSync(opp.Id, quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}

	/**
	 * Start sync from `Quote` with `Quote Line Items` that match existing `Opportunity Products` on `Opportunity`. Verify `Opportunity Product` fields are synced.
	 */
	@isTest
	private static void testStartSyncMatchOppLine7() {
		Integer numLine = 2;

		Opportunity opp = createOpp();
		Quote quote = createQuote(opp);

		// create quotelines first so trigger doesn't copy Boolean field value from opplines on create
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, numLine);

		createOppLines(opp, numLine);

		printOppLines(opp.Id);
		printQuoteLines(quote.Id);

		startSync(opp.Id, quote.Id);

		printOppLines(opp.Id);
		printQuoteLines(quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}

	/**
	 * Start sync from `Quote` with `Quote Line Items` that match existing `Opportunity Products` on `Opportunity`. Verify `Opportunity Product` fields are synced.
	 */
	@isTest
	private static void testStartSyncMatchOppLine7a() {
		Integer numLine = 2;

		Opportunity opp = createOpp();

		createOppLines(opp, numLine, true, false);

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, numLine, true, false);

		startSync(opp.Id, quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}

	/**
	 * Stop sync on verify no changeson `Opportunity` & `Opportunity Product`, quote & `Quote Line Item` fields.
	 */
	@isTest
	private static void testStopSync() {
		Test.startTest();
		Opportunity opp = createOpp();
		Quote quote = createQuote(opp);

		// create quotelines first so trigger doesn't copy Boolean field value from opplines on create
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2);
		List<OpportunityLineItem> oppLines = createOppLines(opp, 2);
		System.assert(!oppLines.isEmpty());

		startSync(opp.Id, quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertQuoteLineFields(quote.Id, quoteLines));

		stopSync(opp.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}

	/**
	 * Update `Opportunity` sync fields. Verify corresponding fields on `Quote` are updated..
	 */
	@isTest
	private static void testUpdateOppSync() {
		Test.startTest();
		Opportunity opp = createOpp();
		Quote quote = createQuote(opp);

		startSync(opp.Id, quote.Id);

		Test.stopTest();

		Opportunity updatedOpp = updateOpp(opp.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertOppFields(opp.Id, updatedOpp));
	}

	/**
	 * Update `Opportunity` sync fields. Verify corresponding fields on `Quote` are updated..
	 */
	@isTest
	private static void testUpdateOppSyncSetNull() {
		Test.startTest();
		Opportunity opp = createOpp();
		Quote quote = createQuote(opp);

		startSync(opp.Id, quote.Id);

		Test.stopTest();

		Opportunity updatedOpp = updateOpp(opp.Id, true);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertOppFields(opp.Id, updatedOpp));
	}

	/**
	 * Update `Opportunity Product` sync fields to null. Verify corresponding fields on `Quote Line Item` are updated..
	 */
	@isTest
	private static void testUpdateOppLineSyncSetNull() {
		Test.startTest();
		Opportunity opp = createOpp();

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2);
		System.assert(!quoteLines.isEmpty());

		startSync(opp.Id, quote.Id);

		//Opportunity updatedOpp = updateOpp(opp.Id);
		List<OpportunityLineItem> oppLines = updateOppLines(opp.Id, true, true, true);
		Test.stopTest();
		//System.assert(assertQuoteSync(opp.Id, quote.Id));
		//System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		//System.assert(assertOppFields(opp.Id, updatedOpp));
		System.assert(assertOppLineFields(opp.Id, oppLines));
	}

	/**
	 * Update `Opportunity Product` sync fields. Verify corresponding fields on `Quote Line Item` are updated..
	 */
	@isTest
	private static void testUpdateOppLineSync1() {
		Test.startTest();
		Opportunity opp = createOpp();

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2);
		System.assert(!quoteLines.isEmpty());

		startSync(opp.Id, quote.Id);

		Test.stopTest();

		//Opportunity updatedOpp = updateOpp(opp.Id);
		List<OpportunityLineItem> oppLines = updateOppLines(opp.Id);

		//System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		//System.assert(assertOppFields(opp.Id, updatedOpp));
		System.assert(assertOppLineFields(opp.Id, oppLines));
	}

	/**
	 * Update `Opportunity Product` standard fields. Verify corresponding fields on `Quote Line Item` are updated..
	 */
	@isTest
	private static void testUpdateOppLineSync2() {
		Test.startTest();
		Opportunity opp = createOpp();

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2);
		System.assert(!quoteLines.isEmpty());

		startSync(opp.Id, quote.Id);

		Test.stopTest();

		//Opportunity updatedOpp =
		updateOpp(opp.Id);
		List<OpportunityLineItem> oppLines = updateOppLinesStdSyncFields(opp.Id);

		//System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		//System.assert(assertOppFields(opp.Id, updatedOpp));
		System.assert(assertOppLineFields(opp.Id, oppLines));
	}

	/**
	 * Update `Opportunity Product` sync fields. Verify corresponding fields on `Quote Line Item` are updated..
	 */
	@isTest
	private static void testUpdateOppLineSync3() {
		Test.startTest();
		Opportunity opp = createOpp();

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2);
		System.assert(!quoteLines.isEmpty());

		startSync(opp.Id, quote.Id);

		Test.stopTest();

		//Opportunity updatedOpp =
		updateOpp(opp.Id);
		List<OpportunityLineItem> oppLines = updateOppLinesCustomSyncFields(opp.Id);

		//System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		//System.assert(assertOppFields(opp.Id, updatedOpp));
		System.assert(assertOppLineFields(opp.Id, oppLines));
	}

	/**
	 * Insert `Opportunity Product` with sync fields set. Verify corresponding fields on `Quote Line Item` are synced..
	 */
	@isTest
	private static void testInsertOppLineSync() {
		Test.startTest();
		Opportunity opp = createOpp();
		List<OpportunityLineItem> oppLines = createOppLines(opp, 2);

		Quote quote = createQuote(opp);

		startSync(opp.Id, quote.Id);

		//Opportunity updatedOpp =
		updateOpp(opp.Id);
		oppLines = createOppLines(opp, 2);

		//System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		//System.assert(assertOppFields(opp.Id, updatedOpp));
		System.assert(assertOppLineFields(opp.Id, oppLines));
	}

	/**
	 * Update `Quote` sync fields. Verify corresponding fieldson `Opportunity` are updated..
	 */
	@isTest
	private static void testUpdateQuoteSync() {
		Test.startTest();
		Opportunity opp = createOpp();
		Quote quote = createQuote(opp);

		startSync(opp.Id, quote.Id);

		Quote updatedQuote = updateQuote(quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteFields(quote.Id, updatedQuote));
	}

	/**
	 * Update `Quote` sync fields. Verify corresponding fieldson `Opportunity` are updated..
	 */
	@isTest
	private static void testUpdateQuoteSyncSetNull() {
		Test.startTest();
		Opportunity opp = createOpp();
		Quote quote = createQuote(opp);

		startSync(opp.Id, quote.Id);

		Quote updatedQuote = updateQuote(quote.Id, true);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteFields(quote.Id, updatedQuote));
	}

	/**
	 * Update `Quote Line Item` sync fields. Verify corresponding fields on `Opportunity Product` are updated..
	 */
	@isTest
	private static void testUpdateQuoteLineSync1() {
		Test.startTest();
		Opportunity opp = createOpp();

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2);
		System.assert(!quoteLines.isEmpty());

		startSync(opp.Id, quote.Id);

		//Quote updatedQuote =
		updateQuote(quote.Id);
		List<QuoteLineItem> updatedQuoteLines = updateQuoteLines(quote.Id);

		//System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		//System.assert(assertQuoteFields(quote.Id, updatedQuote));
		System.assert(assertQuoteLineFields(quote.Id, updatedQuoteLines));
	}

	/**
	 * Update `Quote Line Item` sync fields. Verify corresponding fields on `Opportunity Product` are updated..
	 */
	@isTest
	private static void testUpdateQuoteLineSync2() {
		Test.startTest();
		Opportunity opp = createOpp();

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2);
		System.assert(!quoteLines.isEmpty());

		startSync(opp.Id, quote.Id);

		//Quote updatedQuote =
		updateQuote(quote.Id);
		List<QuoteLineItem> updatedQuoteLines = updateQuoteLinesStdSyncFields(quote.Id);

		//System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		//System.assert(assertQuoteFields(quote.Id, updatedQuote));
		System.assert(assertQuoteLineFields(quote.Id, updatedQuoteLines));
	}

	/**
	 * Update `Quote Line Item` sync fields. Verify corresponding fields on `Opportunity Product` are updated..
	 */
	@isTest
	private static void testUpdateQuoteLineSync3() {
		Test.startTest();
		Opportunity opp = createOpp();

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2);
		System.assert(!quoteLines.isEmpty());

		startSync(opp.Id, quote.Id);

		//Quote updatedQuote =
		updateQuote(quote.Id);
		List<QuoteLineItem> updatedQuoteLines = updateQuoteLinesCustomSyncFields(quote.Id);

		//System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		//System.assert(assertQuoteFields(quote.Id, updatedQuote));
		System.assert(assertQuoteLineFields(quote.Id, updatedQuoteLines));
	}

	/**
	 * Update `Quote Line Item` sync fields. Verify corresponding fields on `Opportunity Product` are updated..
	 */
	@isTest
	private static void testUpdateQuoteLineSyncSetNull() {
		Test.startTest();
		Opportunity opp = createOpp();

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2);
		System.assert(!quoteLines.isEmpty());

		startSync(opp.Id, quote.Id);

		//Quote updatedQuote =
		updateQuote(quote.Id);
		List<QuoteLineItem> updatedQuoteLines = updateQuoteLines(quote.Id, true, true, true);

		Test.stopTest();

		//System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		//System.assert(assertQuoteFields(quote.Id, updatedQuote));
		System.assert(assertQuoteLineFields(quote.Id, updatedQuoteLines));
	}

	/**
	 * Insert `Quote Line Item` with sync fields. Verify corresponding fields on `Opportunity Product` are synced..
	 */
	@isTest
	private static void testInsertQuoteLineSync() {
		Test.startTest();
		Opportunity opp = createOpp();
		List<OpportunityLineItem> oppLines = createOppLines(opp, 2);
		System.assert(!oppLines.isEmpty());
		Quote quote = createQuote(opp);

		startSync(opp.Id, quote.Id);

		//Quote updatedQuote =
		updateQuote(quote.Id);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2);

		//System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		//System.assert(assertQuoteFields(quote.Id, updatedQuote));
		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}

	/**
	 * Update opp non-sync fields. Verify fields on `Quote` are not updated..
	 */
	@isTest
	private static void testUpdateOppNoSync() {
		Test.startTest();
		Opportunity opp = createOpp();
		Quote quote = createQuote(opp);

		startSync(opp.Id, quote.Id);

		updateOppNoSync(opp.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteFields(quote.Id, quote));
	}

	/**
	 * Update `Opportunity Product` non-sync fields. Verify fields on `Quote Line Item` are not updated..
	 */
	@isTest
	private static void testUpdateOppLineNoSync() {
		Test.startTest();
		Opportunity opp = createOpp();
		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2);
		System.assert(!quoteLines.isEmpty());

		startSync(opp.Id, quote.Id);

		// remove sync field
		String field = QuoteSyncUtil.removeQuoteLineField('description');

		List<OpportunityLineItem> oppLines = updateOppLinesNoSync(opp.Id, field);

		//System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertOppLineFields(opp.Id, oppLines));
	}

	/**
	 * Insert `Opportunity Product` without sync fields. Verify fields on `Quote Line Item` are synced..
	 */
	@isTest
	private static void testInsertOppLineNoSync() {
		Test.startTest();
		Opportunity opp = createOpp();
		Quote quote = createQuote(opp);

		startSync(opp.Id, quote.Id);

		List<OpportunityLineItem> oppLines = createOppLinesNoSync(opp, 2);

		//System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertOppLineFields(opp.Id, oppLines));
	}

	/**
	 * Update `Quote` non-sync fields. Verify corresponding fieldson `Opportunity` are not updated..
	 */
	@isTest
	private static void testUpdateQuoteNoSync() {
		Test.startTest();
		Opportunity opp = createOpp();
		Quote quote = createQuote(opp);

		startSync(opp.Id, quote.Id);

		updateQuoteNoSync(quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteFields(quote.Id, quote));
	}

	/**
	 * Update `Quote Line Item` non-sync fields. Verify corresponding fields on `Opportunity Product` are not updated..
	 */
	@isTest
	private static void testUpdateQuoteLineNoSync() {
		Test.startTest();
		Opportunity opp = createOpp();
		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2);
		System.assert(!quoteLines.isEmpty());

		startSync(opp.Id, quote.Id);

		// remove sync field
		QuoteSyncUtil.removeQuoteLineField('description');

		quoteLines = updateQuoteLinesNoSync(quote.Id, 'description');

		//System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}

	/**
	 * Insert `Quote Line Item` without sync fields. Verify corresponding fields on `Opportunity Product` are not synced..
	 */
	@isTest
	private static void testInsertQuoteLineNoSync() {
		Test.startTest();
		Opportunity opp = createOpp();
		Quote quote = createQuote(opp);

		startSync(opp.Id, quote.Id);

		Test.stopTest();

		List<QuoteLineItem> quoteLines = createQuoteLinesNoSync(quote, 2);

		//System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}

	/**
	 * Update `Opportunity` when it's is not synced with `Quote`.
	 */
	@isTest
	private static void testUpdateOppNotSync() {
		Test.startTest();
		Opportunity opp = createOpp();
		Quote quote = createQuote(opp);

		Opportunity updatedOpp = updateOpp(opp.Id);

		Test.stopTest();

		System.assert(assertQuoteNotSync(opp.Id, quote.Id));
		System.assert(assertOppFields(opp.Id, updatedOpp));
	}

	/**
	 * Update `Quote` when it's not synced with `Opportunity`.
	 */
	@isTest
	private static void testUpdateQuoteNotSync() {
		Test.startTest();
		Opportunity opp = createOpp();
		Quote quote = createQuote(opp);

		Quote updatedQuote = updateQuote(quote.Id);

		Test.stopTest();

		System.assert(assertQuoteNotSync(opp.Id, quote.Id));
		System.assert(assertQuoteFields(quote.Id, updatedQuote));
	}

	/**
	 * Update `Opportunity Product` when opp not synced with `Quote`.
	 */
	@isTest
	private static void testUpdateOppLineNotSync() {
		Test.startTest();
		Opportunity opp = createOpp();
		List<OpportunityLineItem> oppLines = createOppLines(opp, 2);
		System.assert(!oppLines.isEmpty());

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2);
		System.assert(!quoteLines.isEmpty());

		//Opportunity updatedOpp =
		updateOpp(opp.Id);
		List<OpportunityLineItem> updatedOppLines = updateOppLines(opp.Id);

		Test.stopTest();

		//System.assert(assertQuoteNotSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineNotSync(opp.Id, quote.Id));

		//System.assert(assertOppFields(opp.Id, updatedOpp));
		System.assert(assertOppLineFields(opp.Id, updatedOppLines));
	}

	/**
	 * Update `Quote Line Item` when `Quote` not synced with `Opportunity`.
	 */
	@isTest
	private static void testUpdateQuoteLineNotSync() {
		Test.startTest();
		Opportunity opp = createOpp();
		List<OpportunityLineItem> oppLines = createOppLines(opp, 2);
		System.assert(!oppLines.isEmpty());

		Quote quote = createQuote(opp);
		//List<QuoteLineItem> quoteLines =
		createQuoteLines(quote, 2);

		Test.stopTest();

		//Quote updatedQuote =
		updateQuote(quote.Id);
		List<QuoteLineItem> updatedQuoteLines = updateQuoteLines(quote.Id);

		//System.assert(assertQuoteNotSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineNotSync(opp.Id, quote.Id));

		//System.assert(assertQuoteFields(quote.Id, updatedQuote));
		System.assert(assertQuoteLineFields(quote.Id, updatedQuoteLines));
	}

	/**
	 * Insert `Opportunity Product` when opp is not synced with `Quote`
	 */
	@isTest
	private static void testInsertOppLineNotSync() {
		Test.startTest();
		Opportunity opp = createOpp();
		List<OpportunityLineItem> oppLines = createOppLines(opp, 2);

		Quote quote = createQuote(opp);

		oppLines.addAll(createOppLines(opp, 2));
		Test.stopTest();

		//System.assert(assertQuoteNotSync(opp.Id, quote.Id, true));
		System.assert(assertQuoteLineNotSync(opp.Id, quote.Id, true));

		System.assert(assertOppLineFields(opp.Id, oppLines));
	}

	/**
	 * Insert `Quote Line Item` when `Quote` is not synced with `Opportunity`.
	 */
	@isTest
	private static void testInsertQuoteLineNotSync() {
		Test.startTest();
		Opportunity opp = createOpp();

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2);

		//System.assert(assertQuoteNotSync(opp.Id, quote.Id, true));
		System.assert(assertQuoteLineNotSync(opp.Id, quote.Id, true));

		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}

	/**
	 * Create duplicate `Opportunity Product` with from same `Price Book Entry`
	 */
	@isTest
	private static void testCreateDuplicateOppLine() {
		Test.startTest();
		Opportunity opp = createOpp();

		Quote quote = createQuote(opp);

		startSync(opp.Id, quote.Id);

		Test.stopTest();

		List<OpportunityLineItem> oppLines = createOppLines(opp, 2, false, false);

		//System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertOppLineFields(opp.Id, oppLines));
	}

	/**
	 * Create duplicate `Quote Line Item` with from same `Price Book Entry`
	 */
	@isTest
	private static void testCreateDuplicateQuoteLine() {
		Test.startTest();
		Opportunity opp = createOpp();

		Quote quote = createQuote(opp);

		startSync(opp.Id, quote.Id);

		Test.stopTest();

		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2, false, false);
		System.assert(!quoteLines.isEmpty());

		//System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}

	/**
	 * Update duplicate `Opportunity Product` with from same `Price Book Entry`
	 */
	@isTest
	private static void testUpdateDuplicateOppLine() {
		Test.startTest();
		Opportunity opp = createOpp();

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2, false, false);
		System.assert(!quoteLines.isEmpty());

		startSync(opp.Id, quote.Id);

		Opportunity updatedOpp = updateOpp(opp.Id);

		Test.stopTest();
		List<OpportunityLineItem> oppLines = updateOppLines(opp.Id);

		//System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertOppFields(opp.Id, updatedOpp));

		System.assert(assertOppLineFields(opp.Id, oppLines));
	}

	/**
	 * Update duplicate `Quote Line Item` with from same `Price Book Entry`
	 */
	@isTest
	private static void testUpdateDuplicateQuoteLine() {
		Test.startTest();
		Opportunity opp = createOpp();

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2, false, false);

		startSync(opp.Id, quote.Id);

		Test.stopTest();

		quote = updateQuote(quote.Id);
		quoteLines = updateQuoteLines(quote.Id);

		//System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		//System.assert(assertQuoteFields(quote.Id, quote));
		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}
}