@IsTest
private class SBC_CapabilityRegistryTest {
    @IsTest
    static void listsExactlyThreeActiveDescriptorsInDisplayOrder() {
        Integer dmlBefore = Limits.getDmlStatements();
        Integer calloutsBefore = Limits.getCallouts();

        List<SBC_CapabilityRegistry.CapabilityDescriptor> descriptors = SBC_CapabilityRegistry.listCapabilities();

        System.assertEquals(3, descriptors.size());
        System.assertEquals('Account_Intelligence', descriptors[0].key);
        System.assertEquals('Customer_Recommendation', descriptors[1].key);
        System.assertEquals('Executive_Customer_Briefing', descriptors[2].key);
        System.assertEquals(dmlBefore, Limits.getDmlStatements());
        System.assertEquals(calloutsBefore, Limits.getCallouts());
    }

    @IsTest
    static void mapsAccountIntelligenceDescriptor() {
        SBC_CapabilityRegistry.CapabilityDescriptor descriptor = SBC_CapabilityRegistry.getCapability(
            'Account_Intelligence'
        );

        System.assertNotEquals(null, descriptor);
        System.assertEquals('Account Intelligence', descriptor.label);
        System.assertEquals(
            'Analyzes trusted Salesforce account data to produce evidence-grounded health, risk, growth, opportunity, and recommended-action insights.',
            descriptor.description
        );
        System.assertEquals('Available', descriptor.lifecycleStatus);
        System.assertEquals('1.0.0', descriptor.version);
        System.assertEquals('accountIntelligence', descriptor.handlerKey);
        System.assertEquals(true, descriptor.requiresHumanApproval);
        System.assertEquals(true, descriptor.executable);
        System.assertEquals(1, descriptor.displayOrder);
    }

    @IsTest
    static void marksOnlyAvailableCapabilityExecutable() {
        System.assertEquals(true, SBC_CapabilityRegistry.isExecutable('Account_Intelligence'));
        System.assertEquals(false, SBC_CapabilityRegistry.isExecutable('Customer_Recommendation'));
        System.assertEquals(
            false,
            SBC_CapabilityRegistry.isExecutable('Executive_Customer_Briefing')
        );

        SBC_CapabilityRegistry.CapabilityDescriptor recommendation = SBC_CapabilityRegistry.getCapability(
            'Customer_Recommendation'
        );
        System.assertEquals('Planned', recommendation.lifecycleStatus);
        System.assertEquals('0.1.0', recommendation.version);
        System.assertEquals('customerRecommendation', recommendation.handlerKey);
        System.assertEquals(true, recommendation.requiresHumanApproval);
        System.assertEquals(false, recommendation.executable);
        System.assertEquals(2, recommendation.displayOrder);

        SBC_CapabilityRegistry.CapabilityDescriptor briefing = SBC_CapabilityRegistry.getCapability(
            'Executive_Customer_Briefing'
        );
        System.assertEquals('Planned', briefing.lifecycleStatus);
        System.assertEquals('executiveCustomerBriefing', briefing.handlerKey);
        System.assertEquals(false, briefing.requiresHumanApproval);
        System.assertEquals(false, briefing.executable);
        System.assertEquals(3, briefing.displayOrder);
    }

    @IsTest
    static void unknownNullAndBlankKeysFailSafely() {
        System.assertEquals(null, SBC_CapabilityRegistry.getCapability('Unknown_Capability'));
        System.assertEquals(null, SBC_CapabilityRegistry.getCapability(null));
        System.assertEquals(null, SBC_CapabilityRegistry.getCapability('   '));
        System.assertEquals(false, SBC_CapabilityRegistry.isExecutable('Unknown_Capability'));
        System.assertEquals(false, SBC_CapabilityRegistry.isExecutable(null));
        System.assertEquals(false, SBC_CapabilityRegistry.isExecutable(''));
    }

    @IsTest
    static void returnsNoInactiveOrUnexpectedDescriptors() {
        Set<String> expectedKeys = new Set<String>{
            'Account_Intelligence',
            'Customer_Recommendation',
            'Executive_Customer_Briefing'
        };

        for (
            SBC_CapabilityRegistry.CapabilityDescriptor descriptor : SBC_CapabilityRegistry.listCapabilities()
        ) {
            System.assert(expectedKeys.remove(descriptor.key));
        }
        System.assertEquals(0, expectedKeys.size());
    }
}
