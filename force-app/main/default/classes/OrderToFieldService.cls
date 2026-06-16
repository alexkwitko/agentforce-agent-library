/**
 * OrderToFieldService — turns an Order for serviceable products into Field Service work.
 *
 * For each Order whose OrderItems include a product flagged Requires_Field_Service__c, this creates:
 *   • one WorkOrder (linked to the Account + the source Order, on the demo Service Territory)
 *   • one WorkOrderLineItem per serviceable line
 *   • one unscheduled ServiceAppointment (Status='None') for the agent to self-schedule
 *
 * Idempotent: WorkOrder.Source_Order_Id__c is the key — re-running returns the existing WorkOrder.
 * Callable from a record-triggered Flow, the storefront, or an Agentforce action.
 */
public without sharing class OrderToFieldService {

    public class Request {
        @InvocableVariable(label='Order ID' required=true) public Id orderId;
    }
    public class Result {
        @InvocableVariable public Id workOrderId;
        @InvocableVariable public Id serviceAppointmentId;
        @InvocableVariable public Boolean created;
        @InvocableVariable public String message;
    }

    @InvocableMethod(label='Create Field Service From Order'
        description='Creates a WorkOrder + line items + an unscheduled ServiceAppointment for serviceable products on an Order.')
    public static List<Result> run(List<Request> reqs) {
        List<Result> out = new List<Result>();
        for (Request r : reqs) out.add(fromOrder(r.orderId));
        return out;
    }

    public static Result fromOrder(Id orderId) {
        Result res = new Result();
        res.created = false;
        if (orderId == null) { res.message = 'No order id.'; return res; }

        // already converted? (idempotent)
        List<WorkOrder> existing = [SELECT Id FROM WorkOrder WHERE Source_Order_Id__c = :String.valueOf(orderId) LIMIT 1];
        if (!existing.isEmpty()) {
            res.workOrderId = existing[0].Id; res.message = 'WorkOrder already exists for this order.'; res.created = false; return res;
        }

        List<OrderItem> serviceable = [
            SELECT Id, Quantity, UnitPrice, Product2Id, Product2.Name, PricebookEntryId,
                   Order.AccountId, Order.Account.Name, Order.Pricebook2Id
            FROM OrderItem
            WHERE OrderId = :orderId AND Product2.Requires_Field_Service__c = true
        ];
        if (serviceable.isEmpty()) { res.message = 'No serviceable products on this order — no field service needed.'; res.created = true; return res; }

        Id acctId = serviceable[0].Order.AccountId;
        Id territoryId = defaultTerritoryId();

        WorkOrder wo = new WorkOrder(
            AccountId = acctId,
            Subject = 'Installation / Service for ' + (serviceable[0].Order.Account != null ? serviceable[0].Order.Account.Name : 'Customer'),
            Status = 'New',
            Source_Order_Id__c = String.valueOf(orderId)
        );
        if (territoryId != null) wo.ServiceTerritoryId = territoryId;
        if (serviceable[0].Order.Pricebook2Id != null) wo.Pricebook2Id = serviceable[0].Order.Pricebook2Id; // lets WOLIs carry a product
        insert wo;

        List<WorkOrderLineItem> wolis = new List<WorkOrderLineItem>();
        for (OrderItem oi : serviceable) {
            // Product2 on a WOLI requires the parent WorkOrder's pricebook + the line's PricebookEntry.
            WorkOrderLineItem woli = new WorkOrderLineItem(
                WorkOrderId = wo.Id,
                Quantity = oi.Quantity,
                Description = oi.Product2 != null ? oi.Product2.Name : 'Service line'
            );
            if (wo.Pricebook2Id != null && oi.PricebookEntryId != null) {
                woli.PricebookEntryId = oi.PricebookEntryId;
                woli.Product2Id = oi.Product2Id;
            }
            wolis.add(woli);
        }
        try {
            insert wolis;
        } catch (DmlException e) {
            // Some contexts reject the product link on a WOLI — keep the line by description only
            // (Quantity requires a product, so drop it too).
            for (WorkOrderLineItem w : wolis) { w.Product2Id = null; w.PricebookEntryId = null; w.Quantity = null; }
            insert wolis;
        }

        ServiceAppointment sa = new ServiceAppointment(
            ParentRecordId = wo.Id,
            Status = 'None',                                  // unscheduled — the agent books it
            Subject = 'Field Service Appointment',
            EarliestStartTime = System.now().addDays(1),
            DueDate = System.now().addDays(14)
        );
        if (territoryId != null) sa.ServiceTerritoryId = territoryId;
        insert sa;

        res.workOrderId = wo.Id; res.serviceAppointmentId = sa.Id; res.created = true;
        res.message = 'Created WorkOrder ' + wo.Id + ' with ' + wolis.size() + ' line(s) and an unscheduled appointment.';
        return res;
    }

    /** First active Service Territory (demo default). */
    private static Id defaultTerritoryId() {
        List<ServiceTerritory> t = [SELECT Id FROM ServiceTerritory WHERE IsActive = true ORDER BY CreatedDate LIMIT 1];
        return t.isEmpty() ? null : t[0].Id;
    }
}
