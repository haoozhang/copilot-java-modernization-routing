package com.acme.orders;

import java.math.BigDecimal;
import javax.validation.constraints.DecimalMin;
import javax.validation.constraints.Min;
import javax.validation.constraints.NotBlank;
import javax.validation.constraints.NotNull;

public class CreateOrderRequest {
    @NotBlank
    public String customerId;
    @NotBlank
    public String sku;
    @Min(1)
    public int quantity;
    @NotNull
    @DecimalMin("0.01")
    public BigDecimal unitPrice;
    public String couponCode;
}