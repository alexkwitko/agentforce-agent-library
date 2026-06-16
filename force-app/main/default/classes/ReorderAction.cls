/**
 * ReorderAction — Agentforce action: "reorder this order."
 * Wraps OrderConciergeService.reorder. One @InvocableMethod per class.
 */
public with sharing class ReorderAction {

    public class Request {
        @InvocableVariable(label='Order ID' required=true
            description='The Order record Id to clone into a new draft order.') public Id orderId;
    }
    public class Result {
        @InvocableVariable public Boolean success;
        @InvocableVariable public Id newOrderId;
        @InvocableVariable public String newOrderNumber;
        @InvocableVariable public String message;
    }

    @InvocableMethod(label='Reorder'
        description='Clones an existing order and its line items into a new draft order.')
    public static List<Result> run(List<Request> reqs) {
        List<Result> out = new List<Result>();
        for (Request r : reqs) {
            OrderConciergeService.ReorderResult rr = OrderConciergeService.reorder(r.orderId);
            Result res = new Result();
            res.success = rr.success;
            res.newOrderId = rr.newOrderId;
            res.newOrderNumber = rr.newOrderNumber;
            res.message = rr.message;
            out.add(res);
        }
        return out;
    }
}
