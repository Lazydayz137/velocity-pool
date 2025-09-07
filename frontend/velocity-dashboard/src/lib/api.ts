import axios from 'axios';
import { io, Socket } from 'socket.io-client';

// API Configuration
const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:4000';
const WS_URL = process.env.NEXT_PUBLIC_WS_URL || 'ws://localhost:4000';

// Create axios instance
export const api = axios.create({
  baseURL: `${API_BASE_URL}/api`,
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Types for pool data
export interface PoolStats {
  id: string;
  name: string;
  coin: string;
  algorithm: string;
  hashrate: number;
  miners: number;
  blocks: number;
  lastBlockTime?: string;
  difficulty: number;
  networkHashrate: number;
  poolFee: number;
  minPayout: number;
}

export interface MinerStats {
  address: string;
  hashrate: number;
  shares: {
    valid: number;
    invalid: number;
    stale: number;
  };
  payments: {
    pending: number;
    paid: number;
    total: number;
  };
  workers: Array<{
    name: string;
    hashrate: number;
    lastSeen: string;
    difficulty: number;
  }>;
}

export interface Block {
  height: number;
  hash: string;
  timestamp: string;
  reward: number;
  difficulty: number;
  confirmations: number;
  status: 'pending' | 'confirmed' | 'orphaned';
}

export interface Payment {
  id: string;
  address: string;
  amount: number;
  transaction: string;
  timestamp: string;
  status: 'pending' | 'confirmed' | 'failed';
}

// API Functions
export const poolApi = {
  // Get all pools
  async getPools(): Promise<PoolStats[]> {
    const response = await api.get('/pools');
    return response.data;
  },

  // Get specific pool stats
  async getPoolStats(poolId: string): Promise<PoolStats> {
    const response = await api.get(`/pools/${poolId}/stats`);
    return response.data;
  },

  // Get miner stats
  async getMinerStats(poolId: string, address: string): Promise<MinerStats> {
    const response = await api.get(`/pools/${poolId}/miners/${address}`);
    return response.data;
  },

  // Get recent blocks
  async getBlocks(poolId: string, limit = 25): Promise<Block[]> {
    const response = await api.get(`/pools/${poolId}/blocks?limit=${limit}`);
    return response.data;
  },

  // Get payments
  async getPayments(poolId: string, limit = 25): Promise<Payment[]> {
    const response = await api.get(`/pools/${poolId}/payments?limit=${limit}`);
    return response.data;
  },

  // Get miner payments
  async getMinerPayments(poolId: string, address: string): Promise<Payment[]> {
    const response = await api.get(`/pools/${poolId}/miners/${address}/payments`);
    return response.data;
  },
};

// WebSocket connection for real-time updates
export class WebSocketService {
  private socket: Socket | null = null;
  private callbacks: Map<string, Function[]> = new Map();

  connect() {
    if (this.socket?.connected) return;

    this.socket = io(WS_URL);

    this.socket.on('connect', () => {
      console.log('WebSocket connected');
    });

    this.socket.on('disconnect', () => {
      console.log('WebSocket disconnected');
    });

    // Handle real-time events
    this.socket.on('block', (data) => {
      this.emit('block', data);
    });

    this.socket.on('payment', (data) => {
      this.emit('payment', data);
    });

    this.socket.on('stats', (data) => {
      this.emit('stats', data);
    });

    this.socket.on('hashrate', (data) => {
      this.emit('hashrate', data);
    });
  }

  disconnect() {
    this.socket?.disconnect();
    this.socket = null;
  }

  on(event: string, callback: Function) {
    if (!this.callbacks.has(event)) {
      this.callbacks.set(event, []);
    }
    this.callbacks.get(event)?.push(callback);
  }

  off(event: string, callback: Function) {
    const callbacks = this.callbacks.get(event);
    if (callbacks) {
      const index = callbacks.indexOf(callback);
      if (index > -1) {
        callbacks.splice(index, 1);
      }
    }
  }

  private emit(event: string, data: any) {
    const callbacks = this.callbacks.get(event);
    callbacks?.forEach(callback => callback(data));
  }
}

export const wsService = new WebSocketService();
