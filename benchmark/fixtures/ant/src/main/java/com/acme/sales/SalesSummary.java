package com.acme.sales;

import java.math.BigDecimal;
import javax.annotation.Generated;

@Generated("sales-report")
public record SalesSummary(int completedOrders, int refundedOrders, BigDecimal netRevenue) {
}