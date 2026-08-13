package com.acme.orders;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;
import javax.annotation.PostConstruct;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class OrderService {
    private static final BigDecimal BULK_DISCOUNT = new BigDecimal("0.10");
    private static final BigDecimal COUPON_DISCOUNT = new BigDecimal("0.05");

    private final OrderRepository repository;

    public OrderService(OrderRepository repository) {
        this.repository = repository;
    }

    @PostConstruct
    void validateDiscountConfiguration() {
        if (BULK_DISCOUNT.add(COUPON_DISCOUNT).compareTo(BigDecimal.ONE) >= 0) {
            throw new IllegalStateException("Combined discounts must remain below 100%");
        }
    }

    @Transactional
    public Order place(CreateOrderRequest request) {
        BigDecimal subtotal = request.unitPrice.multiply(BigDecimal.valueOf(request.quantity));
        BigDecimal discount = BigDecimal.ZERO;
        if (request.quantity >= 10) {
            discount = discount.add(BULK_DISCOUNT);
        }
        if ("SAVE5".equalsIgnoreCase(request.couponCode)) {
            discount = discount.add(COUPON_DISCOUNT);
        }
        BigDecimal total = subtotal.multiply(BigDecimal.ONE.subtract(discount))
            .setScale(2, RoundingMode.HALF_UP);
        return repository.save(new Order(request.customerId, request.sku, request.quantity, request.unitPrice, total));
    }

    public List<Order> ordersFor(String customerId) {
        return repository.findByCustomerIdOrderByCreatedAtDesc(customerId);
    }
}