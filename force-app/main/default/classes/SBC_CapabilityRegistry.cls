public with sharing class SBC_CapabilityRegistry {
    private static final String AVAILABLE = 'Available';

    public class CapabilityDescriptor {
        public String key { get; private set; }
        public String label { get; private set; }
        public String description { get; private set; }
        public String lifecycleStatus { get; private set; }
        public String version { get; private set; }
        public String handlerKey { get; private set; }
        public Boolean requiresHumanApproval { get; private set; }
        public Boolean executable { get; private set; }
        public Integer displayOrder { get; private set; }

        private CapabilityDescriptor(SBC_Capability__mdt recordValue) {
            key = recordValue.DeveloperName;
            label = recordValue.MasterLabel;
            description = recordValue.Description__c;
            lifecycleStatus = recordValue.Lifecycle_Status__c;
            version = recordValue.Version__c;
            handlerKey = recordValue.Handler_Key__c;
            requiresHumanApproval = recordValue.Requires_Human_Approval__c;
            executable = recordValue.Lifecycle_Status__c == AVAILABLE;
            displayOrder = recordValue.Display_Order__c == null
                ? null
                : recordValue.Display_Order__c.intValue();
        }
    }

    public static List<CapabilityDescriptor> listCapabilities() {
        List<CapabilityDescriptor> descriptors = new List<CapabilityDescriptor>();
        for (SBC_Capability__mdt recordValue : queryActiveCapabilities(null)) {
            descriptors.add(new CapabilityDescriptor(recordValue));
        }
        return descriptors;
    }

    public static CapabilityDescriptor getCapability(String capabilityKey) {
        if (String.isBlank(capabilityKey)) {
            return null;
        }

        List<SBC_Capability__mdt> records = queryActiveCapabilities(capabilityKey.trim());
        return records.isEmpty() ? null : new CapabilityDescriptor(records[0]);
    }

    public static Boolean isExecutable(String capabilityKey) {
        CapabilityDescriptor descriptor = getCapability(capabilityKey);
        return descriptor != null && descriptor.executable;
    }

    private static List<SBC_Capability__mdt> queryActiveCapabilities(String capabilityKey) {
        if (capabilityKey == null) {
            return [
                SELECT
                    DeveloperName,
                    MasterLabel,
                    Description__c,
                    Lifecycle_Status__c,
                    Version__c,
                    Handler_Key__c,
                    Requires_Human_Approval__c,
                    Display_Order__c
                FROM SBC_Capability__mdt
                WHERE Is_Active__c = TRUE
                ORDER BY Display_Order__c ASC, DeveloperName ASC
            ];
        }

        return [
            SELECT
                DeveloperName,
                MasterLabel,
                Description__c,
                Lifecycle_Status__c,
                Version__c,
                Handler_Key__c,
                Requires_Human_Approval__c,
                Display_Order__c
            FROM SBC_Capability__mdt
            WHERE Is_Active__c = TRUE AND DeveloperName = :capabilityKey
            ORDER BY Display_Order__c ASC, DeveloperName ASC
            LIMIT 1
        ];
    }
}
