@IsTest
private class SBC_AIContextServiceTest {
    @IsTest
    static void buildsDeterministicContextAcrossSupportedObjects() {
        Account accountRecord = new Account(
            Name = 'Synthetic Account',
            Industry = 'Technology',
            AnnualRevenue = 1000000,
            NumberOfEmployees = 50
        );
        insert accountRecord;
        insert new List<Opportunity>{
            new Opportunity(
                AccountId = accountRecord.Id,
                Name = 'Later Renewal',
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30),
                Amount = 20000
            ),
            new Opportunity(
                AccountId = accountRecord.Id,
                Name = 'Sooner Expansion',
                StageName = 'Qualification',
                CloseDate = Date.today().addDays(10),
                Amount = 40000
            )
        };
        insert new List<Case>{
            new Case(AccountId = accountRecord.Id, Subject = 'First issue', Origin = 'Web'),
            new Case(AccountId = accountRecord.Id, Subject = 'Second issue', Origin = 'Phone')
        };
        insert new List<Task>{
            new Task(
                WhatId = accountRecord.Id,
                Subject = 'Older follow-up',
                Status = 'Not Started',
                Priority = 'Normal',
                ActivityDate = Date.today().addDays(2)
            ),
            new Task(
                WhatId = accountRecord.Id,
                Subject = 'Latest follow-up',
                Status = 'Not Started',
                Priority = 'High',
                ActivityDate = Date.today().addDays(5)
            )
        };
        insert new Contact(
            AccountId = accountRecord.Id,
            LastName = 'Synthetic',
            Title = 'VP Operations',
            Department = 'Operations',
            Email = 'never-sent@example.invalid',
            Phone = '+1 555 0100'
        );

        Test.startTest();
        SBC_AccountIntelligenceContextService.AccountIntelligenceContext context = SBC_AccountIntelligenceContextService.buildContext(
            accountRecord.Id
        );
        Test.stopTest();

        System.assertEquals(8, context.evidence.size());
        for (Integer index = 0; index < context.evidence.size(); index++) {
            System.assertEquals(
                'EV-' + String.valueOf(index + 1).leftPad(3, '0'),
                context.evidence[index].evidenceId
            );
        }
        System.assertEquals('Account', context.evidence[0].sourceType);
        System.assertEquals('Sooner Expansion', context.evidence[1].facts.get('name'));
        System.assertEquals('Later Renewal', context.evidence[2].facts.get('name'));
        System.assertEquals('Task', context.evidence[5].sourceType);
        System.assertEquals('Latest follow-up', context.evidence[5].facts.get('subject'));
        System.assertEquals('Contact', context.evidence[7].sourceType);
        String serializedContext = JSON.serialize(context);
        System.assert(!serializedContext.contains('never-sent@example.invalid'));
        System.assert(!serializedContext.contains('+1 555 0100'));
        System.assert(!serializedContext.contains('Synthetic\"'));

        SBC_AccountIntelligencePresentation.Response presentation = SBC_AccountIntelligencePresentation.create(
            null,
            context
        );
        System.assertEquals(8, presentation.evidenceCatalog.size());
        for (Integer index = 0; index < presentation.evidenceCatalog.size(); index++) {
            System.assertEquals(
                context.evidence[index].evidenceId,
                presentation.evidenceCatalog[index].evidenceId
            );
            System.assertEquals(
                context.evidence[index].recordId,
                presentation.evidenceCatalog[index].recordId
            );
        }
        System.assertEquals('Synthetic Account', presentation.evidenceCatalog[0].displayLabel);
        System.assert(
            presentation.evidenceCatalog[1].factSummary.contains('Stage: Qualification')
        );
        System.assert(!presentation.evidenceCatalog[3].factSummary.contains('First issue'));
        System.assert(!presentation.evidenceCatalog[5].factSummary.contains('Latest follow-up'));
        System.assertEquals('VP Operations', presentation.evidenceCatalog[7].displayLabel);
        String serializedPresentation = JSON.serialize(presentation);
        System.assert(!serializedPresentation.contains('facts'));
        System.assert(!serializedPresentation.contains('never-sent@example.invalid'));
        System.assert(!serializedPresentation.contains('+1 555 0100'));
    }

    @IsTest
    static void supportsAccountWithNoRelatedRecords() {
        Account accountRecord = new Account(Name = 'Empty Synthetic Account');
        insert accountRecord;

        SBC_AccountIntelligenceContextService.AccountIntelligenceContext context = SBC_AccountIntelligenceContextService.buildContext(
            accountRecord.Id
        );

        System.assertEquals(1, context.evidence.size());
        System.assertEquals('EV-001', context.evidence[0].evidenceId);
        System.assertEquals('Account', context.evidence[0].sourceType);
    }

    @IsTest
    static void rejectsMissingAccountId() {
        try {
            SBC_AccountIntelligenceContextService.buildContext(null);
            System.assert(false, 'Expected missing Account validation.');
        } catch (SBC_AccountIntelligenceContextService.ContextException exceptionValue) {
            System.assertEquals('A valid Account is required.', exceptionValue.getMessage());
        }
    }
}
