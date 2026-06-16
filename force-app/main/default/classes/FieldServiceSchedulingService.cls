/**
 * FieldServiceSchedulingService — the self-scheduling brain an Agentforce agent calls.
 *
 * Portable by design: a lightweight slot engine (next business days within the territory's
 * operating window, minus already-booked appointments) so it runs in ANY org without the
 * Field Service optimization/Scheduler config. Swap proposeSlots() for Salesforce Scheduler's
 * getAppointmentSlots / FS appointment candidates in a production deployment.
 *
 * Two operations (each exposed as its own @InvocableMethod wrapper class):
 *   • proposeSlots(serviceAppointmentId) -> up to N candidate start times
 *   • book(serviceAppointmentId, startTime) -> schedules the SA + assigns a resource
 */
public without sharing class FieldServiceSchedulingService {

    public static final Integer SLOT_MINUTES = 60;
    private static final List<Integer> SLOT_HOURS = new List<Integer>{ 9, 13 };  // 9am, 1pm
    private static final Integer DAYS_TO_SCAN = 7;
    private static final Integer MAX_SLOTS = 3;

    public class Slot {
        public Datetime startTime;
        public String label;
        public Slot(Datetime s) { startTime = s; label = s.format('EEE MMM d, h:mm a'); }
    }

    /** Candidate appointment slots for an unscheduled ServiceAppointment. */
    public static List<Slot> proposeSlots(Id saId) {
        List<Slot> slots = new List<Slot>();
        if (saId == null) return slots;
        List<ServiceAppointment> sas = [SELECT Id, ServiceTerritoryId, EarliestStartTime FROM ServiceAppointment WHERE Id = :saId LIMIT 1];
        if (sas.isEmpty()) return slots;
        Id territoryId = sas[0].ServiceTerritoryId;

        // already-booked starts in this territory (avoid double-booking the demo resource)
        Set<Datetime> taken = new Set<Datetime>();
        for (ServiceAppointment b : [
            SELECT SchedStartTime FROM ServiceAppointment
            WHERE ServiceTerritoryId = :territoryId AND Status = 'Scheduled' AND SchedStartTime != null
        ]) taken.add(b.SchedStartTime);

        Date day = Date.today().addDays(1);
        for (Integer d = 0; d < DAYS_TO_SCAN && slots.size() < MAX_SLOTS; d++) {
            Date cur = day.addDays(d);
            Datetime dow = Datetime.newInstance(cur, Time.newInstance(0,0,0,0));
            String wd = dow.format('EEE');
            if (wd == 'Sat' || wd == 'Sun') continue;                 // business days only
            for (Integer h : SLOT_HOURS) {
                if (slots.size() >= MAX_SLOTS) break;
                Datetime start = Datetime.newInstance(cur, Time.newInstance(h,0,0,0));
                if (!taken.contains(start)) slots.add(new Slot(start));
            }
        }
        return slots;
    }

    public class BookResult {
        public Boolean success = false;
        public String message;
        public Datetime scheduledStart;
    }

    /** Schedule the appointment at the chosen start time and assign a territory resource. */
    public static BookResult book(Id saId, Datetime start) {
        BookResult res = new BookResult();
        if (saId == null || start == null) { res.message = 'Need an appointment and a start time.'; return res; }

        List<ServiceAppointment> sas = [SELECT Id, ServiceTerritoryId, Status FROM ServiceAppointment WHERE Id = :saId LIMIT 1];
        if (sas.isEmpty()) { res.message = 'Appointment not found.'; return res; }
        ServiceAppointment sa = sas[0];

        sa.SchedStartTime = start;
        sa.SchedEndTime = start.addMinutes(SLOT_MINUTES);
        sa.Status = 'Scheduled';
        update sa;

        // assign the first resource serving this territory (idempotent-ish for the demo)
        List<ServiceTerritoryMember> stm = [
            SELECT ServiceResourceId FROM ServiceTerritoryMember
            WHERE ServiceTerritoryId = :sa.ServiceTerritoryId LIMIT 1
        ];
        if (!stm.isEmpty()) {
            List<AssignedResource> existing = [SELECT Id FROM AssignedResource WHERE ServiceAppointmentId = :saId LIMIT 1];
            if (existing.isEmpty()) {
                try { insert new AssignedResource(ServiceAppointmentId = saId, ServiceResourceId = stm[0].ServiceResourceId); }
                catch (Exception e) { /* resource assignment is best-effort in the demo */ }
            }
        }
        res.success = true;
        res.scheduledStart = start;
        res.message = 'Appointment scheduled for ' + start.format('EEE MMM d, h:mm a') + '.';
        return res;
    }
}
