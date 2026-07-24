import axios from 'axios';
import { Endpoints } from '../config';
import { transactionFromJson } from '../models';

const http = axios.create({
  headers: { 'Content-Type': 'application/json' },
  timeout: 30000,
  // Do not throw on non-2xx; we inspect status/body ourselves like the Flutter code did.
  validateStatus: () => true,
});

export const Api = {
  async register(body) {
    const res = await http.post(Endpoints.register, body);
    if (res.status === 201 && res.data?.status === 'success') {
      return { user_id: res.data.user_id };
    }
    throw new Error(res.data?.message ?? 'Registration failed.');
  },

  async login(email, password) {
    const res = await http.post(Endpoints.login, { email, password });
    if (res.status === 200 && res.data?.status === 'success') {
      return {
        user_id: res.data.user_id,
        name: res.data.name,
        email: res.data.email ?? email,
        phone_no: res.data.phone_no,
      };
    }
    throw new Error(res.data?.message ?? 'Invalid email or password');
  },

  async addTransaction(body) {
    const res = await http.post(Endpoints.addTransaction, body);
    if (res.status !== 201) {
      throw new Error(res.data?.message ?? 'Failed to add transaction.');
    }
  },

  async getTransactions(userId) {
    const res = await http.get(`${Endpoints.getTransactions}/${userId}`);
    if (res.status === 200 && res.data?.status === 'success') {
      const list = res.data.transactions ?? [];
      return list.map(transactionFromJson);
    }
    throw new Error(res.data?.message ?? 'Failed to load data.');
  },

  async askAgent(userId, question) {
    const res = await http.post(Endpoints.aiAgent, {
      user_id: userId,
      question,
      current_date: new Date().toISOString(),
    });
    if (res.status === 200 && res.data?.status === 'success') {
      return res.data.answer;
    }
    return res.data?.message ?? 'Sorry, I encountered an error.';
  },
};
