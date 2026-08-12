package com.acme.orders;

import java.math.BigDecimal;
import java.time.Instant;
import javax.persistence.Entity;
import javax.persistence.GeneratedValue;
import javax.persistence.Id;

@Entity
public class Order {
    @Id
    @GeneratedValue
    private Long id;
    private String customerId;
    private String sku;
    private int quantity;
    private BigDecimal unitPrice;
    private BigDecimal total;
    private Instant createdAt;

    protected Order() {
    }

    public Order(String customerId, String sku, int quantity, BigDecimal unitPrice, BigDecimal total) {
        this.customerId = customerId;
        this.sku = sku;
        this.quantity = quantity;
        this.unitPrice = unitPrice;
        this.total = total;
        this.createdAt = Instant.now();
    }

    public Long getId() { return id; }
    public String getCustomerId() { return customerId; }
    public String getSku() { return sku; }
    public int getQuantity() { return quantity; }
    public BigDecimal getUnitPrice() { return unitPrice; }
    public BigDecimal getTotal() { return total; }
    public Instant getCreatedAt() { return createdAt; }
}