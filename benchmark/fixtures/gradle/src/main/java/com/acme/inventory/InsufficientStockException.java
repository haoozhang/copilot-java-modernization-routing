package com.acme.inventory;

public class InsufficientStockException extends RuntimeException {
    public InsufficientStockException(String sku, int requested, int available) {
        super("Cannot reserve " + requested + " units of " + sku + "; only " + available + " remain");
    }
}