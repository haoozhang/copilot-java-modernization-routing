package com.acme.sales;

import java.io.FileReader;
import java.nio.charset.StandardCharsets;

public class SalesReportCli {
    public static void main(String[] args) throws Exception {
        if (args.length != 1) {
            throw new IllegalArgumentException("Usage: SalesReportCli <sales.csv>");
        }
        try (FileReader reader = new FileReader(args[0], StandardCharsets.UTF_8)) {
            SalesSummary summary = new SalesReportService().summarize(reader);
            System.out.printf("Completed: %d, refunded: %d, net revenue: %s%n",
                summary.completedOrders(), summary.refundedOrders(), summary.netRevenue());
        }
    }
}