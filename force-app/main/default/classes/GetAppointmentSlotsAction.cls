/**
 * GetAppointmentSlotsAction — Agentforce action: "what appointment times are available?"
 *
 * Wraps FieldServiceSchedulingService.proposeSlots so an agent can offer the customer
 * a short list of self-schedulable slots for their unscheduled ServiceAppointment.
 * One @InvocableMethod per class (Apex rule) — booking lives in BookAppointmentAction.
 */
public with sharing class GetAppointmentSlotsAction {

    public class Request {
        @InvocableVariable(label='Service Appointment ID' required=true) public Id serviceAppointmentId;
    }
    public class Result {
        @InvocableVariable public Boolean hasSlots;
        @InvocableVariable public List<String> slots;        // human-readable labels, in order
        @InvocableVariable public String message;            // ready-to-speak summary for the agent
    }

    @InvocableMethod(label='Get Appointment Slots'
        description='Returns up to 3 available self-scheduling time slots for a ServiceAppointment.')
    public static List<Result> run(List<Request> reqs) {
        List<Result> out = new List<Result>();
        for (Request r : reqs) {
            Result res = new Result();
            res.slots = new List<String>();
            List<FieldServiceSchedulingService.Slot> slots = FieldServiceSchedulingService.proposeSlots(r.serviceAppointmentId);
            for (FieldServiceSchedulingService.Slot s : slots) res.slots.add(s.label);
            res.hasSlots = !res.slots.isEmpty();
            res.message = res.hasSlots
                ? 'Available times: ' + String.join(res.slots, ' | ') + '. Ask the customer which one they prefer.'
                : 'No open appointment times in the next several business days. Offer to have someone follow up.';
            out.add(res);
        }
        return out;
    }
}
