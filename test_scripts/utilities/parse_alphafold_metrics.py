#!/usr/bin/env python3
"""
Parse and analyze AlphaFold output metrics for acceptance testing.
Extracts timing, quality, and resource usage information.
"""

import json
import pickle
import csv
import argparse
from pathlib import Path
from datetime import datetime
import numpy as np
from typing import Dict, List, Optional, Tuple


class AlphaFoldMetricsParser:
    """Parse metrics from AlphaFold output directories."""
    
    def __init__(self, output_dir: Path):
        self.output_dir = Path(output_dir)
        self.protein_name = self.output_dir.name
        
    def parse_timings(self) -> Dict[str, float]:
        """Extract timing information from timings.json."""
        timings_file = self.output_dir / "timings.json"
        
        if not timings_file.exists():
            return {}
            
        with open(timings_file) as f:
            timings = json.load(f)
            
        # Calculate total and percentages
        total_time = sum(timings.values())
        
        return {
            'total_time': total_time,
            'features_time': timings.get('features', 0),
            'predict_time': timings.get('predict_and_compile_model', 0),
            'relax_time': timings.get('relax', 0),
            'features_pct': (timings.get('features', 0) / total_time * 100) if total_time > 0 else 0,
            'predict_pct': (timings.get('predict_and_compile_model', 0) / total_time * 100) if total_time > 0 else 0,
            'relax_pct': (timings.get('relax', 0) / total_time * 100) if total_time > 0 else 0
        }
    
    def parse_quality_metrics(self) -> Dict[str, float]:
        """Extract quality metrics (pLDDT, pTM, etc.)."""
        metrics = {}
        
        # Parse ranking debug for pLDDT scores
        ranking_file = self.output_dir / "ranking_debug.json"
        if ranking_file.exists():
            with open(ranking_file) as f:
                ranking_data = json.load(f)
                
            # Get pLDDT scores
            plddts = ranking_data.get('plddts', {})
            if plddts:
                metrics['plddt_scores'] = plddts
                metrics['best_plddt'] = max(plddts.values())
                metrics['avg_plddt'] = sum(plddts.values()) / len(plddts)
                metrics['best_model'] = ranking_data.get('order', ['unknown'])[0]
        
        # Parse individual model results for detailed metrics
        for pkl_file in self.output_dir.glob("result_model_*.pkl"):
            model_name = pkl_file.stem.replace('result_', '')
            
            try:
                with open(pkl_file, 'rb') as f:
                    result = pickle.load(f)
                    
                # Extract key metrics
                if 'plddt' in result:
                    metrics[f'{model_name}_mean_plddt'] = float(np.mean(result['plddt']))
                    metrics[f'{model_name}_plddt_std'] = float(np.std(result['plddt']))
                    
                if 'ptm' in result:
                    metrics[f'{model_name}_ptm'] = float(result['ptm'])
                    
                if 'predicted_aligned_error' in result:
                    pae = result['predicted_aligned_error']
                    metrics[f'{model_name}_mean_pae'] = float(np.mean(pae))
                    
            except Exception as e:
                print(f"Error parsing {pkl_file}: {e}")
                
        return metrics
    
    def parse_msa_metrics(self) -> Dict[str, any]:
        """Extract MSA-related metrics from features."""
        features_file = self.output_dir / "features.pkl"
        
        if not features_file.exists():
            return {}
            
        try:
            with open(features_file, 'rb') as f:
                features = pickle.load(f)
                
            metrics = {
                'sequence_length': len(features.get('sequence', '')),
                'msa_depth': len(features.get('msa', [])),
                'num_templates': len(features.get('template_domain_names', [])),
            }
            
            # Calculate MSA diversity
            if 'msa' in features and len(features['msa']) > 0:
                msa = features['msa']
                # Simple diversity metric: average pairwise sequence identity
                if len(msa) > 1:
                    seq_len = msa.shape[1] if len(msa.shape) > 1 else len(msa[0])
                    identity_scores = []
                    
                    for i in range(min(10, len(msa))):  # Sample first 10 sequences
                        for j in range(i+1, min(10, len(msa))):
                            identity = np.mean(msa[i] == msa[j])
                            identity_scores.append(identity)
                            
                    if identity_scores:
                        metrics['msa_avg_identity'] = float(np.mean(identity_scores))
                        
            return metrics
            
        except Exception as e:
            print(f"Error parsing features: {e}")
            return {}
    
    def check_output_completeness(self) -> Dict[str, bool]:
        """Check which expected output files are present."""
        expected_files = {
            'features': 'features.pkl',
            'timings': 'timings.json',
            'ranking': 'ranking_debug.json',
            'ranked_pdb': 'ranked_0.pdb',
            'unrelaxed_pdb': 'unrelaxed_model_1_pred_0.pdb',
            'relaxed_pdb': 'relaxed_model_1_pred_0.pdb',
            'result_pkl': 'result_model_1_pred_0.pkl'
        }
        
        completeness = {}
        for key, filename in expected_files.items():
            completeness[key] = (self.output_dir / filename).exists()
            
        # Check for all model outputs
        completeness['all_models'] = len(list(self.output_dir.glob("ranked_*.pdb"))) >= 5
        
        return completeness
    
    def get_all_metrics(self) -> Dict[str, any]:
        """Compile all metrics into a single dictionary."""
        metrics = {
            'protein': self.protein_name,
            'output_dir': str(self.output_dir),
            'timestamp': datetime.now().isoformat()
        }
        
        # Add all metric categories
        metrics.update(self.parse_timings())
        metrics.update(self.parse_quality_metrics())
        metrics.update(self.parse_msa_metrics())
        
        # Add completeness check
        completeness = self.check_output_completeness()
        metrics['output_complete'] = all(completeness.values())
        metrics['missing_files'] = [k for k, v in completeness.items() if not v]
        
        return metrics


def parse_gpu_metrics(metrics_file: Path) -> Dict[str, float]:
    """Parse nvidia-smi dmon output."""
    if not metrics_file.exists():
        return {}
        
    metrics = {
        'gpu_max_memory_mb': 0,
        'gpu_avg_utilization': 0,
        'gpu_max_utilization': 0,
        'gpu_total_samples': 0
    }
    
    try:
        utilizations = []
        memories = []
        
        with open(metrics_file) as f:
            for line in f:
                if line.startswith('#'):
                    continue
                    
                parts = line.strip().split()
                if len(parts) >= 3:
                    try:
                        util = float(parts[1])
                        mem = float(parts[2])
                        utilizations.append(util)
                        memories.append(mem)
                    except ValueError:
                        continue
                        
        if memories:
            metrics['gpu_max_memory_mb'] = max(memories)
            metrics['gpu_avg_memory_mb'] = sum(memories) / len(memories)
            
        if utilizations:
            metrics['gpu_avg_utilization'] = sum(utilizations) / len(utilizations)
            metrics['gpu_max_utilization'] = max(utilizations)
            metrics['gpu_total_samples'] = len(utilizations)
            
    except Exception as e:
        print(f"Error parsing GPU metrics: {e}")
        
    return metrics


def aggregate_test_results(results_dir: Path, output_file: Path):
    """Aggregate results from multiple test runs."""
    all_results = []
    
    # Find all AlphaFold output directories
    for output_dir in results_dir.glob("*/*/"):
        if (output_dir / "timings.json").exists():
            parser = AlphaFoldMetricsParser(output_dir)
            metrics = parser.get_all_metrics()
            
            # Check for associated GPU metrics
            test_id = output_dir.parent.name
            gpu_metrics_file = results_dir.parent / "metrics" / test_id / "gpu_metrics.csv"
            if gpu_metrics_file.exists():
                metrics.update(parse_gpu_metrics(gpu_metrics_file))
                
            all_results.append(metrics)
    
    # Write aggregated results
    if all_results:
        # Determine all fields
        all_fields = set()
        for result in all_results:
            all_fields.update(result.keys())
        
        # Write CSV
        with open(output_file, 'w', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=sorted(all_fields))
            writer.writeheader()
            writer.writerows(all_results)
            
        print(f"Aggregated {len(all_results)} results to {output_file}")
    else:
        print("No results found to aggregate")


def generate_summary_statistics(results_csv: Path):
    """Generate summary statistics from aggregated results."""
    import pandas as pd
    
    try:
        df = pd.read_csv(results_csv)
        
        print("\n=== AlphaFold Metrics Summary ===\n")
        
        # Timing statistics
        if 'total_time' in df.columns:
            print("Timing Statistics:")
            print(f"  Average total time: {df['total_time'].mean():.1f}s")
            print(f"  Min/Max total time: {df['total_time'].min():.1f}s / {df['total_time'].max():.1f}s")
            
            if 'sequence_length' in df.columns:
                # Time per residue
                df['time_per_residue'] = df['total_time'] / df['sequence_length']
                print(f"  Average time per residue: {df['time_per_residue'].mean():.2f}s")
        
        # Quality statistics
        if 'best_plddt' in df.columns:
            print("\nQuality Statistics:")
            print(f"  Average best pLDDT: {df['best_plddt'].mean():.1f}")
            print(f"  pLDDT range: {df['best_plddt'].min():.1f} - {df['best_plddt'].max():.1f}")
        
        # GPU statistics
        if 'gpu_max_memory_mb' in df.columns:
            print("\nGPU Statistics:")
            print(f"  Average peak memory: {df['gpu_max_memory_mb'].mean():.0f} MB")
            print(f"  Max memory used: {df['gpu_max_memory_mb'].max():.0f} MB")
            
            if 'sequence_length' in df.columns:
                # Memory per residue
                df['memory_per_residue'] = df['gpu_max_memory_mb'] / df['sequence_length']
                print(f"  Average memory per residue: {df['memory_per_residue'].mean():.2f} MB")
        
        # MSA statistics
        if 'msa_depth' in df.columns:
            print("\nMSA Statistics:")
            print(f"  Average MSA depth: {df['msa_depth'].mean():.0f}")
            print(f"  MSA depth range: {df['msa_depth'].min()} - {df['msa_depth'].max()}")
        
        # Completeness
        if 'output_complete' in df.columns:
            complete_count = df['output_complete'].sum()
            total_count = len(df)
            print(f"\nOutput Completeness: {complete_count}/{total_count} ({complete_count/total_count*100:.1f}%)")
            
    except Exception as e:
        print(f"Error generating summary: {e}")


def main():
    parser = argparse.ArgumentParser(description='Parse AlphaFold output metrics')
    parser.add_argument('--output-dir', type=Path,
                        help='Single AlphaFold output directory to parse')
    parser.add_argument('--results-dir', type=Path,
                        help='Directory containing multiple test results')
    parser.add_argument('--aggregate', type=Path,
                        help='Output file for aggregated results (CSV)')
    parser.add_argument('--summary', action='store_true',
                        help='Generate summary statistics')
    
    args = parser.parse_args()
    
    if args.output_dir:
        # Parse single output
        metrics_parser = AlphaFoldMetricsParser(args.output_dir)
        metrics = metrics_parser.get_all_metrics()
        
        # Pretty print
        print(json.dumps(metrics, indent=2, default=str))
        
    elif args.results_dir and args.aggregate:
        # Aggregate multiple results
        aggregate_test_results(args.results_dir, args.aggregate)
        
        if args.summary:
            generate_summary_statistics(args.aggregate)
            
    else:
        parser.print_help()


if __name__ == '__main__':
    main()