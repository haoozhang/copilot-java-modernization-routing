package com.acme.sales;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.io.StringReader;
import java.math.BigDecimal;
import org.junit.jupiter.api.Test;

class SalesReportServiceTest {
    private final SalesReportService service = new SalesReportService();

    @Test
    void calculatesNetRevenueAcrossCompletedAndRefundedOrders() throws Exception {
        String csv = "order_id,amount,status\nA-1,40.00,COMPLETED\nA-2,12.50,REFUNDED\nA-3,20.00,COMPLETED\n";

        SalesSummary summary = service.summarize(new StringReader(csv));

        assertEquals(2, summary.completedOrders());
        assertEquals(1, summary.refundedOrders());
        assertEquals(new BigDecimal("47.50"), summary.netRevenue());
    }

    @Test
    void rejectsNegativeAmounts() {
        String csv = "order_id,amount,status\nA-1,-1.00,COMPLETED\n";

        assertThrows(IllegalArgumentException.class, () -> service.summarize(new StringReader(csv)));
    }
}