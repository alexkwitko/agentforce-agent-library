/**
 * BookAppointmentAction — Agentforce action: "book the slot the customer picked."
 *
 * Robust against how a planner passes the choice back: it re-derives the current slots
 * (via FieldServiceSchedulingService.proposeSlots) and matches the customer's selection by
 * exact/!fuzzy label OR by 1-based index ("the first one" -> "1"). This avoids fragile
 * datetime-string parsing. Then it schedules the SA + assigns a resource.
 */
public with sharing class BookAppointmentAction {

    public class Request {
        @InvocableVariable(label='Service Appointment ID' required=true) public Id serviceAppointmentId;
        @InvocableVariable(label='Selected Slot' required=true
            description='The slot the customer chose — the exact label from Get Appointment Slots, or its position like "1".')
        public String selectedSlot;
    }
    public class Result {
        @InvocableVariable public Boolean success;
        @InvocableVariable public String scheduledTime;      // confirmed label, empty if not booked
        @InvocableVariable public String message;            // ready-to-speak confirmation/clarification
    }

    @InvocableMethod(label='Book Appointment'
        description='Books the chosen self-scheduling slot for a ServiceAppointment and assigns a resource.')
    public static List<Result> run(List<Request> reqs) {
        List<Result> out = new List<Result>();
        for (Request r : reqs) out.add(bookOne(r));
        return out;
    }

    private static Result bookOne(Request r) {
        Result res = new Result();
        res.success = false;
        res.scheduledTime = '';

        List<FieldServiceSchedulingService.Slot> slots = FieldServiceSchedulingService.proposeSlots(r.serviceAppointmentId);
        if (slots.isEmpty()) {
            res.message = 'There are no open slots to book right now. Offer to have someone follow up.';
            return res;
        }

        FieldServiceSchedulingService.Slot chosen = match(slots, r.selectedSlot);
        if (chosen == null) {
            List<String> labels = new List<String>();
            for (FieldServiceSchedulingService.Slot s : slots) labels.add(s.label);
            res.message = 'That selection did not match an available slot. The options are: ' + String.join(labels, ' | ') + '.';
            return res;
        }

        FieldServiceSchedulingService.BookResult br = FieldServiceSchedulingService.book(r.serviceAppointmentId, chosen.startTime);
        res.success = br.success;
        res.message = br.message;
        if (br.success) res.scheduledTime = chosen.label;
        return res;
    }

    /** Match by 1-based index first, then exact (trim/case-insensitive), then substring. */
    private static FieldServiceSchedulingService.Slot match(List<FieldServiceSchedulingService.Slot> slots, String sel) {
        if (sel == null) return null;
        String s = sel.trim();
        if (s.isNumeric()) {
            Integer i = Integer.valueOf(s);
            if (i >= 1 && i <= slots.size()) return slots[i - 1];
        }
        String low = s.toLowerCase();
        for (FieldServiceSchedulingService.Slot slot : slots) {
            if (slot.label.toLowerCase() == low) return slot;
        }
        for (FieldServiceSchedulingService.Slot slot : slots) {
            if (slot.label.toLowerCase().contains(low) || low.contains(slot.label.toLowerCase())) return slot;
        }
        return null;
    }
}
