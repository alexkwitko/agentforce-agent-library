/**
 * ServiceAppointmentCloseService — closes out a field-service visit.
 *
 * Marks the ServiceAppointment Completed (stamping actual times), rolls its parent WorkOrder
 * to Completed with a recorded completion summary, and — only if the ServiceReport object
 * exists in this org — creates a Service Report (best-effort, version-safe via dynamic SObject).
 *
 * Idempotent: re-closing an already-Completed appointment is a no-op that reports success.
 */
public without sharing class ServiceAppointmentCloseService {

    public class CloseResult {
        public Boolean success = false;
        public String message;
        public String workOrderStatus;
        public Boolean serviceReportCreated = false;
    }

    public static CloseResult close(Id saId, String notes) {
        CloseResult res = new CloseResult();
        if (saId == null) { res.message = 'No appointment id provided.'; return res; }

        List<ServiceAppointment> sas = [
            SELECT Id, Status, ParentRecordId, ActualStartTime, ActualEndTime, SchedStartTime
            FROM ServiceAppointment WHERE Id = :saId LIMIT 1
        ];
        if (sas.isEmpty()) { res.message = 'Appointment not found.'; return res; }
        ServiceAppointment sa = sas[0];

        if (sa.Status == 'Completed') {
            res.success = true;
            res.message = 'Appointment was already completed.';
            res.workOrderStatus = workOrderStatusOf(sa.ParentRecordId);
            return res;
        }

        sa.ActualStartTime = sa.ActualStartTime != null ? sa.ActualStartTime
                              : (sa.SchedStartTime != null ? sa.SchedStartTime : System.now().addHours(-1));
        sa.ActualEndTime = System.now();
        sa.Status = 'Completed';
        update sa;

        // Roll up the parent Work Order
        if (sa.ParentRecordId != null && ((String)sa.ParentRecordId).startsWith(WorkOrder.SObjectType.getDescribe().getKeyPrefix())) {
            WorkOrder wo = new WorkOrder(Id = sa.ParentRecordId, Status = 'Completed');
            if (notes != null) wo.Completion_Notes__c = notes;
            update wo;
            res.workOrderStatus = 'Completed';
        }

        // Optional Service Report (only if the object exists in this org)
        if (Schema.getGlobalDescribe().containsKey('ServiceReport') && sa.ParentRecordId != null) {
            try {
                SObject sr = Schema.getGlobalDescribe().get('ServiceReport').newSObject();
                sr.put('ParentId', sa.ParentRecordId);
                if (((Map<String,Schema.SObjectField>)Schema.getGlobalDescribe().get('ServiceReport').getDescribe().fields.getMap()).containsKey('DocumentBody')) {
                    sr.put('DocumentBody', Blob.valueOf(notes == null ? 'Visit completed.' : notes));
                }
                insert sr;
                res.serviceReportCreated = true;
            } catch (Exception e) { /* best-effort; report templates vary by org */ }
        }

        res.success = true;
        res.message = 'Appointment closed and Work Order marked Completed'
                      + (res.serviceReportCreated ? ' (Service Report created).' : '.');
        return res;
    }

    private static String workOrderStatusOf(Id parentId) {
        if (parentId == null) return null;
        if (!((String)parentId).startsWith(WorkOrder.SObjectType.getDescribe().getKeyPrefix())) return null;
        List<WorkOrder> w = [SELECT Status FROM WorkOrder WHERE Id = :parentId LIMIT 1];
        return w.isEmpty() ? null : w[0].Status;
    }
}
