package com.acme.inventory;

import java.time.Instant;
import jakarta.annotation.Generated;

@Generated("inventory-service")
public class StockItem {
    private final String sku;
    private final int available;
    private final Instant updatedAt;

    public StockItem(String sku, int available, Instant updatedAt) {
        this.sku = sku;
        this.available = available;
        this.updatedAt = updatedAt;
    }

    public String getSku() { return sku; }
    public int getAvailable() { return available; }
    public Instant getUpdatedAt() { return updatedAt; }
}