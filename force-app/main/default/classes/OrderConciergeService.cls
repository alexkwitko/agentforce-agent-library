/**
 * OrderConciergeService — order status lookup + reorder for the Order / Commerce Concierge agent.
 *
 * lookup(): finds an order by its OrderNumber (or 18-char Id) and summarizes status + line items.
 * reorder(): clones an existing order and its items into a new Draft order.
 *
 * Returns only the single order asked about (PII-scoped). Anti-hallucination: callers must report
 * only the fields returned here, never invented order data.
 */
public without sharing class OrderConciergeService {

    public class LookupResult {
        public Boolean found = false;
        public Id orderId;
        public String orderNumber;
        public String status;
        public String accountName;
        public Decimal totalAmount;
        public Integer itemCount = 0;
        public String message;
    }
    public class ReorderResult {
        public Boolean success = false;
        public Id newOrderId;
        public String newOrderNumber;
        public String message;
    }

    public static LookupResult lookup(String orderRef) {
        LookupResult res = new LookupResult();
        if (String.isBlank(orderRef)) { res.message = 'Tell me your order number and I will look it up.'; return res; }
        orderRef = orderRef.trim();

        List<Order> orders;
        if (orderRef.length() == 15 || orderRef.length() == 18) {
            orders = ordersBy('Id', orderRef);
            if (orders.isEmpty()) orders = ordersBy('OrderNumber', orderRef);
        } else {
            orders = ordersBy('OrderNumber', orderRef);
        }
        if (orders.isEmpty()) { res.message = 'I could not find an order matching "' + orderRef + '".'; return res; }

        Order o = orders[0];
        res.found = true;
        res.orderId = o.Id;
        res.orderNumber = o.OrderNumber;
        res.status = o.Status;
        res.accountName = o.Account != null ? o.Account.Name : null;
        res.totalAmount = o.TotalAmount;
        List<OrderItem> items = [SELECT Quantity, UnitPrice, Product2.Name FROM OrderItem WHERE OrderId = :o.Id];
        res.itemCount = items.size();

        List<String> lines = new List<String>();
        for (OrderItem oi : items) {
            lines.add('• ' + (oi.Product2 != null ? oi.Product2.Name : 'Item') + ' x' + oi.Quantity);
        }
        res.message = 'Order ' + o.OrderNumber + ' is ' + o.Status + '.'
            + (items.isEmpty() ? '' : ' Items:\n' + String.join(lines, '\n'));
        return res;
    }

    private static List<Order> ordersBy(String field, String val) {
        String q = 'SELECT Id, OrderNumber, Status, TotalAmount, AccountId, Account.Name, Pricebook2Id '
                 + 'FROM Order WHERE ' + field + ' = :val LIMIT 1';
        return Database.query(q);
    }

    public static ReorderResult reorder(Id orderId) {
        ReorderResult res = new ReorderResult();
        if (orderId == null) { res.message = 'No order id provided.'; return res; }

        List<Order> src = [SELECT Id, AccountId, Pricebook2Id FROM Order WHERE Id = :orderId LIMIT 1];
        if (src.isEmpty()) { res.message = 'Original order not found.'; return res; }
        Order o = src[0];

        Order copy = new Order(AccountId = o.AccountId, EffectiveDate = Date.today(), Status = 'Draft');
        if (o.Pricebook2Id != null) copy.Pricebook2Id = o.Pricebook2Id;
        insert copy;

        List<OrderItem> items = [SELECT Product2Id, PricebookEntryId, Quantity, UnitPrice FROM OrderItem WHERE OrderId = :orderId];
        List<OrderItem> clones = new List<OrderItem>();
        for (OrderItem oi : items) {
            clones.add(new OrderItem(OrderId = copy.Id, Product2Id = oi.Product2Id,
                PricebookEntryId = oi.PricebookEntryId, Quantity = oi.Quantity, UnitPrice = oi.UnitPrice));
        }
        if (!clones.isEmpty()) insert clones;

        Order created = [SELECT OrderNumber FROM Order WHERE Id = :copy.Id LIMIT 1];
        res.success = true;
        res.newOrderId = copy.Id;
        res.newOrderNumber = created.OrderNumber;
        res.message = 'Created a new draft order ' + created.OrderNumber + ' with ' + clones.size() + ' item(s).';
        return res;
    }
}
