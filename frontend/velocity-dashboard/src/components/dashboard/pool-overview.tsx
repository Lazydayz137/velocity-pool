"use client";

import { useState, useEffect } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Button } from '@/components/ui/button';
import { PoolStats, poolApi, wsService } from '@/lib/api';
import { Activity, Zap, Users, Blocks, TrendingUp, RefreshCw } from 'lucide-react';

export function PoolOverview() {
  const [pools, setPools] = useState<PoolStats[]>([]);
  const [selectedPool, setSelectedPool] = useState<string>('');
  const [loading, setLoading] = useState(true);
  const [lastUpdate, setLastUpdate] = useState<Date>(new Date());

  useEffect(() => {
    loadPools();
    
    // Connect to WebSocket for real-time updates
    wsService.connect();
    
    const handleStatsUpdate = (data: any) => {
      setLastUpdate(new Date());
      // Update specific pool stats
      setPools(prev => prev.map(pool => 
        pool.id === data.poolId ? { ...pool, ...data } : pool
      ));
    };

    wsService.on('stats', handleStatsUpdate);

    return () => {
      wsService.off('stats', handleStatsUpdate);
    };
  }, []);

  const loadPools = async () => {
    try {
      setLoading(true);
      const poolData = await poolApi.getPools();
      setPools(poolData);
      if (poolData.length > 0 && !selectedPool) {
        setSelectedPool(poolData[0].id);
      }
    } catch (error) {
      console.error('Failed to load pools:', error);
    } finally {
      setLoading(false);
    }
  };

  const formatHashrate = (hashrate: number): string => {
    if (hashrate >= 1e12) return `${(hashrate / 1e12).toFixed(2)} TH/s`;
    if (hashrate >= 1e9) return `${(hashrate / 1e9).toFixed(2)} GH/s`;
    if (hashrate >= 1e6) return `${(hashrate / 1e6).toFixed(2)} MH/s`;
    if (hashrate >= 1e3) return `${(hashrate / 1e3).toFixed(2)} KH/s`;
    return `${hashrate.toFixed(2)} H/s`;
  };

  const formatDifficulty = (difficulty: number): string => {
    if (difficulty >= 1e12) return `${(difficulty / 1e12).toFixed(2)}T`;
    if (difficulty >= 1e9) return `${(difficulty / 1e9).toFixed(2)}G`;
    if (difficulty >= 1e6) return `${(difficulty / 1e6).toFixed(2)}M`;
    if (difficulty >= 1e3) return `${(difficulty / 1e3).toFixed(2)}K`;
    return difficulty.toFixed(0);
  };

  const currentPool = pools.find(p => p.id === selectedPool);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <RefreshCw className="h-8 w-8 animate-spin" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Velocity Pool Dashboard</h1>
          <p className="text-muted-foreground">
            Monitor your mining pools in real-time • Last updated: {lastUpdate.toLocaleTimeString()}
          </p>
        </div>
        <Button onClick={loadPools} variant="outline" size="sm">
          <RefreshCw className="h-4 w-4 mr-2" />
          Refresh
        </Button>
      </div>

      {/* Pool Selection Tabs */}
      <Tabs value={selectedPool} onValueChange={setSelectedPool}>
        <TabsList className="grid w-full grid-cols-4">
          {pools.map((pool) => (
            <TabsTrigger key={pool.id} value={pool.id} className="flex items-center gap-2">
              <Badge variant="secondary">{pool.coin}</Badge>
              {pool.name}
            </TabsTrigger>
          ))}
        </TabsList>

        {pools.map((pool) => (
          <TabsContent key={pool.id} value={pool.id} className="space-y-6">
            {/* Stats Cards */}
            <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
              <Card>
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                  <CardTitle className="text-sm font-medium">Pool Hashrate</CardTitle>
                  <Zap className="h-4 w-4 text-muted-foreground" />
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold">{formatHashrate(pool.hashrate)}</div>
                  <p className="text-xs text-muted-foreground">
                    {((pool.hashrate / pool.networkHashrate) * 100).toFixed(2)}% of network
                  </p>
                </CardContent>
              </Card>

              <Card>
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                  <CardTitle className="text-sm font-medium">Active Miners</CardTitle>
                  <Users className="h-4 w-4 text-muted-foreground" />
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold">{pool.miners.toLocaleString()}</div>
                  <p className="text-xs text-muted-foreground">
                    Currently mining {pool.coin}
                  </p>
                </CardContent>
              </Card>

              <Card>
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                  <CardTitle className="text-sm font-medium">Blocks Found</CardTitle>
                  <Blocks className="h-4 w-4 text-muted-foreground" />
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold">{pool.blocks.toLocaleString()}</div>
                  <p className="text-xs text-muted-foreground">
                    {pool.lastBlockTime ? `Last: ${new Date(pool.lastBlockTime).toLocaleTimeString()}` : 'No blocks yet'}
                  </p>
                </CardContent>
              </Card>

              <Card>
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                  <CardTitle className="text-sm font-medium">Network Difficulty</CardTitle>
                  <TrendingUp className="h-4 w-4 text-muted-foreground" />
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold">{formatDifficulty(pool.difficulty)}</div>
                  <p className="text-xs text-muted-foreground">
                    Algorithm: {pool.algorithm}
                  </p>
                </CardContent>
              </Card>
            </div>

            {/* Pool Details */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <Activity className="h-5 w-5" />
                  Pool Information
                </CardTitle>
                <CardDescription>
                  Configuration and payout details for {pool.name}
                </CardDescription>
              </CardHeader>
              <CardContent className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
                <div>
                  <dt className="text-sm font-medium text-muted-foreground">Pool Fee</dt>
                  <dd className="text-lg font-semibold">{pool.poolFee}%</dd>
                </div>
                <div>
                  <dt className="text-sm font-medium text-muted-foreground">Min Payout</dt>
                  <dd className="text-lg font-semibold">{pool.minPayout} {pool.coin}</dd>
                </div>
                <div>
                  <dt className="text-sm font-medium text-muted-foreground">Network Hashrate</dt>
                  <dd className="text-lg font-semibold">{formatHashrate(pool.networkHashrate)}</dd>
                </div>
              </CardContent>
            </Card>
          </TabsContent>
        ))}
      </Tabs>
    </div>
  );
}
