const test = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');
const app = require('../index');

test('returns a discounted express quote for business customers', async () => {
  const response = await request(app)
    .post('/api/quotes')
    .send({
      destinationZone: 'regional',
      weightKg: 10,
      service: 'express',
      customerTier: 'business',
    });

  assert.equal(response.status, 200);
  assert.deepEqual(response.body, {
    currency: 'USD',
    amount: 33.12,
    discount: 2.88,
    estimatedDays: 1,
  });
});

test('rejects unsupported destinations', async () => {
  const response = await request(app)
    .post('/api/quotes')
    .send({ destinationZone: 'international', weightKg: 2, service: 'standard' });

  assert.equal(response.status, 400);
  assert.equal(response.body.error, 'Invalid quote request');
});