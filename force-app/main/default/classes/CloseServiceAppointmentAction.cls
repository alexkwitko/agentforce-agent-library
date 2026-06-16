/**
 * CloseServiceAppointmentAction — Agentforce action: "close out this appointment."
 * Wraps ServiceAppointmentCloseService.close. One @InvocableMethod per class.
 */
public with sharing class CloseServiceAppointmentAction {

    public class Request {
        @InvocableVariable(label='Service Appointment ID' required=true) public Id serviceAppointmentId;
        @InvocableVariable(label='Completion Notes'
            description='Short summary of what was done on the visit.') public String completionNotes;
    }
    public class Result {
        @InvocableVariable public Boolean success;
        @InvocableVariable public String workOrderStatus;
        @InvocableVariable public String message;
    }

    @InvocableMethod(label='Close Service Appointment'
        description='Marks a ServiceAppointment Completed, rolls its Work Order to Completed, and records completion notes.')
    public static List<Result> run(List<Request> reqs) {
        List<Result> out = new List<Result>();
        for (Request r : reqs) {
            ServiceAppointmentCloseService.CloseResult cr =
                ServiceAppointmentCloseService.close(r.serviceAppointmentId, r.completionNotes);
            Result res = new Result();
            res.success = cr.success;
            res.workOrderStatus = cr.workOrderStatus;
            res.message = cr.message;
            out.add(res);
        }
        return out;
    }
}
