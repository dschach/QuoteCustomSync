/**
 * @description QuoteSyncHandler class that contains all the logic that uses the
 * QuoteSyncUtil. This class exposes methods to sync the Opportunity, Quote,
 * OpportunityLineItem and QuoteLineItem objects and should ideally be called
 * from each object's trigger
 * <br>Code adapted from QuoteSync AppExchange package, moved to single handler class
 *
 * @author {@link [Salesforce Labs](https://github.com/SalesforceLabs)}
 * @since  2014 Original Author
 *
 * @author {@link [David Schach](https://github.com/dschach)}
 * @since 2022-08 New trigger handler framework
 * @since 2022-10 Converted to Custom Metadata
 * @since 2023-04 Refine Quote Sync with new Quote fields
 * @since 2023-04 Remove trigger framework, stoppers into this class
 *
 * @group OppQuoteSync
 * @see QuoteSyncUtil
 */
@SuppressWarnings('PMD.AvoidGLobalModifier')
global without sharing class QuoteSyncHandler {
	/**
	 * @description Sync `Opportunities` with `Quotes`
	 * @author {@link [David Schach](https://github.com/dschach)}
	 * @since  2022 Change SOQL to use IN collection, not comma-separated Ids
	 * @param newRecords New `Opportunities` from Trigger.new
	 * @param oldRecordsMap Old `Opportunities` in a map from Trigger.oldMap
	 */
	global void syncOpportunities(List<Opportunity> newRecords, Map<Id, Opportunity> oldRecordsMap) {
		System.debug('OPP TRIGGER: ' + Trigger.operationType.name());
		if (stopOpp) {
			return;
		}

		stopOpp = true;
		Set<String> quoteFields = QuoteSyncUtil.getQuoteFields();

		String quoteFieldsString = getStringFromFieldSet(quoteFields);
		String oppFieldsString = getStringFromFieldSet(QuoteSyncUtil.getOppFields());

		Map<Id, Id> startSyncQuoteMap = new Map<Id, Id>();
		Set<Id> syncQuoteIds = new Set<Id>();
		Set<Id> syncOppIds = new Set<Id>();

		Set<Id> oppIds = new Set<Id>();
		Set<Id> quoteIds = new Set<Id>();

		for (Opportunity opp : newRecords) {
			if (opp.SyncedQuoteId != oldRecordsMap.get(opp.Id).SyncedQuoteId && opp.SyncedQuoteId != null) {
				startSyncQuoteMap.put(opp.SyncedQuoteId, opp.Id);
				syncQuoteIds.add(opp.SyncedQuoteId);
				syncOppIds.add(opp.Id);
			} else if (opp.SyncedQuoteId != null) {
				oppIds.add(opp.Id);
				quoteIds.add(opp.SyncedQuoteId);
			}
		}

		if (!oppIds.isEmpty() && !quoteIds.isEmpty()) {
			List<Quote> updateQuotes = getQuotesToUpdate(oppIds, quoteIds, oppFieldsString, quoteFieldsString, quoteFields);

			stopQuote = true;
			Database.update(updateQuotes);
			stopQuote = false;
		}

		// Check start sync quote with matching opp lines and quote lines
		if (!startSyncQuoteMap.isEmpty()) {
			String qliFields = getStringFromFieldSet(QuoteSyncUtil.getQuoteLineFields());
			String oliFields = getStringFromFieldSet(QuoteSyncUtil.getOppLineFields());

			//prettier-ignore
			String qliQuery = 'SELECT Id, Name, (SELECT Id, QuoteId, PricebookEntryId, UnitPrice, Quantity, Discount, SortOrder ';
			//prettier-ignore
			qliQuery += qliFields + ' FROM QuoteLineItems ORDER BY SortOrder ASC) FROM Quote WHERE Id IN :syncQuoteIds ORDER BY Id ASC';
			//prettier-ignore
			String oliQuery = 'SELECT Id, Name, (SELECT OpportunityId, PricebookEntryId, UnitPrice, Quantity, Discount, SortOrder ';
			//prettier-ignore
			oliQuery += oliFields + ' FROM OpportunityLineItems ORDER BY SortOrder ASC) FROM Opportunity WHERE Id IN :syncOppIds ORDER BY Id';
			Map<Id, Quote> quoteToQliMap = new Map<Id, Quote>((List<Quote>) Database.query(qliQuery)); //NOPMD
			Map<Id, Opportunity> oppToOliMap = new Map<Id, Opportunity>((List<Opportunity>) Database.query(oliQuery)); //NOPMD

			Set<OpportunityLineItem> updateOliSet = getOpportunityLineItemsToUpdate(syncQuoteIds, syncOppIds, startSyncQuoteMap, qliFields, oliFields);

			if (!updateOliSet.isEmpty()) {
				stopQuote = true;
				stopOppLine = true;
				stopQuoteLine = true;

				List<OpportunityLineItem> updateOliList = new List<OpportunityLineItem>(updateOliSet);
				Database.update(updateOliList);

				updateOliSet.clear();
				updateOliList.clear();
			}
		}
		clearAllBypasses();
	}

	/**
	 * @description        Sync `Quote` fields with `Opportunity` fields
	 *
	 * @author             {@link [Salesforce Labs](https://github.com/SalesforceLabs)}
	 * @author {@link [David Schach](https://github.com/dschach)}
	 * @since  2022 Change SOQL to use IN collection, not comma-separated Ids
	 * @param newRecords    New `Quotes` from Trigger.new
	 * @param oldRecordsMap Old `Quotes` in a map from Trigger.oldMap
	 */
	global void syncQuote(List<Quote> newRecords, Map<Id, Quote> oldRecordsMap) {
		System.debug('QUOTE TRIGGER: ' + Trigger.operationType.name());
		if (stopQuote) {
			return;
		}
		stopQuote = true;
		Set<String> quoteFields = QuoteSyncUtil.getQuoteFields();

		String quoteFieldsString = getStringFromFieldSet(quoteFields);
		String oppFieldsString = getStringFromFieldSet(QuoteSyncUtil.getOppFields());

		String quoteQuery = 'SELECT Id, OpportunityId, IsSyncing' + quoteFieldsString + ' FROM Quote WHERE Id IN :newRecords';
		System.debug(quoteQuery);

		List<Quote> quotes = Database.query(quoteQuery); //NOPMD
		System.debug(quotes);

		Set<Id> oppIds = new Set<Id>();
		Map<Id, Quote> quoteMap = new Map<Id, Quote>();

		for (Quote q : quotes) {
			if (Trigger.isInsert || (Trigger.isUpdate && q.IsSyncing)) {
				quoteMap.put(q.OpportunityId, q);
				oppIds.add(q.OpportunityId);
			}
		}

		if (!oppIds.isEmpty()) {
			String oppQuery = 'SELECT Id, HasOpportunityLineItem' + oppFieldsString + ' FROM Opportunity WHERE Id IN :oppIds';
			System.debug(oppQuery);

			List<Opportunity> opps = Database.query(oppQuery); //NOPMD
			System.debug(opps);

			List<Opportunity> updateOpps = new List<Opportunity>();
			List<Quote> updateQuotes = new List<Quote>();
			for (Opportunity opp : opps) {
				Quote q = quoteMap.get(opp.Id);
				// store the new `Quote` Id if corresponding opportunity has line items
				if (Trigger.isInsert && opp.HasOpportunityLineItem) {
					QuoteSyncUtil.addNewQuoteId(q.Id);
				}
				Boolean hasChange = false;
				for (String quoteField : quoteFields) {
					String oppField = QuoteSyncUtil.getQuoteFieldMapTo(quoteField);
					Object oppValue = opp.get(oppField);
					Object quoteValue = q.get(quoteField);
					System.debug('For Quote.' + quoteField + ' to Opportunity.' + oppField + ' Quote value: ' + quoteValue + ' to Opp value: ' + oppValue);
					if (oppValue != quoteValue) {
						hasChange = true;
						// on Insert, copy value from Opp to Quote for all synced fields
						if (Trigger.isInsert && (quoteValue == null || (quoteValue instanceof Boolean && Boolean.valueOf(quoteValue) == false))) {
							// QuoteSyncUtil.getField('Quote', quoteField).getType() == DisplayType.BOOLEAN &&
							q.put(quoteField, oppValue);
						}
						// on Quote Update, copy Quote values to Opportunity
						else if (Trigger.isUpdate) {
							System.debug('IS UPDATE FROM QUOTE: ' + quoteValue + ' copied over ' + oppValue);
							if (quoteValue == null) {
								opp.put(oppField, null);
							} else {
								opp.put(oppField, quoteValue);
							}
						}
					}
				}
				if (hasChange) {
					if (Trigger.isInsert) {
						updateQuotes.add(q);
					} else if (Trigger.isUpdate) {
						updateOpps.add(opp);
					}
				}
			}
			if (Trigger.isInsert) {
				Database.update(updateQuotes);
			} else if (Trigger.isUpdate) {
				stopOpp = true;
				System.debug('About to update Opps ' + opps);
				Database.update(updateOpps);
				stopOpp = false;
			}
		}
		stopQuote = false;
		System.debug('At end of Quote trigger: newQuoteIds: ' + QuoteSyncUtil.getNewQuoteIds());
	}

	/**
	 * @description         Sync `Opportunity Products` with `Quote Line Items`
	 * @author              {@link [David Schach](https://github.com/dschach)}
	 * @since               2022 Change SOQL to use IN collection, not comma-separated Ids
	 * @param newRecords    New `OpportunityLineItems` from Trigger.new
	 * @param oldRecordsMap Old `OpportunityLineItems` in a map from Trigger.oldMap
	 */
	global void syncOppLines(List<OpportunityLineItem> newRecords, Map<Id, OpportunityLineItem> oldRecordsMap) {
		System.debug('OPP LINES TRIGGER: ' + Trigger.operationType.name());
		if (stopOppLine) {
			return;
		}

		/* 	if (Trigger.isBefore && Trigger.isInsert) {
			if (Test.isRunningTest()) {
				for (OpportunityLineItem oli : newRecords) {
					//QuoteSyncUtil.populateRequiredFields(oli);
				}
			}
			return;
		} */
		Set<String> quoteLineFields = QuoteSyncUtil.getQuoteLineFields();
		Set<String> oppLineFields = QuoteSyncUtil.getOppLineFields(); //NOPMD

		String qliFields = getStringFromFieldSet(quoteLineFields);
		String oliFields = getStringFromFieldSet(oppLineFields);

		Set<Id> oppIds = new Set<Id>();
		for (OpportunityLineItem oli : newRecords) {
			oppIds.add(oli.OpportunityId);
		}

		//prettier-ignore
		String oliQuery ='SELECT Id, Name, SyncedQuoteId, (SELECT Id, Discount, OpportunityId, PricebookEntryId, Quantity, ServiceDate, SortOrder, UnitPrice' + oliFields + ' FROM OpportunityLineItems WHERE Id IN :newRecords ORDER BY SortOrder ASC ) FROM Opportunity WHERE Id IN :oppIds AND SyncedQuoteId != NULL ORDER BY Id ASC';
		System.debug(oliQuery);

		Map<Id, Opportunity> oppToOliMap = new Map<Id, Opportunity>((List<Opportunity>) Database.query(oliQuery)); //NOPMD

		Set<Id> quoteIds = new Set<Id>();
		for (Opportunity opp : oppToOliMap.values()) {
			//We need this loop, but the if statement may not be needed
			if (opp.SyncedQuoteId != null) {
				quoteIds.add(opp.SyncedQuoteId);
			}
		}

		if (!quoteIds.isEmpty()) {
			//prettier-ignore
			String qliQuery = 'SELECT Id, OpportunityId, Name, (SELECT Id, Discount, OpportunityLineItemId, PricebookEntryId, Quantity, QuoteId, ServiceDate, SortOrder, UnitPrice' + qliFields + ' FROM QuoteLineItems ORDER BY SortOrder ASC) FROM Quote WHERE Id IN :quoteIds ORDER BY OpportunityId ASC';
			System.debug(qliQuery);

			Map<Id, Quote> quoteToQliMap = new Map<Id, Quote>((List<Quote>) Database.query(String.escapeSingleQuotes(qliQuery)));

			Set<QuoteLineItem> updateQlis = new Set<QuoteLineItem>();
			Set<OpportunityLineItem> updateOlis = new Set<OpportunityLineItem>();
			for (Opportunity opp : oppToOliMap.values()) {
				List<QuoteLineItem> quotelines = quoteToQliMap.get(opp.SyncedQuoteId).QuoteLineItems;
				// for opp line insert, there will not be corresponding quote line
				if (quotelines == null || quotelines.isEmpty()) {
					continue;
				}

				Set<QuoteLineItem> matchedQlis = new Set<QuoteLineItem>();
				for (OpportunityLineItem oli : oppToOliMap.get(opp.Id).OpportunityLineItems) {
					Boolean updateQli = false;

					if (Trigger.isUpdate) {
						OpportunityLineItem oldOli = oldRecordsMap.get(oli.Id);

						System.debug('Old oli: ' + oldOli.UnitPrice + ', ' + oldOli.Quantity + ', ' + oldOli.Discount + ', ' + oldOli.ServiceDate);
						System.debug('New oli: ' + oli.UnitPrice + ', ' + oli.Quantity + ', ' + oli.Discount + ', ' + oli.ServiceDate);

						/* if (
							oli.UnitPrice == oldOli.UnitPrice &&
							oli.Quantity == oldOli.Quantity &&
							oli.Discount == oldOli.Discount &&
							oli.ServiceDate == oldOli.ServiceDate &&
							oli.SortOrder == oldOli.SortOrder
						) {
							updateQli = true;
						} */
					}

					// Trying setting the update flag to true for all transactions
					updateQli = true;
					// End of trying

					Boolean hasChange = false;
					for (QuoteLineItem qli : quotelines) {
						if (
							(oli.PricebookEntryId == qli.PricebookEntryId &&
							oli.UnitPrice == qli.UnitPrice &&
							oli.Quantity == qli.Quantity &&
							oli.Discount == qli.Discount &&
							oli.ServiceDate == qli.ServiceDate &&
							oli.SortOrder == qli.SortOrder) || (qli.OpportunityLineItemId != null && oli.Id == qli.OpportunityLineItemId)
						) {
							if (updateQlis.contains(qli) || matchedQlis.contains(qli)) {
								continue;
							}
							matchedQlis.add(qli);
							for (String qliField : quoteLineFields) {
								String oliField = QuoteSyncUtil.getQuoteLineFieldMapTo(qliField);
								Object oliValue = oli.get(oliField);
								Object qliValue = qli.get(qliField);
								if (oliValue != qliValue) {
									if (Trigger.isInsert) {
										if (qliValue == null) {
											oli.put(oliField, null);
										} else {
											oli.put(oliField, qliValue);
										}
										hasChange = true;
									} else if (Trigger.isUpdate && !updateQli) {
										if (qliValue == null) {
											oli.put(oliField, null);
										} else {
											oli.put(oliField, qliValue);
										}
										hasChange = true;
									} else if (Trigger.isUpdate && updateQli) {
										if (oliValue == null) {
											qli.put(qliField, null);
										} else {
											qli.put(qliField, oliValue);
										}
										hasChange = true;
									}
								}
							}
							if (hasChange) {
								if (Trigger.isInsert || (Trigger.isUpdate && !updateQli)) {
									updateOlis.add(oli);
								} else if (Trigger.isUpdate && updateQli) {
									updateQlis.add(qli);
								}
							}
							break;
						}
					}
				}
			}

			bypassAll();
			if (!updateOlis.isEmpty()) {
				List<OpportunityLineItem> oliList = new List<OpportunityLineItem>();
				oliList.addAll(updateOlis);
				Database.update(oliList);
			}
			if (!updateQlis.isEmpty()) {
				List<QuoteLineItem> qliList = new List<QuoteLineItem>();
				qliList.addAll(updateQlis);
				Database.update(qliList);
			}
			clearAllBypasses();
		}
	}

	/**
	 * Sync `Quote Line Items` with `Opportunity Products`
	 * @author {@link [David Schach](https://github.com/dschach)}
	 * @since  2022 Change SOQL to use IN collection, not comma-separated Ids
	 * @param newRecords New `QuoteLineItems` from Trigger.new
	 * @param oldRecordsMap Old `QuoteLineItems` in a map from Trigger.oldMap
	 */
	global void syncQuoteLines(List<QuoteLineItem> newRecords, Map<Id, QuoteLineItem> oldRecordsMap) {
		System.debug('QUOTE LINES TRIGGER: ' + Trigger.operationType.name());
		System.debug('New `Quote` Ids: ' + QuoteSyncUtil.getNewQuoteIds());
		if (stopQuoteLine) {
			return;
		}

		/* if (Trigger.isBefore && Trigger.isInsert) {
			if (Test.isRunningTest()) {
				for (QuoteLineItem qli : newRecords) {
					//QuoteSyncUtil.populateRequiredFields(qli);
				}
			}
			return;
		} */

		Set<String> quoteLineFields = QuoteSyncUtil.getQuoteLineFields();
		Set<String> oppLineFields = QuoteSyncUtil.getOppLineFields(); //NOPMD

		String qliFields = getStringFromFieldSet(quoteLineFields);
		String oliFields = getStringFromFieldSet(oppLineFields);

		Set<Id> quoteIds = new Set<Id>();
		for (QuoteLineItem qli : newRecords) {
			quoteIds.add(qli.QuoteId);
		}

		//prettier-ignore
		String qliQuery = 'SELECT Id, OpportunityId, Opportunity.HasOpportunityLineItem, IsSyncing, (SELECT Id, OpportunityLineItemId, QuoteId, PricebookEntryId, UnitPrice, Quantity, Discount, ServiceDate, SortOrder';
		//prettier-ignore
		qliQuery += qliFields + ' FROM QuoteLineItems WHERE Id IN:newRecords ORDER BY SortOrder ASC) FROM Quote WHERE Id IN :quoteIds ORDER BY Id ASC';
		System.debug('qliQuery ' + qliQuery);

		Map<Id, Quote> quoteToQliMap = new Map<Id, Quote>((List<Quote>) Database.query(qliQuery)); //NOPMD)

		quoteIds = quoteToQliMap.keySet();

		Set<Id> oppIds = new Set<Id>();
		Set<Id> filterQuoteIds = new Set<Id>();
		for (Quote q : quoteToQliMap.values()) {
			// Only sync quote line item that are inserted for a new Quote or on a isSyncing Quote
			if ((Trigger.isInsert && q.Opportunity.HasOpportunityLineItem) || q.IsSyncing) {
				QuoteSyncUtil.addNewQuoteId(q.Id);
				oppIds.add(q.OpportunityId);
			} else {
				filterQuoteIds.add(q.Id);
			}
		}

		//System.debug('Filter `Quote` Ids: ' + filterQuoteIds);

		quoteIds.removeAll(filterQuoteIds);
		for (Id id : filterQuoteIds) {
			//quoteToQliMap.remove(id);
			quoteToQliMap.remove(id);
		}

		if (!oppIds.isEmpty()) {
			//prettier-ignore
			String oliQuery = 'SELECT Id, Name, (SELECT Id, OpportunityId, PricebookEntryId, UnitPrice, Quantity, Discount, ServiceDate, SortOrder';
			//prettier-ignore
			oliQuery += oliFields + ' FROM OpportunityLineItems ORDER BY SortOrder ASC) FROM Opportunity WHERE Id IN :oppIds ORDER BY Id ASC';
			System.debug(qliQuery);

			Map<Id, Opportunity> oppToOliMap = new Map<Id, Opportunity>((List<Opportunity>) Database.query(oliQuery)); //NOPMD

			Set<OpportunityLineItem> updateOlis = new Set<OpportunityLineItem>();
			Set<QuoteLineItem> updateQlis = new Set<QuoteLineItem>();

			for (Quote q : quoteToQliMap.values()) {
				List<OpportunityLineItem> opplines = oppToOliMap.get(q.OpportunityId).OpportunityLineItems;

				// for quote line insert, there will not be corresponding opp line
				if (opplines == null || opplines.isEmpty()) {
					continue;
				}

				Set<OpportunityLineItem> matchedOlis = new Set<OpportunityLineItem>();

				for (QuoteLineItem qli : quoteToQliMap.get(q.Id).QuoteLineItems) {
					Boolean updateOli = false;

					if (Trigger.isUpdate) {
						QuoteLineItem oldQli = oldRecordsMap.get(qli.Id);
						System.debug('Old qli: ' + oldQli.UnitPrice + ', ' + oldQli.Quantity + ', ' + oldQli.Discount + ', ' + oldQli.ServiceDate);
						System.debug('New qli: ' + qli.UnitPrice + ', ' + qli.Quantity + ', ' + qli.Discount + ', ' + qli.ServiceDate);

						/* if (
							(qli.UnitPrice == oldQli.UnitPrice &&
							qli.Quantity == oldQli.Quantity &&
							qli.Discount == oldQli.Discount &&
							qli.ServiceDate == oldQli.ServiceDate &&
							qli.SortOrder == oldQli.SortOrder)
						) {
							updateOli = true;
						} */
					}

					// Trying to set updateOli to true for every transaction because we've made an update to the record
					updateOli = true;
					// End of trying

					Boolean hasChange = false;

					for (OpportunityLineItem oli : opplines) {
						if (
							(oli.PricebookEntryId == qli.PricebookEntryId &&
							oli.UnitPrice == qli.UnitPrice &&
							oli.Quantity == qli.Quantity &&
							oli.Discount == qli.Discount &&
							oli.ServiceDate == qli.ServiceDate &&
							oli.SortOrder == qli.SortOrder) || (qli.OpportunityLineItemId != null && oli.Id == qli.OpportunityLineItemId)
						) {
							if (updateOlis.contains(oli) || matchedOlis.contains(oli)) {
								continue;
							}

							matchedOlis.add(oli);

							for (String qliField : quoteLineFields) {
								String oliField = QuoteSyncUtil.getQuoteLineFieldMapTo(qliField);
								Object oliValue = oli.get(oliField);
								Object qliValue = qli.get(qliField);
								if (oliValue != qliValue) {
									if (Trigger.isInsert && (qliValue == null || (qliValue instanceof Boolean && Boolean.valueOf(qliValue) == false))) {
										System.debug('Insert trigger, isSyncing: ' + q.IsSyncing + ', new `Quote` Ids: ' + QuoteSyncUtil.getNewQuoteIds());

										// If it's a newly created Quote, don't sync the "Description" field value,
										// because it's already copied from Opportunity Line Item on create.
										if (q.IsSyncing || (QuoteSyncUtil.isNewQuote(q.Id) && !qliField.equalsIgnoreCase('description'))) {
											qli.put(qliField, oliValue);
											hasChange = true;
										}
									} else if (Trigger.isUpdate && !updateOli) {
										if (oliValue == null) {
											qli.put(qliField, null);
										} else {
											qli.put(qliField, oliValue);
										}
										hasChange = true;
									} else if (Trigger.isUpdate && updateOli) {
										if (qliValue == null) {
											oli.put(oliField, null);
										} else {
											oli.put(oliField, qliValue);
										}
										hasChange = true;
									}
								}
							}

							if (hasChange) {
								if (Trigger.isInsert || (Trigger.isUpdate && !updateOli)) {
									updateQlis.add(qli);
								} else if (Trigger.isUpdate && updateOli) {
									updateOlis.add(oli);
								}
							}
							break;
						}
					}
				}
			}

			bypassAll();

			if (!updateOlis.isEmpty()) {
				List<OpportunityLineItem> oliList = new List<OpportunityLineItem>(updateOlis);
				//oliList.addAll(updateOlis);
				Database.update(olilist);
			}

			if (!updateQlis.isEmpty()) {
				List<QuoteLineItem> qliList = new List<QuoteLineItem>(updateQlis);
				//qliList.addAll(updateQlis);
				Database.update(qliList);
			}

			// Salesforce has split Quote and QLI creation into two transactions, so this may not be necessary.
			// TODO: Remove this in a future version if unneeded.
			if (Trigger.isInsert) {
				QuoteSyncUtil.removeAllNewQuoteIds(quoteIds);
			}

			clearAllBypasses();
		}
	}

	/**
	 * If true, exit `OppoortunityLineItem` trigger handler
	 */
	public static Boolean stopOppLine = false;
	/**
	 * If true, exit `Opportunity` trigger handler
	 */
	public static Boolean stopOpp = false;
	/**
	 * If true, exit `QuoteLineItem` trigger handler
	 */
	public static Boolean stopQuoteLine = false;
	/**
	 * If true, exit `Quote` trigger handler
	 */
	public static Boolean stopQuote = false;

	/**
	 * @description Deactivate all QuoteSync triggers
	 */
	public static void bypassAll() {
		stopOpp = true;
		stopOppLine = true;
		stopQuote = true;
		stopQuoteLine = true;
	}

	/**
	 * @description Reactivate all QuoteSync triggers
	 */
	public static void clearAllBypasses() {
		stopOpp = false;
		stopOppLine = false;
		stopQuote = false;
		stopQuoteLine = false;
	}

	/**
	 * @description  Method that builds a string of fields separated by a comma to be put into a Database query string
	 * @param fields Set of field names
	 * @return       `String` with the fields separated by commas
	 */
	private String getStringFromFieldSet(Set<String> fields) {
		//Set<String> uniqueFields = new Set<String>(fields);
		String fieldsString = fields.isEmpty() ? '' : ',';
		fieldsString += String.join(new List<String>(fields), ',');
		return fieldsString;
	}

	/**
	 * @description Method that gets a set of `Opportunity` Ids, a set of `Quote` 
	 * Ids and returns a list of `Quotes` that should be updated to be synced with
	 * their corresponding `Opportunity`

	 * @author David Schach
	 * @since 2022
	 *
	 * @param oppIds Set of `Opportunity` Ids
	 * @param quoteIds Set of `Quote` Ids
	 * @param oppFieldsString List of comma separated  `Opportunity` fields to be compared
	 * @param quoteFieldsString List of comma separated quote fields to be compared (in a string)
	 * @param quoteFields List of `Quote` fields in a list
	 * @return `List<Quote>` That should be updated
	 */
	private static List<Quote> getQuotesToUpdate(
		Set<Id> oppIds,
		Set<Id> quoteIds,
		String oppFieldsString,
		String quoteFieldsString,
		Set<String> quoteFields
	) {
		//prettier-ignore
		String oppQuery = 'SELECT Id, SyncedQuoteId' + oppFieldsString + ' FROM Opportunity WHERE Id IN :oppIds AND SyncedQuoteId != null';
		System.debug(oppQuery);

		Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>((List<Opportunity>) Database.query(oppQuery)); //NOPMD
		//prettier-ignore
		String quoteQuery = 'SELECT Id, OpportunityId' + quoteFieldsString + ' FROM Quote WHERE Id IN :quoteIds';
		System.debug(quoteQuery);

		List<Quote> quotes = Database.query(quoteQuery); //NOPMD
		List<Quote> updateQuotes = new List<Quote>();
		for (Quote q : quotes) {
			Opportunity opp = oppMap.get(q.OpportunityId);
			Boolean hasChange = false;
			for (String quoteField : quoteFields) {
				String oppField = QuoteSyncUtil.getQuoteFieldMapTo(quoteField);
				Object oppValue = opp.get(oppField);
				Object quoteValue = q.get(quoteField);
				if (oppValue != quoteValue) {
					hasChange = true;
					q.put(quoteField, oppValue);
				}
			}
			if (hasChange) {
				updateQuotes.add(q);
			}
		}

		return updateQuotes;
	}

	/**
	 * @description Method that takes a set of `Quote` Ids, a set of `Opportunity` Ids and a map
	 * linking them together and returns a list of `Opportunity Products` that should be updated to be synced
	 *
	 * @param syncQuoteIds Set of `Quote` Ids
	 * @param syncOppIds Set of `Opportunity` Ids
	 * @param startSyncQuoteMap Map that links each `Quote` Id with its synced `Opportunity` Id
	 * @param qliFields List of `QuoteLineItem` fields to be compared
	 * @param oliFields List of `OpportunityLineItem` fields to be compared
	 * @return `Set<OpportunityLineItem>` that should be updated
	 */
	private static Set<OpportunityLineItem> getOpportunityLineItemsToUpdate(
		Set<Id> syncQuoteIds,
		Set<Id> syncOppIds,
		Map<Id, Id> startSyncQuoteMap,
		String qliFields,
		String oliFields
	) {
		//prettier-ignore
		String qliQuery = 'SELECT Id, Name, (SELECT Id, QuoteId, OpportunityLineItemId, PricebookEntryId, UnitPrice, Quantity, Discount, SortOrder';
		//prettier-ignore
		qliQuery += qliFields + ' FROM QuoteLineItems ORDER BY SortOrder ASC) FROM Quote WHERE Id IN :syncQuoteIds ORDER BY Id ASC';
		//prettier-ignore
		String oliQuery = 'SELECT Id, Name, (SELECT OpportunityId, PricebookEntryId, UnitPrice, Quantity, Discount, SortOrder';
		//prettier-ignore
		oliQuery += oliFields + ' FROM OpportunityLineItems ORDER BY SortOrder ASC) FROM Opportunity WHERE Id IN :syncOppIds ORDER BY Id ASC';
		Map<Id, Quote> quoteToQliMap = new Map<Id, Quote>((List<Quote>) Database.query(qliQuery)); //NOPMD
		Map<Id, Opportunity> oppToOliMap = new Map<Id, Opportunity>((List<Opportunity>) Database.query(oliQuery)); //NOPMD

		Set<OpportunityLineItem> updateOliSet = new Set<OpportunityLineItem>();
		Set<String> quoteLineFields = QuoteSyncUtil.getQuoteLineFields();

		for (Id quoteId : startSyncQuoteMap.keySet()) {
			Id oppId = startSyncQuoteMap.get(quoteId);
			List<QuoteLineItem> quotelines = quoteToQliMap.get(quoteId).QuoteLineItems;
			List<OpportunityLineItem> opplines = oppToOliMap.get(oppId).OpportunityLineItems;

			if (quotelines != null && opplines != null && !quotelines.isEmpty() && !opplines.isEmpty()) {
				for (QuoteLineItem qli : quotelines) {
					Boolean hasChange = false;

					for (OpportunityLineItem oli : opplines) {
						//TODO: Why is this the way to compare OLIs to QLIs
						if (
							(oli.PricebookEntryId == qli.PricebookEntryId &&
							oli.UnitPrice == qli.UnitPrice &&
							oli.Quantity == qli.Quantity &&
							oli.Discount == qli.Discount &&
							oli.SortOrder == qli.SortOrder) ||
							// prettier-ignore
							(qli.OpportunityLineItemId != null && oli.Id == qli.OpportunityLineItemId)
						) {
							if (updateOliSet.contains(oli)) {
								continue;
							}
							System.debug('########## qliId: ' + qli.Id + '     oliId: ' + oli.Id);
							for (String qliField : quoteLineFields) {
								String oliField = QuoteSyncUtil.getQuoteLineFieldMapTo(qliField);
								Object oliValue = oli.get(oliField);
								Object qliValue = qli.get(qliField);
								if (oliValue != qliValue) {
									hasChange = true;
									oli.put(oliField, qliValue);
								}
							}

							if (hasChange) {
								updateOliSet.add(oli);
							}
							break;
						}
					}
				}
			}
		}

		return updateOliSet;
	}
}