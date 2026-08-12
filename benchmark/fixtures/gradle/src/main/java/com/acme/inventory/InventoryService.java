package com.acme.inventory;

import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import org.springframework.stereotype.Service;

@Service
public class InventoryService {
    private final Map<String, AtomicInteger> stock = new ConcurrentHashMap<>();

    public StockItem replenish(String sku, int quantity) {
        if (quantity < 1) {
            throw new IllegalArgumentException("Replenishment quantity must be positive");
        }
        int available = stock.computeIfAbsent(sku, ignored -> new AtomicInteger()).addAndGet(quantity);
        return new StockItem(sku, available, Instant.now());
    }

    public StockItem reserve(String sku, int quantity) {
        AtomicInteger available = stock.computeIfAbsent(sku, ignored -> new AtomicInteger());
        while (true) {
            int current = available.get();
            if (current < quantity) {
                throw new InsufficientStockException(sku, quantity, current);
            }
            if (available.compareAndSet(current, current - quantity)) {
                return new StockItem(sku, current - quantity, Instant.now());
            }
        }
    }

    public StockItem get(String sku) {
        return new StockItem(sku, stock.getOrDefault(sku, new AtomicInteger()).get(), Instant.now());
    }
}