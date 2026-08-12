const { z } = require('zod');

const quoteRequest = z.object({
  destinationZone: z.enum(['local', 'regional', 'national']),
  weightKg: z.number().positive().max(100),
  service: z.enum(['standard', 'express']),
  customerTier: z.enum(['standard', 'business', 'enterprise']).default('standard'),
});

const zoneRates = {
  local: 1.2,
  regional: 1.8,
  national: 2.6,
};

const tierDiscounts = {
  standard: 0,
  business: 0.08,
  enterprise: 0.15,
};

function calculateQuote(input) {
  const baseCharge = 4.5;
  const expressMultiplier = input.service === 'express' ? 1.6 : 1;
  const subtotal = (baseCharge + input.weightKg * zoneRates[input.destinationZone]) * expressMultiplier;
  const discount = subtotal * tierDiscounts[input.customerTier];

  return {
    currency: 'USD',
    amount: Number((subtotal - discount).toFixed(2)),
    discount: Number(discount.toFixed(2)),
    estimatedDays: input.service === 'express' ? 1 : input.destinationZone === 'national' ? 5 : 3,
  };
}

module.exports = { quoteRequest, calculateQuote };