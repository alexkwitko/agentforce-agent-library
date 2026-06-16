/**
 * LookupOrderAction — Agentforce action: "look up my order."
 * Wraps OrderConciergeService.lookup. One @InvocableMethod per class.
 */
public with sharing class LookupOrderAction {

    public class Request {
        @InvocableVariable(label='Order Number or ID' required=true
            description='The OrderNumber (e.g. 00000123) or 18-char Order Id.') public String orderRef;
    }
    public class Result {
        @InvocableVariable public Boolean found;
        @InvocableVariable public Id orderId;
        @InvocableVariable public String orderNumber;
        @InvocableVariable public String status;
        @InvocableVariable public Integer itemCount;
        @InvocableVariable public String message;
    }

    @InvocableMethod(label='Look Up Order'
        description='Finds an order by number or id and summarizes its status and line items.')
    public static List<Result> run(List<Request> reqs) {
        List<Result> out = new List<Result>();
        for (Request r : reqs) {
            OrderConciergeService.LookupResult lr = OrderConciergeService.lookup(r.orderRef);
            Result res = new Result();
            res.found = lr.found;
            res.orderId = lr.orderId;
            res.orderNumber = lr.orderNumber;
            res.status = lr.status;
            res.itemCount = lr.itemCount;
            res.message = lr.message;
            out.add(res);
        }
        return out;
    }
}
