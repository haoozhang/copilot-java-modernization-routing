package com.acme.inventory;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;

class InventoryServiceTest {
    @Test
    void reservesAvailableStock() {
        InventoryService service = new InventoryService();
        service.replenish("COFFEE-1KG", 12);

        StockItem remaining = service.reserve("COFFEE-1KG", 5);

        assertThat(remaining.getAvailable()).isEqualTo(7);
    }

    @Test
    void rejectsReservationThatWouldOversell() {
        InventoryService service = new InventoryService();
        service.replenish("COFFEE-1KG", 2);

        assertThatThrownBy(() -> service.reserve("COFFEE-1KG", 3))
            .isInstanceOf(InsufficientStockException.class)
            .hasMessageContaining("only 2 remain");
    }
}