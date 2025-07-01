#!/usr/bin/env python3
"""Minimal JAX GPU test to isolate hanging issue."""

import subprocess
import sys
import os
import time
import signal

def timeout_handler(signum, frame):
    raise TimeoutError("Operation timed out")

def test_jax_version(version, cuda_variant="cuda12_pip"):
    """Test a specific JAX version with timeout protection."""
    print(f"\n{'='*60}")
    print(f"Testing JAX {version} with {cuda_variant}")
    print('='*60)
    
    # Uninstall any existing JAX
    subprocess.run([sys.executable, "-m", "pip", "uninstall", "-y", "jax", "jaxlib"], 
                   capture_output=True)
    
    # Install specific version
    print(f"Installing JAX {version}...")
    if cuda_variant == "cuda12_pip":
        result = subprocess.run([
            sys.executable, "-m", "pip", "install", "-q",
            f"jax[cuda12_pip]=={version}",
            "-f", "https://storage.googleapis.com/jax-releases/jax_cuda_releases.html"
        ], capture_output=True, text=True)
    else:
        # Try older installation method
        result = subprocess.run([
            sys.executable, "-m", "pip", "install", "-q",
            f"jax=={version}",
            f"jaxlib=={version}+cuda12.cudnn89",
            "-f", "https://storage.googleapis.com/jax-releases/jax_cuda_releases.html"
        ], capture_output=True, text=True)
    
    if result.returncode != 0:
        print(f"Failed to install: {result.stderr}")
        return False
    
    # Test with timeout
    signal.signal(signal.SIGALRM, timeout_handler)
    
    try:
        # Import test
        print("1. Testing import...")
        signal.alarm(10)  # 10 second timeout
        import jax
        print(f"   ✓ JAX version: {jax.__version__}")
        signal.alarm(0)
        
        # Device detection test
        print("2. Testing device detection...")
        signal.alarm(10)
        devices = jax.devices()
        print(f"   ✓ Devices found: {len(devices)}")
        for i, d in enumerate(devices):
            print(f"     Device {i}: {d}")
        signal.alarm(0)
        
        # Simple CPU operation
        print("3. Testing CPU operation...")
        signal.alarm(10)
        with jax.default_device(jax.devices('cpu')[0]):
            x_cpu = jax.numpy.ones(10)
            y_cpu = x_cpu + 1
            print(f"   ✓ CPU result: {float(y_cpu[0])}")
        signal.alarm(0)
        
        # GPU detection
        gpu_devices = jax.devices('gpu')
        if not gpu_devices:
            print("   ✗ No GPU devices found!")
            return False
            
        # Simple GPU operation with timeout
        print("4. Testing simple GPU operation...")
        signal.alarm(30)  # 30 second timeout for GPU op
        try:
            x_gpu = jax.numpy.array([1.0, 2.0, 3.0])
            print(f"   Array created, device: {x_gpu.device()}")
            y_gpu = x_gpu + 1
            result = float(y_gpu[0])
            print(f"   ✓ GPU result: {result}")
        except TimeoutError:
            print("   ✗ GPU operation timed out!")
            return False
        finally:
            signal.alarm(0)
        
        # Matrix multiplication test
        print("5. Testing GPU matrix multiplication...")
        signal.alarm(30)
        try:
            a = jax.numpy.ones((100, 100))
            b = jax.numpy.ones((100, 100))
            c = jax.numpy.dot(a, b)
            c.block_until_ready()  # Force computation
            print(f"   ✓ Matrix mult result shape: {c.shape}, sum: {float(jax.numpy.sum(c))}")
        except TimeoutError:
            print("   ✗ Matrix multiplication timed out!")
            return False
        finally:
            signal.alarm(0)
            
        print(f"\n✓ JAX {version} PASSED all tests!")
        return True
        
    except TimeoutError as e:
        print(f"\n✗ JAX {version} FAILED: {e}")
        return False
    except Exception as e:
        print(f"\n✗ JAX {version} FAILED with error: {e}")
        import traceback
        traceback.print_exc()
        return False
    finally:
        signal.alarm(0)

def main():
    """Test multiple JAX versions."""
    print("JAX GPU Testing Script")
    print("=" * 60)
    
    # Show environment
    print("Environment:")
    print(f"Python: {sys.version}")
    print(f"CUDA_VISIBLE_DEVICES: {os.environ.get('CUDA_VISIBLE_DEVICES', 'not set')}")
    print(f"LD_LIBRARY_PATH: {os.environ.get('LD_LIBRARY_PATH', 'not set')}")
    
    # Check CUDA availability first
    print("\nChecking CUDA with PyTorch...")
    try:
        import torch
        print(f"PyTorch CUDA available: {torch.cuda.is_available()}")
        if torch.cuda.is_available():
            print(f"PyTorch CUDA device count: {torch.cuda.device_count()}")
            print(f"PyTorch CUDA device: {torch.cuda.get_device_name(0)}")
    except ImportError:
        print("PyTorch not available for CUDA check")
    
    # Test versions
    versions_to_test = [
        ("0.4.23", "cuda12_pip"),
        ("0.4.26", "cuda12_pip"),
        ("0.4.30", "cuda12_pip"),
        ("0.4.23", "manual"),  # Try manual jaxlib specification
    ]
    
    results = []
    for version, variant in versions_to_test:
        try:
            success = test_jax_version(version, variant)
            results.append((version, variant, success))
        except Exception as e:
            print(f"Unexpected error testing {version}: {e}")
            results.append((version, variant, False))
    
    # Summary
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    for version, variant, success in results:
        status = "PASSED" if success else "FAILED"
        print(f"JAX {version} ({variant}): {status}")
    
    # Find working version
    working_versions = [(v, var) for v, var, s in results if s]
    if working_versions:
        print(f"\nRecommended JAX version: {working_versions[0][0]} ({working_versions[0][1]})")
    else:
        print("\nNo working JAX version found!")

if __name__ == "__main__":
    main()