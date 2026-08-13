package com.acme.sales;

import java.io.IOException;
import java.io.Reader;
import java.math.BigDecimal;
import org.apache.commons.csv.CSVFormat;
import org.apache.commons.csv.CSVRecord;

public class SalesReportService {
    public SalesSummary summarize(Reader source) throws IOException {
        int completed = 0;
        int refunded = 0;
        BigDecimal revenue = BigDecimal.ZERO;
        Iterable<CSVRecord> records = CSVFormat.DEFAULT.builder()
            .setHeader()
            .setSkipHeaderRecord(true)
            .build()
            .parse(source);

        for (CSVRecord record : records) {
            BigDecimal amount = new BigDecimal(record.get("amount"));
            String status = record.get("status");
            if (amount.signum() < 0) {
                throw new IllegalArgumentException("Order amount cannot be negative");
            }
            if ("COMPLETED".equals(status)) {
                completed++;
                revenue = revenue.add(amount);
            } else if ("REFUNDED".equals(status)) {
                refunded++;
                revenue = revenue.subtract(amount);
            }
        }
        return new SalesSummary(completed, refunded, revenue);
    }
}