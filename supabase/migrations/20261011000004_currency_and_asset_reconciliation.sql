-- ==============================================================================
-- Migration: 20261011000004_currency_and_asset_reconciliation.sql
-- Description: Sets up canonical asset mapping registry and reconciles
--              legacy asset identifiers (e.g. 'btc' -> 'bitcoin').
-- ==============================================================================

-- 1. Canonical Assets Registry
CREATE TABLE IF NOT EXISTS public.canonical_assets (
    symbol TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    coingecko_id TEXT NOT NULL,
    binance_symbol TEXT NOT NULL,
    decimals INT DEFAULT 8,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Populate common Top Binance / CoinGecko assets
INSERT INTO public.canonical_assets (symbol, name, coingecko_id, binance_symbol, decimals)
VALUES
    ('BTC', 'Bitcoin', 'bitcoin', 'BTCUSDT', 8),
    ('ETH', 'Ethereum', 'ethereum', 'ETHUSDT', 8),
    ('SOL', 'Solana', 'solana', 'SOLUSDT', 6),
    ('BNB', 'BNB', 'binancecoin', 'BNBUSDT', 4),
    ('XRP', 'XRP', 'ripple', 'XRPUSDT', 6),
    ('ADA', 'Cardano', 'cardano', 'ADAUSDT', 6),
    ('DOGE', 'Dogecoin', 'dogecoin', 'DOGEUSDT', 6),
    ('AVAX', 'Avalanche', 'avalanche-2', 'AVAXUSDT', 6),
    ('DOT', 'Polkadot', 'polkadot', 'DOTUSDT', 4),
    ('LINK', 'Chainlink', 'chainlink', 'LINKUSDT', 4),
    ('MATIC', 'Polygon', 'matic-network', 'MATICUSDT', 4),
    ('PEPE', 'Pepe', 'pepe', 'PEPEUSDT', 8),
    ('SUI', 'Sui', 'sui', 'SUIUSDT', 6),
    ('NEAR', 'NEAR Protocol', 'near', 'NEARUSDT', 6),
    ('TRX', 'TRON', 'tron', 'TRXUSDT', 6),
    ('SHIB', 'Shiba Inu', 'shiba-inu', 'SHIBUSDT', 8),
    ('LTC', 'Litecoin', 'litecoin', 'LTCUSDT', 8)
ON CONFLICT (symbol) DO NOTHING;

ALTER TABLE public.canonical_assets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "canonical_assets_read" ON public.canonical_assets;
CREATE POLICY "canonical_assets_read" ON public.canonical_assets FOR SELECT TO authenticated USING (true);

-- 2. Data Reconciliation for Existing Transactions & Holdings
-- Normalize any 'btc' or ticker-based coin_id into canonical coingecko_id
UPDATE public.transactions t
SET coin_id = c.coingecko_id
FROM public.canonical_assets c
WHERE UPPER(t.symbol) = c.symbol AND (t.coin_id IS NULL OR t.coin_id = LOWER(t.symbol));

UPDATE public.holdings h
SET coin_id = c.coingecko_id
FROM public.canonical_assets c
WHERE UPPER(h.symbol) = c.symbol AND (h.coin_id IS NULL OR h.coin_id = LOWER(h.symbol));
