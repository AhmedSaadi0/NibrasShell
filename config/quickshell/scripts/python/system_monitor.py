#!/usr/bin/env python3
import glob
import os
import shutil
import subprocess
import time

import psutil

# إعداد فترة التحديث (ثانيتين)
INTERVAL = 2

# 1. كاش مسارات الحرارة
THERMAL_ZONES = glob.glob("/sys/class/thermal/thermal_zone*/temp")

# 2. كاش ملف طاقة المعالج (Intel/AMD RAPL)
RAPL_PATH = None
for path in [
    "/sys/class/powercap/intel-rapl/intel-rapl:0/energy_uj",
    "/sys/class/powercap/intel-rapl:0:0/energy_uj",
]:
    if os.path.exists(path):
        RAPL_PATH = path
        break

# متغيرات لحساب استهلاك المعالج بين الدورات
_last_rapl_energy = 0
_last_rapl_time = 0

# 3. كشف مصدر استهلاك GPU
GPU_SOURCE = None  # "nvidia" | "amd" | None
_NVIDIA_BIN = shutil.which("nvidia-smi")
_AMD_BUSY_PATHS = glob.glob("/sys/class/drm/card*/device/gpu_busy_percent")

if _NVIDIA_BIN:
    GPU_SOURCE = "nvidia"
elif _AMD_BUSY_PATHS:
    GPU_SOURCE = "amd"


def get_max_temp():
    """الحصول على أعلى درجة حرارة"""
    if not THERMAL_ZONES:
        return 0.0

    max_temp = 0.0
    for zone in THERMAL_ZONES:
        try:
            with open(zone, "r") as f:
                raw_temp = float(f.read())
                temp_c = raw_temp / 1000.0
                if temp_c > max_temp:
                    max_temp = temp_c
        except Exception:
            continue
    return max_temp


def get_cpu_power():
    """حساب استهلاك المعالج بالواط عبر قراءة فارق الطاقة مع الدورة السابقة"""
    global _last_rapl_energy, _last_rapl_time
    if not RAPL_PATH:
        return 0.0

    try:
        now = time.time()
        with open(RAPL_PATH, "r") as f:
            current_energy = int(f.read())

        if _last_rapl_time == 0:
            _last_rapl_energy = current_energy
            _last_rapl_time = now
            return 0.0

        time_delta = now - _last_rapl_time
        energy_delta = current_energy - _last_rapl_energy

        # تحديث القراءات السابقة
        _last_rapl_energy = current_energy
        _last_rapl_time = now

        # تجنب الأخطاء في حال تصفير العداد (Counter Rollover)
        if energy_delta < 0 or time_delta <= 0:
            return 0.0

        # التحويل من microjoules/sec إلى Watts
        return (energy_delta / time_delta) / 1_000_000.0
    except Exception:
        return 0.0


def get_gpu_metrics():
    """قراءة استهلاك GPU، الذاكرة، والواط.
    ترجع (gpu%, vram%, vram_used_mb, vram_total_mb, gpu_watts)
    """
    if GPU_SOURCE is None:
        return -1, -1, -1, -1, 0.0

    if GPU_SOURCE == "nvidia":
        try:
            # طلب الواط (power.draw) في نفس الاستعلام بدون أي تكلفة إضافية
            out = subprocess.run(
                [
                    _NVIDIA_BIN,
                    "--query-gpu=utilization.gpu,memory.used,memory.total,power.draw",
                    "--format=csv,noheader,nounits",
                ],
                capture_output=True,
                text=True,
                timeout=1,
            )
            util_str, used_str, total_str, pwr_str = out.stdout.strip().split(
                ", "
            )
            gpu_util = float(util_str)
            used_mb = float(used_str)
            total_mb = float(total_str)
            gpu_pwr = float(pwr_str)
            vram_pct = (used_mb / total_mb * 100.0) if total_mb > 0 else -1
            return gpu_util, vram_pct, used_mb, total_mb, gpu_pwr
        except Exception:
            return -1, -1, -1, -1, 0.0

    # AMD
    try:
        with open(_AMD_BUSY_PATHS[0], "r") as f:
            return float(f.read()), -1, -1, -1, 0.0
    except Exception:
        return -1, -1, -1, -1, 0.0


def main():
    # تهيئة أولية
    psutil.cpu_percent(interval=None)
    get_cpu_power()  # أخذ عينة أولى لحساب الواط

    while True:
        try:
            # 1. استهلاك المعالج والرام
            cpu_usage = psutil.cpu_percent(interval=None)
            ram_usage = psutil.virtual_memory().percent

            # 2. أعلى حرارة
            max_temp = get_max_temp()

            # 3. بيانات كرت الشاشة والواط الخاص به
            gpu_usage, vram_pct, vram_used, vram_total, gpu_pwr = (
                get_gpu_metrics()
            )

            # 4. حساب واط المعالج والواط الكلي التقريبي
            cpu_pwr = get_cpu_power()
            total_pwr = cpu_pwr + gpu_pwr

            # 5. طباعة JSON
            print(
                f'{{"cpu": {cpu_usage:.1f}, "cpu_pwr": {cpu_pwr:.1f}, '
                f'"ram": {ram_usage:.1f}, "temp": {max_temp:.1f}, '
                f'"gpu": {gpu_usage:.1f}, "gpu_pwr": {gpu_pwr:.1f}, '
                f'"total_pwr": {total_pwr:.1f}, '
                f'"vram": {vram_pct:.1f}, "vram_used": {vram_used:.0f}, "vram_total": {vram_total:.0f}}}',
                flush=True,
            )

            time.sleep(INTERVAL)

        except KeyboardInterrupt:
            break
        except Exception as e:
            err_msg = str(e).replace('"', '\\"')
            print(f'{{"error": "{err_msg}"}}', flush=True)
            time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
