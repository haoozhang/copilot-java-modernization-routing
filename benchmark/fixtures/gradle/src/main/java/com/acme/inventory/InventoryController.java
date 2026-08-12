package com.acme.inventory;

import javax.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/inventory")
public class InventoryController {
    private final InventoryService service;

    public InventoryController(InventoryService service) {
        this.service = service;
    }

    @GetMapping("/{sku}")
    public StockItem get(@PathVariable String sku) {
        return service.get(sku);
    }

    @PostMapping("/reserve")
    public StockItem reserve(@Valid @RequestBody ReservationRequest request) {
        return service.reserve(request.sku, request.quantity);
    }

    @PostMapping("/{sku}/replenish/{quantity}")
    @ResponseStatus(HttpStatus.CREATED)
    public StockItem replenish(@PathVariable String sku, @PathVariable int quantity) {
        return service.replenish(sku, quantity);
    }
}