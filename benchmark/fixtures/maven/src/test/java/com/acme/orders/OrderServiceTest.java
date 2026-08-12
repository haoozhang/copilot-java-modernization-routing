package com.acme.orders;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import org.junit.jupiter.api.Test;

class OrderServiceTest {
    @Test
    void combinesBulkAndCouponDiscounts() {
        OrderRepository repository = mock(OrderRepository.class);
        when(repository.save(org.mockito.ArgumentMatchers.any(Order.class)))
            .thenAnswer(invocation -> invocation.getArgument(0));
        OrderService service = new OrderService(repository);
        CreateOrderRequest request = new CreateOrderRequest();
        request.customerId = "customer-42";
        request.sku = "COFFEE-1KG";
        request.quantity = 10;
        request.unitPrice = new BigDecimal("12.50");
        request.couponCode = "SAVE5";

        Order order = service.place(request);

        assertThat(order.getTotal()).isEqualByComparingTo("106.25");
    }
}