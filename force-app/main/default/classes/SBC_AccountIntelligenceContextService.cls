public with sharing class SBC_AccountIntelligenceContextService {
    private static final Integer RELATED_RECORD_LIMIT = 10;

    public class ContextException extends Exception {
    }

    public class AccountIntelligenceContext {
        public List<Evidence> evidence { get; set; }

        public AccountIntelligenceContext() {
            evidence = new List<Evidence>();
        }
    }

    public class Evidence {
        public String evidenceId { get; set; }
        public String sourceType { get; set; }
        public transient Id recordId { get; set; }
        public Map<String, Object> facts { get; set; }

        private Evidence(
            String evidenceId,
            String sourceType,
            Id recordId,
            Map<String, Object> facts
        ) {
            this.evidenceId = evidenceId;
            this.sourceType = sourceType;
            this.recordId = recordId;
            this.facts = facts;
        }
    }

    public static AccountIntelligenceContext buildContext(Id accountId) {
        if (accountId == null || accountId.getSObjectType() != Account.SObjectType) {
            throw new ContextException('A valid Account is required.');
        }

        List<Account> accounts = [
            SELECT Id, Name, Industry, Type, AnnualRevenue, NumberOfEmployees
            FROM Account
            WHERE Id = :accountId
            WITH USER_MODE
            LIMIT 1
        ];
        if (accounts.isEmpty()) {
            throw new ContextException('The Account is unavailable.');
        }

        AccountIntelligenceContext context = new AccountIntelligenceContext();
        Integer sequence = 1;
        Account accountRecord = accounts[0];
        context.evidence.add(
            evidence(
                sequence++,
                'Account',
                accountRecord.Id,
                new Map<String, Object>{
                    'name' => accountRecord.Name,
                    'industry' => accountRecord.Industry,
                    'type' => accountRecord.Type,
                    'annualRevenue' => accountRecord.AnnualRevenue,
                    'numberOfEmployees' => accountRecord.NumberOfEmployees
                }
            )
        );

        for (
            Opportunity opportunityRecord : [
                SELECT Id, Name, StageName, Amount, CloseDate, Probability, IsClosed, IsWon
                FROM Opportunity
                WHERE AccountId = :accountId
                WITH USER_MODE
                ORDER BY CloseDate ASC NULLS LAST, CreatedDate DESC, Id ASC
                LIMIT :RELATED_RECORD_LIMIT
            ]
        ) {
            context.evidence.add(
                evidence(
                    sequence++,
                    'Opportunity',
                    opportunityRecord.Id,
                    new Map<String, Object>{
                        'name' => opportunityRecord.Name,
                        'stage' => opportunityRecord.StageName,
                        'amount' => opportunityRecord.Amount,
                        'closeDate' => opportunityRecord.CloseDate,
                        'probability' => opportunityRecord.Probability,
                        'isClosed' => opportunityRecord.IsClosed,
                        'isWon' => opportunityRecord.IsWon
                    }
                )
            );
        }

        for (
            Case caseRecord : [
                SELECT Id, CaseNumber, Subject, Status, Priority, CreatedDate, ClosedDate
                FROM Case
                WHERE AccountId = :accountId
                WITH USER_MODE
                ORDER BY CreatedDate DESC, Id ASC
                LIMIT :RELATED_RECORD_LIMIT
            ]
        ) {
            context.evidence.add(
                evidence(
                    sequence++,
                    'Case',
                    caseRecord.Id,
                    new Map<String, Object>{
                        'caseNumber' => caseRecord.CaseNumber,
                        'subject' => caseRecord.Subject,
                        'status' => caseRecord.Status,
                        'priority' => caseRecord.Priority,
                        'createdDate' => caseRecord.CreatedDate,
                        'closedDate' => caseRecord.ClosedDate
                    }
                )
            );
        }

        for (
            Task taskRecord : [
                SELECT Id, Subject, Status, Priority, ActivityDate, CreatedDate
                FROM Task
                WHERE WhatId = :accountId
                WITH USER_MODE
                ORDER BY ActivityDate DESC NULLS LAST, CreatedDate DESC, Id ASC
                LIMIT :RELATED_RECORD_LIMIT
            ]
        ) {
            context.evidence.add(
                evidence(
                    sequence++,
                    'Task',
                    taskRecord.Id,
                    new Map<String, Object>{
                        'subject' => taskRecord.Subject,
                        'status' => taskRecord.Status,
                        'priority' => taskRecord.Priority,
                        'activityDate' => taskRecord.ActivityDate,
                        'createdDate' => taskRecord.CreatedDate
                    }
                )
            );
        }

        for (
            Contact contactRecord : [
                SELECT Id, Title, Department, CreatedDate
                FROM Contact
                WHERE AccountId = :accountId
                WITH USER_MODE
                ORDER BY CreatedDate DESC, Id ASC
                LIMIT :RELATED_RECORD_LIMIT
            ]
        ) {
            context.evidence.add(
                evidence(
                    sequence++,
                    'Contact',
                    contactRecord.Id,
                    new Map<String, Object>{
                        'title' => contactRecord.Title,
                        'department' => contactRecord.Department,
                        'createdDate' => contactRecord.CreatedDate
                    }
                )
            );
        }

        return context;
    }

    private static Evidence evidence(
        Integer sequence,
        String sourceType,
        Id recordId,
        Map<String, Object> facts
    ) {
        return new Evidence(
            'EV-' + String.valueOf(sequence).leftPad(3, '0'),
            sourceType,
            recordId,
            facts
        );
    }
}
