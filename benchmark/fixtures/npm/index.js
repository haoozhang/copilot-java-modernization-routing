const express = require('express');
const { ZodError } = require('zod');
const { quoteRequest, calculateQuote } = require('./src/pricing');

const app = express();
app.use(express.json());

app.post('/api/quotes', (request, response, next) => {
	try {
		const input = quoteRequest.parse(request.body);
		response.json(calculateQuote(input));
	} catch (error) {
		next(error);
	}
});

app.use((error, request, response, next) => {
	if (error instanceof ZodError) {
		response.status(400).json({ error: 'Invalid quote request', issues: error.issues });
		return;
	}
	next(error);
});

if (require.main === module) {
	const port = Number(process.env.PORT || 3000);
	app.listen(port, () => console.log(`Quote service listening on ${port}`));
}

module.exports = app;