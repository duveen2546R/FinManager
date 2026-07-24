// Central place for the backend API configuration.
// Mirrors the old Flutter lib/Screens/config.dart AppConfig.
export const BASE_URL = 'http://savorgo.centralindia.cloudapp.azure.com:5001';

export const Endpoints = {
  register: `${BASE_URL}/register`,
  login: `${BASE_URL}/login`,
  addTransaction: `${BASE_URL}/transaction`,
  getTransactions: `${BASE_URL}/transactions`, // append /:userId
  aiAgent: `${BASE_URL}/ai/agent/invoke`,
};
