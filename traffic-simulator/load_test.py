#!/usr/bin/env python3
"""
Simple load test script for Lakebase PostgreSQL
Uses connection pooling for efficient connection management
"""
import psycopg2
from psycopg2 import pool
import time
import os
from dotenv import load_dotenv
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
import random

# Load environment variables
load_dotenv('../.env')

# Database configuration
DB_CONFIG = {
    'host': os.getenv('DB_HOST'),
    'port': int(os.getenv('DB_PORT', 5432)),
    'database': os.getenv('DB_NAME'),
    'user': os.getenv('DB_USER'),
    'password': os.getenv('DB_PASSWORD'),
    'sslmode': 'require'
}

# Global connection pool (will be initialized in run_load_test)
connection_pool = None

# Test queries - ultra-optimized for maximum throughput
# Mix of simple COUNT and LIMIT queries for realistic workload
QUERIES = [
    "SELECT COUNT(*) FROM orders",
    "SELECT COUNT(*) FROM products",
    "SELECT COUNT(*) FROM inventory", 
    "SELECT COUNT(*) FROM stores",
    "SELECT COUNT(*) FROM notifications",
    "SELECT * FROM products LIMIT 1",
    "SELECT * FROM stores LIMIT 1",
    "SELECT * FROM orders LIMIT 1",
    "SELECT * FROM inventory LIMIT 1",
    "SELECT * FROM notifications LIMIT 1",
    "SELECT product_id, product_name FROM products LIMIT 3",
    "SELECT store_id, store_name FROM stores LIMIT 3",
]

def execute_query_batch(worker_id, queries, duration_seconds, start_time):
    """Execute multiple queries using connection pool for better performance"""
    results = []
    conn = None
    
    # Stagger connection creation to avoid rate limiting (50ms per worker)
    delay = worker_id * 0.05
    time.sleep(delay)
    
    try:
        # Get connection from pool
        conn = connection_pool.getconn()
        cursor = conn.cursor()
        
        query_count = 0
        while (time.time() - start_time) < duration_seconds:
            query = random.choice(queries)
            query_start = time.time()
            
            try:
                cursor.execute(query)
                result = cursor.fetchall()
                latency = (time.time() - query_start) * 1000
                
                results.append({
                    'query_id': f"{worker_id}-{query_count}",
                    'query': query[:60] + '...' if len(query) > 60 else query,
                    'latency': latency,
                    'success': True,
                    'row_count': len(result)
                })
            except Exception as e:
                latency = (time.time() - query_start) * 1000
                results.append({
                    'query_id': f"{worker_id}-{query_count}",
                    'query': query[:60] + '...' if len(query) > 60 else query,
                    'latency': latency,
                    'success': False,
                    'error': str(e)
                })
            
            query_count += 1
            # No sleep - maximize throughput!
        
        cursor.close()
        # Return connection to pool instead of closing it
        if conn:
            connection_pool.putconn(conn)
        
    except Exception as e:
        print(f"Worker {worker_id} connection error: {e}")
        # Return connection to pool even on error
        if conn:
            connection_pool.putconn(conn)
    
    return results

def run_load_test(duration_seconds=15, concurrent_workers=200):
    """
    Run load test for specified duration
    
    Args:
        duration_seconds: How long to run the test
        concurrent_workers: Number of concurrent workers (share connection pool)
    """
    global connection_pool
    
    # Calculate optimal pool size (50% of concurrent workers, min 20, max 100)
    pool_size = max(20, min(100, concurrent_workers // 2))
    
    print("\n" + "=" * 70)
    print("🚀  LAKEBASE POSTGRESQL PERFORMANCE DEMO")
    print("=" * 70)
    print(f"📊 Test Configuration:")
    print(f"   💾 Database: Lakebase PostgreSQL")
    print(f"   ⏱️  Duration: {duration_seconds} seconds")
    print(f"   🔗 Concurrent Workers: {concurrent_workers}")
    print(f"   🏊 Connection Pool Size: {pool_size} connections")
    print(f"   📈 Query Type: SELECT (optimized read operations)")
    print(f"   🎯 Query Patterns: {len(QUERIES)} different patterns")
    print(f"   ⚡ Mode: Connection pooling (shared pool)")
    print("=" * 70)
    print()
    
    try:
        # Initialize connection pool
        print("🏊 Initializing connection pool...", flush=True)
        connection_pool = pool.ThreadedConnectionPool(
            minconn=pool_size // 2,  # Minimum connections
            maxconn=pool_size,        # Maximum connections
            **DB_CONFIG
        )
        print(f"✅ Connection pool initialized ({pool_size} connections)", flush=True)
        print()
        
        start_time = time.time()
        
        print("🔄 Starting concurrent workers...", flush=True)
        print()
        
        with ThreadPoolExecutor(max_workers=concurrent_workers) as executor:
            # Submit all workers at once - each will run queries for the duration
            futures = [
                executor.submit(execute_query_batch, worker_id, QUERIES, duration_seconds, start_time)
                for worker_id in range(concurrent_workers)
            ]
            
            # Show progress while workers are running
            last_update = time.time()
            while (time.time() - start_time) < duration_seconds:
                elapsed = time.time() - start_time
                remaining = duration_seconds - elapsed
                
                # Update progress every 0.5 seconds
                if time.time() - last_update >= 0.5:
                    progress_pct = (elapsed / duration_seconds) * 100
                    bar_length = 40
                    filled = int(bar_length * progress_pct / 100)
                    bar = "█" * filled + "░" * (bar_length - filled)
                    
                    print(f"\r⚡ [{bar}] {progress_pct:.1f}% | {elapsed:.1f}s / {duration_seconds}s | {concurrent_workers} workers active", end='', flush=True)
                    last_update = time.time()
                
                time.sleep(0.1)
            
            print()  # New line after progress bar
            print()
            print("⏳ Collecting results from all workers...", flush=True)
            
            # Collect all results
            all_results = []
            for future in as_completed(futures):
                worker_results = future.result()
                all_results.extend(worker_results)
        
        # Calculate statistics
        elapsed_time = time.time() - start_time
        success_results = [r for r in all_results if r['success']]
        failed_results = [r for r in all_results if not r['success']]
        latencies = [r['latency'] for r in success_results]
        
        if latencies:
            avg_latency = sum(latencies) / len(latencies)
            min_latency = min(latencies)
            max_latency = max(latencies)
            sorted_latencies = sorted(latencies)
            p50_latency = sorted_latencies[len(sorted_latencies)//2] if sorted_latencies else 0
            p95_latency = sorted_latencies[int(len(sorted_latencies)*0.95)] if sorted_latencies else 0
            qps = len(all_results) / elapsed_time
        else:
            avg_latency = min_latency = max_latency = p50_latency = p95_latency = qps = 0
        
        # Print results with demo-friendly formatting
        print()
        print("=" * 70)
        print("🎯  PERFORMANCE TEST RESULTS")
        print("=" * 70)
        print()
        
        # Key metrics in large, bold format
        print(f"⚡ THROUGHPUT:  {qps:.1f} Queries/Second")
        print(f"🚀 PEAK LOAD:   {concurrent_workers} concurrent workers")
        print(f"🏊 POOL SIZE:   {pool_size} connections")
        print(f"📊 TOTAL QUERIES: {len(all_results):,} queries in {elapsed_time:.1f} seconds")
        print(f"✅ SUCCESS RATE:  {(len(success_results)/len(all_results)*100):.1f}% ({len(success_results):,}/{len(all_results):,})")
        print()
        
        # Latency metrics
        print(f"⏱️  LATENCY METRICS:")
        print(f"   Average: {avg_latency:.0f}ms")
        print(f"   Median (p50): {p50_latency:.0f}ms")
        print(f"   95th percentile: {p95_latency:.0f}ms")
        print(f"   Best:    {min_latency:.0f}ms")
        print(f"   Worst:   {max_latency:.0f}ms")
        print()
        
        # Show sample queries
        print("📋 Sample Successful Queries:")
        for result in success_results[:5]:
            print(f"   ✅ {result['query']}")
            print(f"      Latency: {result['latency']:.2f}ms | Rows: {result.get('row_count', 'N/A')}")
        
        if failed_results:
            print()
            print(f"⚠️  Failed Queries: {len(failed_results)}")
            for result in failed_results[:3]:
                print(f"   ❌ {result['query']}")
                print(f"      Error: {result.get('error', 'Unknown')[:70]}")
    
        print()
        print("=" * 70)
        print("✅  DEMO COMPLETED SUCCESSFULLY!")
        print("=" * 70)
        print()
        print(f"💡 Key Takeaway: Lakebase PostgreSQL handled {qps:.0f} QPS")
        print(f"   across {concurrent_workers} workers with {pool_size} pooled connections!")
        print(f"   Success rate: {(len(success_results)/len(all_results)*100):.1f}% ({len(success_results):,}/{len(all_results):,})")
        print()
    
    finally:
        # Clean up connection pool
        if connection_pool:
            print("🔄 Closing connection pool...", flush=True)
            connection_pool.closeall()
            print("✅ Connection pool closed")
            print()

if __name__ == "__main__":
    try:
        # Run 15 second load test with 200 concurrent workers
        # Uses connection pooling for efficient connection management
        # Staggered connection setup avoids rate limiting
        # Ultra-optimized queries for highest QPS
        run_load_test(duration_seconds=15, concurrent_workers=200)
    except KeyboardInterrupt:
        print("\n\n⚠️  Load test interrupted by user")
    except Exception as e:
        print(f"\n\n❌ Error: {e}")
        import traceback
        traceback.print_exc()

