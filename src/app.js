"use strict";

const fastify = require("fastify")({ logger: true });

// The environment variables we want to display
const DEMO_ENV_VARS = [
  "DEMO_API_KEY",
  "DEMO_DATABASE_URL",
  "DEMO_ENCRYPTION_KEY",
  "DEMO_SERVICE_URL",
  "DEMO_SECRET_TOKEN",
  "API_URL",
  "APPLICATION_CODE",
  "PHASE_APP",
  "PHASE_ENVIRONMENT",
];

// Register routes
fastify.get("/", async (request, reply) => {
  return { message: "Phase secrets demo app is running!" };
});

fastify.get("/env", async (request, reply) => {
  const envVars = {};
  DEMO_ENV_VARS.forEach((varName) => {
    envVars[varName] = process.env[varName] || "Not set";
  });

  return {
    app: process.env.PHASE_APP || "Not set",
    environment: process.env.PHASE_ENVIRONMENT || "Not set",
    variables: envVars,
  };
});

// Start server
const start = async () => {
  try {
    await fastify.listen({ port: 3000, host: "0.0.0.0" });
  } catch (err) {
    fastify.log.error(err);
    process.exit(1);
  }
};

start();
