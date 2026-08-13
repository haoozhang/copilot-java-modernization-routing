package com.acme.inventory;

import javax.validation.constraints.Min;
import javax.validation.constraints.NotBlank;

public class ReservationRequest {
    @NotBlank
    public String sku;
    @Min(1)
    public int quantity;
}