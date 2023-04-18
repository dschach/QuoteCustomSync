/**
 * Test class for Quote/Opportunity sync
 *
 * @author {@link [Salesforce Labs](https://github.com/SalesforceLabs)}
 * @since  2014
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
private class QuoteSyncTestSuite {
	/**
	 * Store the standard pricebook Id
	 */
	private static Id standardPricebookId;

	/**
	 * Memoized version of `Test.getStandardPricebookId()` so we call it once and not again in a test
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
	static void makeData() {
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

			// Boolean field is equal even not sync because of trigger on Quote creation copy values from Opp
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
		String qliQuery = 'SELECT Id, QuoteId, PricebookEntryId, UnitPrice, Quantity, Discount, ServiceDate, SortOrder' + qliFields + ' FROM QuoteLineItem WHERE QuoteId = \'' + quoteId + '\'';
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
					//prettier-ignore
					String oliValues = '#################   OppLine ' + n +': ' + oli.PricebookEntryId + ', ' + oli.UnitPrice + ', ' + oli.Quantity +
						', ' + oli.Discount + ', ' + oli.ServiceDate;
					for (String oliField : QuoteSyncUtil.getOppLineFields()) {
						oliValues += ', ' + oli.get(oliField);
					}

					System.debug(oliValues);
					errorMsg += oliValues + '\n';
				}

				n = 0;
				for (QuoteLineItem qli : qlis) {
					n++;
					//prettier-ignore
					String qliValues ='#################   QuoteLine ' + n + ': ' + qli.PricebookEntryId + ', ' + qli.UnitPrice + ', ' +qli.Quantity + ', ' + qli.Discount + ', ' + qli.ServiceDate;
					for (String qliField : QuoteSyncUtil.getQuoteLineFields()) {
						qliValues += ', ' + qli.get(qliField);
					}

					System.debug(qliValues);
					errorMsg += qliValues + '\n';
				}
			}
			//prettier-ignore
			System.assertEquals(olis.size(), qlis.size(), 'Number of opp lines: ' + olis.size() + ' does not match number of quote lines: ' + qlis.size() + '\n' + errorMsg);
		}

		for (QuoteLineItem qli : qlis) {
			Boolean match = false;
			for (OpportunityLineItem oli : olis) {
				if (
					oli.PricebookEntryId == qli.PricebookEntryId &&
					oli.UnitPrice == qli.UnitPrice &&
					oli.Quantity == qli.Quantity &&
					oli.Discount == qli.Discount &&
					oli.ServiceDate == qli.ServiceDate &&
					oli.SortOrder == qli.SortOrder
				) {
					for (String qliField : QuoteSyncUtil.getQuoteLineFields()) {
						String oliField = QuoteSyncUtil.getQuoteLineFieldMapTo(qliField);
						Object oliValue = oli.get(oliField);
						Object qliValue = qli.get(qliField);

						// Boolean field is equal even not sync because of trigger on QuoteLineItem creation copy values from OppLineItem
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
		System.debug(olis);

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
	 * Debug method for use in checking unit tests. Currently not used.
	 *
	 * @param oppId The `Opportunity` to debug
	 * @example
	 * printOpp(opp.Id);
	 */
	private static void printOpp(Id oppId) {
		String oppFields = QuoteSyncUtil.getOppFieldsString();
		String oppQuery = 'SELECT Id, SyncedQuoteId' + oppFields + ' FROM Opportunity WHERE Id = \'' + oppId + '\'';

		Opportunity opp = ((List<Opportunity>) Database.query(oppQuery))[0];
		String oppValues = 'OpportunityId: ' + opp.Id;

		for (String oppField : QuoteSyncUtil.getOppFields()) {
			oppValues = ', ' + opp.get(oppField);
		}

		//System.debug(oppValues);
	}

	/**
	 * Debug method for use in checking unit tests. Currently not used.
	 *
	 * @param quoteId The `Quote` to debug
	 * @example
	 * printQuote(quote.Id);
	 */
	private static void printQuote(Id quoteId) {
		String quoteFields = QuoteSyncUtil.getQuoteFieldsString();
		String quoteQuery = 'SELECT Id, OpportunityId' + quoteFields + ' FROM Quote WHERE Id = \'' + quoteId + '\'';

		Quote quote = ((List<Quote>) Database.query(quoteQuery))[0];
		String quoteValues = 'QuoteId: ' + quote.Id;

		for (String quoteField : QuoteSyncUtil.getQuoteFields()) {
			quoteValues = ', ' + quote.get(quoteField);
		}

		//System.debug(quoteValues);
	}

	/**
	 * Debug method for use in checking unit tests. Currently not used.
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
			//prettier-ignore
			String oliValues ='*******************   OppLine ' + n + ': ' + oli.PricebookEntryId + ', ' + oli.UnitPrice + ', ' + oli.Quantity + ', ' + oli.Discount + ', ' + oli.ServiceDate;
			for (String oliField : QuoteSyncUtil.getOppLineFields()) {
				oliValues += ', ' + oli.get(oliField);
			}

			System.debug(oliValues);
		}
	}

	/**
	 * Debug method for use in checking unit tests. Currently not used.
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
			//prettier-ignore
			String qliValues ='*******************   QuoteLine ' + n + ': ' + qli.PricebookEntryId + ', ' + qli.UnitPrice + ', ' + qli.Quantity + ', ' + qli.Discount + ', ' + qli.ServiceDate;
			for (String qliField : QuoteSyncUtil.getQuoteLineFields()) {
				qliValues += ', ' + qli.get(qliField);
			}

			System.debug(qliValues);
		}
	}

	private static void populateField(SObject sobj, String entity, String field) {
		List<String> fields = new List<String>();
		fields.add(field);
		populateFields(sobj, entity, fields);
	}

	private static void populateFields(SObject sobj, String entity, List<String> fields) {
		populateFields(sobj, entity, fields, false);
	}

	private static void populateFields(SObject sobj, String entity, Set<String> fields, Boolean setNullOrFalse) {
		for (String field : fields) {
			Schema.DescribeFieldResult result = QuoteSyncUtil.getField(entity, field);
			sobj.put(field, QuoteSyncUtil.createValue(sobj, entity, field, result, setNullOrFalse));
		}
	}

	private static void populateFields(SObject sobj, String entity, List<String> fields, Boolean setNullOrFalse) {
		for (String field : fields) {
			Schema.DescribeFieldResult result = QuoteSyncUtil.getField(entity, field);
			sobj.put(field, QuoteSyncUtil.createValue(sobj, entity, field, result, setNullOrFalse));
		}
	}

	private static Opportunity createOpp() {
		return createOpp(false);
	}

	private static Opportunity createOpp(Boolean setNullOrFalse) {
		Pricebook2 standardPB = new Pricebook2(Id = getStandardPricebookId(), IsActive = true);
		Database.update(standardPB, false);

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

	private static Quote createQuote(Opportunity opp) {
		return createQuote(opp, false);
	}

	private static Quote createQuote(Opportunity opp, Boolean setNullOrFalse) {
		Quote quote = new Quote(Name = 'test quote', OpportunityId = opp.Id, Pricebook2Id = opp.Pricebook2Id);
		populateFields(quote, 'Quote', QuoteSyncUtil.getQuoteFields(), setNullOrFalse);
		//System.debug('quote ' + quote);

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

	private static Quote updateQuote(Id quoteId) {
		return updateQuote(quoteId, false);
	}

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

	private static List<OpportunityLineItem> updateOppLinesStdSyncFields(Id oppId) {
		return updateOppLines(oppId, true, false);
	}

	private static List<OpportunityLineItem> updateOppLinesCustomSyncFields(Id oppId) {
		return updateOppLines(oppId, false, true);
	}

	private static List<OpportunityLineItem> updateOppLines(Id oppId, Boolean stdSyncField, Boolean customSyncField) {
		return updateOppLines(oppId, stdSyncField, customSyncField, false);
	}

	private static List<OpportunityLineItem> updateOppLines(Id oppId, Boolean stdSyncField, Boolean customSyncField, Boolean updateNullOrFalse) {
		String oliFields = QuoteSyncUtil.getOppLineFieldsString();
		//System.debug('oliFields: ' + oliFields);
		//prettier-ignore
		String oliQuery = 'SELECT Id, UnitPrice, Quantity, Discount, ServiceDate, SortOrder' + oliFields + ' FROM OpportunityLineItem WHERE OpportunityId  = \'' + oppId + '\'';
		//System.debug('oliQuery: ' + oliQuery);
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

	private static List<QuoteLineItem> updateQuoteLines(Id quoteId) {
		return updateQuoteLines(quoteId, true, true);
	}

	private static List<QuoteLineItem> updateQuoteLinesStdSyncFields(Id quoteId) {
		return updateQuoteLines(quoteId, true, false);
	}

	private static List<QuoteLineItem> updateQuoteLinesCustomSyncFields(Id quoteId) {
		return updateQuoteLines(quoteId, false, true);
	}

	private static List<QuoteLineItem> updateQuoteLines(Id quoteId, Boolean stdSyncField, Boolean customSyncField) {
		return updateQuoteLines(quoteId, stdSyncField, customSyncField, false);
	}

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

		List<QuoteLineItem> qlis = Database.query(qliQuery);

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
	 * Create quote from opp. Verify quote sync fields are copied from opp
	 */
	@isTest
	private static void testCreateQuote() {
		Opportunity opp = createOpp();
		Quote quote = createQuote(opp);
		System.assert(assertQuoteNotSync(opp.Id, quote.Id, true));
	}

	/**
	 * Create quote from opp with opp line. Verify quote line sync fields are copied from opp line
	 */
	@isTest
	private static void testCreateQuoteWithQuoteLine() {
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
	 * Start sync from quote. Verify opp fields are sync'ed from quote
	 */
	@isTest
	private static void testStartSyncQuote() {
		Opportunity opp = createOpp();
		Quote quote = createQuote(opp);

		quote = updateQuote(quote.Id);
		System.assert(assertQuoteNotSync(opp.Id, quote.Id));

		startSync(opp.Id, quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteFields(quote.Id, quote));
	}

	/**
	 * Start sync from quote. Verify opp fields are sync'ed from quote
	 */
	@isTest
	private static void testStartSyncQuoteSetNull() {
		Opportunity opp = createOpp();
		Quote quote = createQuote(opp, true);

		startSync(opp.Id, quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteFields(quote.Id, quote));
	}

	/**
	 * Start sync from quote with quote line. Verify opp line fields are sync'ed from quote line
	 */
	@isTest
	private static void testStartSyncWithQuoteLine() {
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
	 * Start sync from quote with quote line. Verify opp line fields are sync'ed from quote line
	 */
	@isTest
	private static void testStartSyncWithQuoteLineSetNull() {
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
	 * Start sync from another quote. Verify opp and opp line fields are sync'ed from new quote and quote line
	 */
	@isTest
	private static void testStartSyncOtherQuote() {
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
	 * Start sync from quote with quote lines create new opp lines on opp.  Verify opp line fields are sync'ed
	 */
	@isTest
	private static void testStartSyncInsertOppLine() {
		Opportunity opp = createOpp();

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2);

		startSync(opp.Id, quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}

	/**
	 * Start sync from quote with quote lines create new opp lines on opp.  Verify opp line fields are sync'ed
	 */
	@isTest
	private static void testStartSyncInsertOppLineSetNull() {
		Opportunity opp = createOpp();

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2, false, true);

		startSync(opp.Id, quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}

	/**
	 * Start sync from quote with quote lines update existing opp lines on opp.  Verify opp line fields are sync'ed
	 */
	@isTest
	private static void testStartSyncUpdateOppLine() {
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
	 * Start sync from quote with quote lines update existing opp lines on opp.  Verify opp line fields are sync'ed
	 */
	@isTest
	private static void testStartSyncUpdateOppLineSetNull() {
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
	 * Start sync from quote with quote lines that match existing opp lines on opp.  Verify opp line fields are sync'ed
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

		//printOppLines(opp.Id);
		//printQuoteLines(quote.Id);

		startSync(opp.Id, quote.Id);

		//printOppLines(opp.Id);
		//printQuoteLines(quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}

	/**
	 * Start sync from quote with quote lines that match existing opp lines on opp.  Verify opp line fields are sync'ed
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

		//printOppLines(opp.Id);
		//printQuoteLines(quote.Id);

		startSync(opp.Id, quote.Id);

		//printOppLines(opp.Id);
		//printQuoteLines(quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}

	/**
	 * Start sync from quote with quote lines that match existing opp lines on opp.  Verify opp line fields are sync'ed
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
	 * Start sync from quote with quote lines that match existing opp lines on opp.  Verify opp line fields are sync'ed
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
	 * Start sync from quote with quote lines that match existing opp lines on opp.  Verify opp line fields are sync'ed
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
	 * Start sync from quote with quote lines that match existing opp lines on opp.  Verify opp line fields are sync'ed
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

		//printOppLines(opp.Id);
		//printQuoteLines(quote.Id);

		startSync(opp.Id, quote.Id);

		//printOppLines(opp.Id);
		//printQuoteLines(quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}

	/**
	 * Start sync from quote with quote lines that match existing opp lines on opp.  Verify opp line fields are sync'ed
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

		//printOppLines(opp.Id);
		//printQuoteLines(quote.Id);

		startSync(opp.Id, quote.Id);

		//printOppLines(opp.Id);
		//printQuoteLines(quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}

	/**
	 * Start sync from quote with quote lines that match existing opp lines on opp.  Verify opp line fields are sync'ed
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
	 * Start sync from quote with quote lines that match existing opp lines on opp.  Verify opp line fields are sync'ed
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
	 * Start sync from quote with quote lines that match existing opp lines on opp.  Verify opp line fields are sync'ed
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
	 * Start sync from quote with quote lines that match existing opp lines on opp.  Verify opp line fields are sync'ed
	 */
	@isTest
	private static void testStartSyncMatchOppLine7() {
		Integer numLine = 2;

		Opportunity opp = createOpp();
		Quote quote = createQuote(opp);

		// create quotelines first so trigger doesn't copy Boolean field value from opplines on create
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, numLine);
		//List<OpportunityLineItem> oppLines =
		createOppLines(opp, numLine);

		//printOppLines(opp.Id);
		//printQuoteLines(quote.Id);

		startSync(opp.Id, quote.Id);

		//printOppLines(opp.Id);
		//printQuoteLines(quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}

	/**
	 * Start sync from quote with quote lines that match existing opp lines on opp.  Verify opp line fields are sync'ed
	 */
	@isTest
	private static void testStartSyncMatchOppLine7a() {
		Integer numLine = 2;

		Opportunity opp = createOpp();
		//List<OpportunityLineItem> oppLines =
		createOppLines(opp, numLine, true, false);

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, numLine, true, false);

		startSync(opp.Id, quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}

	/**
	 * Stop sync on verify no changes on opp & opp line, quote & quote line fields
	 */
	@isTest
	private static void testStopSync() {
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
	 * Update opp sync fields.  Verify corresponding fields on quote are updated.
	 */
	@isTest
	private static void testUpdateOppSync() {
		Opportunity opp = createOpp();
		Quote quote = createQuote(opp);

		startSync(opp.Id, quote.Id);

		Opportunity updatedOpp = updateOpp(opp.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertOppFields(opp.Id, updatedOpp));
	}

	/**
	 * Update opp sync fields.  Verify corresponding fields on quote are updated.
	 */
	@isTest
	private static void testUpdateOppSyncSetNull() {
		Opportunity opp = createOpp();
		Quote quote = createQuote(opp);

		startSync(opp.Id, quote.Id);

		Opportunity updatedOpp = updateOpp(opp.Id, true);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertOppFields(opp.Id, updatedOpp));
	}

	/**
	 * Update opp line sync fields.  Verify corresponding fields on quote line are updated.
	 */
	@isTest
	private static void testUpdateOppLineSyncSetNull() {
		Opportunity opp = createOpp();

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2);
		System.assert(!quoteLines.isEmpty());

		startSync(opp.Id, quote.Id);

		Opportunity updatedOpp = updateOpp(opp.Id);
		List<OpportunityLineItem> oppLines = updateOppLines(opp.Id, true, true, true);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertOppFields(opp.Id, updatedOpp));
		System.assert(assertOppLineFields(opp.Id, oppLines));
	}

	/**
	 * Update opp line sync fields.  Verify corresponding fields on quote line are updated.
	 */
	@isTest
	private static void testUpdateOppLineSync1() {
		Opportunity opp = createOpp();

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2);
		System.assert(!quoteLines.isEmpty());

		startSync(opp.Id, quote.Id);

		Opportunity updatedOpp = updateOpp(opp.Id);
		List<OpportunityLineItem> oppLines = updateOppLines(opp.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertOppFields(opp.Id, updatedOpp));
		System.assert(assertOppLineFields(opp.Id, oppLines));
	}

	/**
	 * Update opp line sync fields.  Verify corresponding fields on quote line are updated.
	 */
	@isTest
	private static void testUpdateOppLineSync2() {
		Opportunity opp = createOpp();

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2);
		System.assert(!quoteLines.isEmpty());

		startSync(opp.Id, quote.Id);

		Opportunity updatedOpp = updateOpp(opp.Id);
		List<OpportunityLineItem> oppLines = updateOppLinesStdSyncFields(opp.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertOppFields(opp.Id, updatedOpp));
		System.assert(assertOppLineFields(opp.Id, oppLines));
	}

	/**
	 * Update opp line sync fields.  Verify corresponding fields on quote line are updated.
	 */
	@isTest
	private static void testUpdateOppLineSync3() {
		Opportunity opp = createOpp();

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2);
		System.assert(!quoteLines.isEmpty());

		startSync(opp.Id, quote.Id);

		Opportunity updatedOpp = updateOpp(opp.Id);
		List<OpportunityLineItem> oppLines = updateOppLinesCustomSyncFields(opp.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertOppFields(opp.Id, updatedOpp));
		System.assert(assertOppLineFields(opp.Id, oppLines));
	}

	/**
	 * Insert opp line with sync fields set.  Verify corresponding fields on quote line are sync'ed.
	 */
	@isTest
	private static void testInsertOppLineSync() {
		Opportunity opp = createOpp();
		List<OpportunityLineItem> oppLines = createOppLines(opp, 2);

		Quote quote = createQuote(opp);

		startSync(opp.Id, quote.Id);

		Opportunity updatedOpp = updateOpp(opp.Id);
		oppLines = createOppLines(opp, 2);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertOppFields(opp.Id, updatedOpp));
		System.assert(assertOppLineFields(opp.Id, oppLines));
	}

	/**
	 * Update quote sync fields.  Verify corresponding fields on opp are updated.
	 */
	@isTest
	private static void testUpdateQuoteSync() {
		Opportunity opp = createOpp();
		Quote quote = createQuote(opp);

		startSync(opp.Id, quote.Id);

		Quote updatedQuote = updateQuote(quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteFields(quote.Id, updatedQuote));
	}

	/**
	 * Update quote sync fields.  Verify corresponding fields on opp are updated.
	 */
	@isTest
	private static void testUpdateQuoteSyncSetNull() {
		Opportunity opp = createOpp();
		Quote quote = createQuote(opp);

		startSync(opp.Id, quote.Id);

		Quote updatedQuote = updateQuote(quote.Id, true);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteFields(quote.Id, updatedQuote));
	}

	/**
	 * Update quote line sync fields.  Verify corresponding fields on opp line are updated.
	 */
	@isTest
	private static void testUpdateQuoteLineSync1() {
		Opportunity opp = createOpp();

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2);
		System.assert(!quoteLines.isEmpty());

		startSync(opp.Id, quote.Id);

		Quote updatedQuote = updateQuote(quote.Id);
		List<QuoteLineItem> updatedQuoteLines = updateQuoteLines(quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertQuoteFields(quote.Id, updatedQuote));
		System.assert(assertQuoteLineFields(quote.Id, updatedQuoteLines));
	}

	/**
	 * Update quote line sync fields.  Verify corresponding fields on opp line are updated.
	 */
	@isTest
	private static void testUpdateQuoteLineSyncSetNull() {
		Opportunity opp = createOpp();

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2);
		System.assert(!quoteLines.isEmpty());

		startSync(opp.Id, quote.Id);

		Quote updatedQuote = updateQuote(quote.Id);
		List<QuoteLineItem> updatedQuoteLines = updateQuoteLines(quote.Id, true, true, true);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertQuoteFields(quote.Id, updatedQuote));
		System.assert(assertQuoteLineFields(quote.Id, updatedQuoteLines));
	}

	/**
	 * Update quote line sync fields.  Verify corresponding fields on opp line are updated.
	 */
	@isTest
	private static void testUpdateQuoteLineSync2() {
		Opportunity opp = createOpp();

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2);
		System.assert(!quoteLines.isEmpty());

		startSync(opp.Id, quote.Id);

		Quote updatedQuote = updateQuote(quote.Id);
		List<QuoteLineItem> updatedQuoteLines = updateQuoteLinesStdSyncFields(quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertQuoteFields(quote.Id, updatedQuote));
		System.assert(assertQuoteLineFields(quote.Id, updatedQuoteLines));
	}

	/**
	 * Update quote line sync fields.  Verify corresponding fields on opp line are updated.
	 */
	@isTest
	private static void testUpdateQuoteLineSync3() {
		Opportunity opp = createOpp();

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2);
		System.assert(!quoteLines.isEmpty());

		startSync(opp.Id, quote.Id);

		Quote updatedQuote = updateQuote(quote.Id);
		List<QuoteLineItem> updatedQuoteLines = updateQuoteLinesCustomSyncFields(quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertQuoteFields(quote.Id, updatedQuote));
		System.assert(assertQuoteLineFields(quote.Id, updatedQuoteLines));
	}

	/**
	 * Insert quote line with sync fields.  Verify corresponding fields on opp line are sync'ed.
	 */
	@isTest
	private static void testInsertQuoteLineSync() {
		Opportunity opp = createOpp();
		List<OpportunityLineItem> oppLines = createOppLines(opp, 2);
		System.assert(!oppLines.isEmpty());
		Quote quote = createQuote(opp);

		startSync(opp.Id, quote.Id);

		Quote updatedQuote = updateQuote(quote.Id);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertQuoteFields(quote.Id, updatedQuote));
		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}

	/**
	 * Update opp non-sync fields.  Verify fields on quote are not updated.
	 */
	@isTest
	private static void testUpdateOppNoSync() {
		Opportunity opp = createOpp();
		Quote quote = createQuote(opp);

		startSync(opp.Id, quote.Id);

		updateOppNoSync(opp.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteFields(quote.Id, quote));
	}

	/**
	 * Update opp line non-sync fields.  Verify fields on quote line are not updated.
	 */
	@isTest
	private static void testUpdateOppLineNoSync() {
		Opportunity opp = createOpp();
		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2);
		System.assert(!quoteLines.isEmpty());

		startSync(opp.Id, quote.Id);

		// remove sync field
		String field = QuoteSyncUtil.removeQuoteLineField('description');

		List<OpportunityLineItem> oppLines = updateOppLinesNoSync(opp.Id, field);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertOppLineFields(opp.Id, oppLines));

		// add sync field
		/* if (field != null) {
			QuoteSyncUtil.addQuoteLineField('description', field);
		} */
	}

	/**
	 * Insert opp line without sync fields.  Verify fields on quote line are sync'ed.
	 */
	@isTest
	private static void testInsertOppLineNoSync() {
		Opportunity opp = createOpp();
		Quote quote = createQuote(opp);

		startSync(opp.Id, quote.Id);

		List<OpportunityLineItem> oppLines = createOppLinesNoSync(opp, 2);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertOppLineFields(opp.Id, oppLines));
	}

	/**
	 * Update quote non-sync fields.  Verify corresponding fields on opp are not updated.
	 */
	@isTest
	private static void testUpdateQuoteNoSync() {
		Opportunity opp = createOpp();
		Quote quote = createQuote(opp);

		startSync(opp.Id, quote.Id);

		updateQuoteNoSync(quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteFields(quote.Id, quote));
	}

	/**
	 * Update quote line non-sync fields.  Verify corresponding fields on opp line are not updated.
	 */
	@isTest
	private static void testUpdateQuoteLineNoSync() {
		Opportunity opp = createOpp();
		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2);
		System.assert(!quoteLines.isEmpty());

		startSync(opp.Id, quote.Id);

		// remove sync field
		String field = QuoteSyncUtil.removeQuoteLineField('description');

		quoteLines = updateQuoteLinesNoSync(quote.Id, 'description');

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertQuoteLineFields(quote.Id, quoteLines));

		// add sync field
		/* if (field != null) {
			QuoteSyncUtil.addQuoteLineField('description', field);
		} */
	}

	/**
	 * Insert quote line without sync fields.  Verify corresponding fields on opp line are not synced.
	 */
	@isTest
	private static void testInsertQuoteLineNoSync() {
		Opportunity opp = createOpp();
		Quote quote = createQuote(opp);

		startSync(opp.Id, quote.Id);

		List<QuoteLineItem> quoteLines = createQuoteLinesNoSync(quote, 2);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}

	/**
	 * Update opp when it's not sync with quote.
	 */
	@isTest
	private static void testUpdateOppNotSync() {
		Opportunity opp = createOpp();
		Quote quote = createQuote(opp);

		Opportunity updatedOpp = updateOpp(opp.Id);

		System.assert(assertQuoteNotSync(opp.Id, quote.Id));
		System.assert(assertOppFields(opp.Id, updatedOpp));
	}

	/**
	 * Update quote when it's not synced with opp.
	 */
	@isTest
	private static void testUpdateQuoteNotSync() {
		Opportunity opp = createOpp();
		Quote quote = createQuote(opp);

		Quote updatedQuote = updateQuote(quote.Id);

		System.assert(assertQuoteNotSync(opp.Id, quote.Id));
		System.assert(assertQuoteFields(quote.Id, updatedQuote));
	}

	/**
	 * Update opp line when opp not synced with quote.
	 */
	@isTest
	private static void testUpdateOppLineNotSync() {
		Opportunity opp = createOpp();
		List<OpportunityLineItem> oppLines = createOppLines(opp, 2);
		System.assert(!oppLines.isEmpty());

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2);
		System.assert(!quoteLines.isEmpty());

		Opportunity updatedOpp = updateOpp(opp.Id);
		List<OpportunityLineItem> updatedOppLines = updateOppLines(opp.Id);

		System.assert(assertQuoteNotSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineNotSync(opp.Id, quote.Id));

		System.assert(assertOppFields(opp.Id, updatedOpp));
		System.assert(assertOppLineFields(opp.Id, updatedOppLines));
	}

	/**
	 * Update quote line when quote not synced with opp.
	 */
	@isTest
	private static void testUpdateQuoteLineNotSync() {
		Opportunity opp = createOpp();
		List<OpportunityLineItem> oppLines = createOppLines(opp, 2);
		System.assert(!oppLines.isEmpty());

		Quote quote = createQuote(opp);
		//List<QuoteLineItem> quoteLines =
		createQuoteLines(quote, 2);

		Quote updatedQuote = updateQuote(quote.Id);
		List<QuoteLineItem> updatedQuoteLines = updateQuoteLines(quote.Id);

		System.assert(assertQuoteNotSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineNotSync(opp.Id, quote.Id));

		System.assert(assertQuoteFields(quote.Id, updatedQuote));
		System.assert(assertQuoteLineFields(quote.Id, updatedQuoteLines));
	}

	/**
	 * Insert opp line when opp not sync with quote
	 */
	@isTest
	private static void testInsertOppLineNotSync() {
		Opportunity opp = createOpp();
		List<OpportunityLineItem> oppLines = createOppLines(opp, 2);

		Quote quote = createQuote(opp);

		oppLines.addAll(createOppLines(opp, 2));

		System.assert(assertQuoteNotSync(opp.Id, quote.Id, true));
		System.assert(assertQuoteLineNotSync(opp.Id, quote.Id, true));

		System.assert(assertOppLineFields(opp.Id, oppLines));
	}

	/**
	 * Insert quote line when quote not sync with opp.
	 */
	@isTest
	private static void testInsertQuoteLineNotSync() {
		Opportunity opp = createOpp();

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2);

		System.assert(assertQuoteNotSync(opp.Id, quote.Id, true));
		System.assert(assertQuoteLineNotSync(opp.Id, quote.Id, true));

		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}

	/**
	 * Create duplicate opp line with from same pricebookentry
	 */
	@isTest
	private static void testCreateDuplicateOppLine() {
		Opportunity opp = createOpp();

		Quote quote = createQuote(opp);

		startSync(opp.Id, quote.Id);

		List<OpportunityLineItem> oppLines = createOppLines(opp, 2, false, false);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertOppLineFields(opp.Id, oppLines));
	}

	/**
	 * Create duplicate quote line with from same pricebookentry
	 */
	@isTest
	private static void testCreateDuplicateQuoteLine() {
		Opportunity opp = createOpp();

		Quote quote = createQuote(opp);

		startSync(opp.Id, quote.Id);

		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2, false, false);
		System.assert(!quoteLines.isEmpty());

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}

	/**
	 * Update duplicate opp line with from same pricebookentry
	 */
	@isTest
	private static void testUpdateDuplicateOppLine() {
		Opportunity opp = createOpp();

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2, false, false);
		System.assert(!quoteLines.isEmpty());

		startSync(opp.Id, quote.Id);

		Opportunity updatedOpp = updateOpp(opp.Id);
		List<OpportunityLineItem> oppLines = updateOppLines(opp.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertOppFields(opp.Id, updatedOpp));
		System.assert(assertOppLineFields(opp.Id, oppLines));
	}

	/**
	 * Update duplicate quote line with from same pricebookentry
	 */
	@isTest
	private static void testUpdateDuplicateQuoteLine() {
		Opportunity opp = createOpp();

		Quote quote = createQuote(opp);
		List<QuoteLineItem> quoteLines = createQuoteLines(quote, 2, false, false);

		startSync(opp.Id, quote.Id);

		quote = updateQuote(quote.Id);
		quoteLines = updateQuoteLines(quote.Id);

		System.assert(assertQuoteSync(opp.Id, quote.Id));
		System.assert(assertQuoteLineSync(opp.Id, quote.Id));

		System.assert(assertQuoteFields(quote.Id, quote));
		System.assert(assertQuoteLineFields(quote.Id, quoteLines));
	}
}