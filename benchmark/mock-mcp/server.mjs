import { createInterface } from 'node:readline';

const extensionOption = 'Use GitHub Copilot modernization extension';
const manualOption = 'Continue in the current chat';

const questionSchema = {
  type: 'object',
  additionalProperties: false,
  required: ['questions'],
  properties: {
    questions: {
      type: 'array',
      minItems: 1,
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['header', 'question'],
        properties: {
          header: { type: 'string', maxLength: 50 },
          question: { type: 'string', maxLength: 200 },
          multiSelect: { type: 'boolean' },
          allowFreeformInput: { type: 'boolean' },
          message: { type: 'string' },
          options: {
            type: 'array',
            items: {
              type: 'object',
              additionalProperties: false,
              required: ['label'],
              properties: {
                label: { type: 'string' },
                description: { type: 'string' },
                recommended: { type: 'boolean' }
              }
            }
          }
        }
      }
    }
  }
};

function write(message) {
  process.stdout.write(`${JSON.stringify(message)}\n`);
}

function result(id, value) {
  write({ jsonrpc: '2.0', id, result: value });
}

function error(id, code, message) {
  write({ jsonrpc: '2.0', id, error: { code, message } });
}

function validateQuestion(argumentsValue) {
  const questions = argumentsValue?.questions;
  if (!Array.isArray(questions) || questions.length !== 1) {
    return 'Expected exactly one question.';
  }

  const question = questions[0];
  if (question.allowFreeformInput !== false) {
    return 'allowFreeformInput must be false.';
  }
  if (question.multiSelect === true) {
    return 'multiSelect must not be true.';
  }

  const labels = question.options?.map((option) => option.label);
  if (labels?.length !== 2 || labels[0] !== extensionOption || labels[1] !== manualOption) {
    return 'Expected the extension and current-chat options in that order.';
  }
  if (question.options[0].recommended !== true) {
    return 'The extension option must be recommended.';
  }

  return null;
}

const input = createInterface({ input: process.stdin, crlfDelay: Infinity });
input.on('line', (line) => {
  if (!line.trim()) return;

  let request;
  try {
    request = JSON.parse(line);
  } catch {
    error(null, -32700, 'Parse error');
    return;
  }

  if (request.method === 'initialize') {
    result(request.id, {
      protocolVersion: request.params?.protocolVersion ?? '2025-06-18',
      capabilities: { tools: {} },
      serverInfo: { name: 'vscode-question-benchmark', version: '1.0.0' }
    });
    return;
  }

  if (request.method === 'tools/list') {
    result(request.id, {
      tools: [{
        name: 'vscode_askQuestions',
        description: 'Ask the user one or more structured questions in VS Code.',
        inputSchema: questionSchema
      }]
    });
    return;
  }

  if (request.method === 'tools/call') {
    if (request.params?.name !== 'vscode_askQuestions') {
      error(request.id, -32602, `Unknown tool: ${request.params?.name}`);
      return;
    }

    const validationError = validateQuestion(request.params.arguments);
    if (validationError) {
      result(request.id, { isError: true, content: [{ type: 'text', text: validationError }] });
      return;
    }

    result(request.id, {
      content: [{
        type: 'text',
        text: JSON.stringify({ answers: [{ header: request.params.arguments.questions[0].header, answer: manualOption }] })
      }]
    });
    return;
  }

  if (request.id !== undefined) {
    error(request.id, -32601, `Method not found: ${request.method}`);
  }
});