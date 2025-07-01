# Review of AlphaFold Build Plan to Eliminate CUDA Bind Mounts

## Reviewer: Software Developer & System Administrator Perspective

---

## ✅ Strengths of the Proposed Plan

1. **Correct Base Image**
   - Switching to `nvidia/cuda:12.2.2-cudnn8-devel-ubuntu22.04` resolves:
     - GLIBC compatibility (previous issues with Ubuntu 20.04)
     - Inclusion of `ptxas` and CUDA dev tools required by JAX

2. **Self-Contained Environment**
   - Eliminates host dependency on:
     - `/usr/local/cuda/...`
     - Manual `LD_PRELOAD`
     - Bind mounts
   - Improves portability and reproducibility

3. **Pre-Build Configuration**
   - Moves library setup and symlinks to `%post` section
   - Avoids runtime issues with `ldconfig` and read-only FS

4. **Environment Hardening**
   - `%environment` with `PYTHONNOUSERSITE=1` avoids interference from host/user packages

---

## ⚠️ Weaknesses and Suggested Improvements

### 1. NumPy and JAX Version Pinning
- Plan should explicitly pin these versions:
  ```bash
  pip install numpy==1.24.3 jax==0.4.26 jaxlib==0.4.26+cuda12.cudnn89 --extra-index-url https://storage.googleapis.com/jax-releases/jax_cuda_releases.html
  ```

### 2. CUDA Toolkit Version Flexibility
- CUDA 12.2 is acceptable but near edge of compatibility
- Recommend secondary build with CUDA 11.8 or 12.1 (better support in JAX historically)

### 3. Host NVIDIA Driver Compatibility
- Document or script a check:
  ```bash
  nvidia-smi
  ```
  Ensure host driver version >= container CUDA version

### 4. Symlink Strategy Risks
- Manual symlinks may silently fail with version changes
- Use `if` guards or install via Conda for more robust setup

### 5. Missing Build-Time Tests
- Add a `%test` section:
  ```bash
  python /app/test_scripts/test_jax_cuda.py
  ```

---

## 🔍 Additional Enhancements

- Inspect Python RUNPATHs to verify correct library resolution
  ```bash
  readelf -d $(which python) | grep RUNPATH
  ```
- Include `strace`, `gdb` for debugging GPU hangs

---

## ✅ Success Probability

- If host NVIDIA driver supports CUDA 12.2: **~95% success likelihood**
- If not, fallback to CUDA 11.8 build may be required: **~70–80%**

---

## Summary of Actionable Suggestions

| Area                        | Suggestion                                                                 |
|-----------------------------|----------------------------------------------------------------------------|
| NumPy & JAX Versions        | Pin explicitly in `%post` (NumPy 1.24.3, jaxlib with +cuda suffix)         |
| CUDA Toolkit Version        | Consider alternate definition with CUDA 11.8 or 12.1                       |
| Library Setup               | Automate symlink checking; better to use Conda than hardcoding             |
| Runtime Test                | Add `%test` section or run test scripts post-build                         |
| Host Compatibility Check    | Include a README note or script for verifying `nvidia-smi` version         |

---

Would you like help updating your `.def` file or setting up a dual-build strategy?