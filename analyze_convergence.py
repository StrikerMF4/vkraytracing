#!/usr/bin/env python3
import os
import argparse
import glob
import csv

import numpy as np
from PIL import Image
import matplotlib.pyplot as plt
from skimage.metrics import structural_similarity as ssim


# --------------------------
# Image & metric utilities
# --------------------------

def load_image(path):
    """Load image as float32 in [0,1], RGB."""
    img = Image.open(path).convert("RGB")
    arr = np.asarray(img, dtype=np.float32) / 255.0
    return arr


def compute_mse_rmse_psnr(img, ref):
    """Compute MSE, RMSE and PSNR (assuming range [0,1])."""
    diff = img - ref
    mse = float(np.mean(diff ** 2))
    rmse = float(np.sqrt(mse))
    if mse == 0.0:
        psnr = float("inf")
    else:
        psnr = 10.0 * np.log10(1.0 / mse)
    return mse, rmse, psnr


def compute_ssim(img, ref):
    """Compute SSIM over the full RGB image."""
    # skimage expects data_range=1.0 for [0,1] images
    s = ssim(img, ref, channel_axis=-1, data_range=1.0)
    return float(s)


# --------------------------
# Filesystem helpers
# --------------------------

def find_scenes(root):
    """Return list of scenes (subdirectories under root)."""
    scenes = []
    for entry in os.scandir(root):
        if entry.is_dir():
            scenes.append(entry.name)
    return sorted(scenes)


def find_techniques(scene_dir):
    """Return list of techniques (subdirectories under a scene)."""
    techs = []
    for entry in os.scandir(scene_dir):
        if entry.is_dir():
            techs.append(entry.name)
    return sorted(techs)


# --------------------------
# Log parsing
# --------------------------

def load_log_mapping(log_path):
    """
    Load mapping from filename -> (delta_time, iteration)
    from a log.txt like:

    cornellbox_sphere.scn_BPT2025-11-16 10.47.20-66.png 0.550587 66

    Note: filenames may contain spaces (date/time).
    Strategy:
      - split line
      - join tokens up to the one ending with '.png' as the filename
      - next token: delta_time
      - next token: iteration
    """
    mapping = {}

    if not os.path.isfile(log_path):
        print(f"[WARN] log file '{log_path}' not found. "
              f"Metrics will still be computed but iterations/time won't be mapped.")
        return mapping

    with open(log_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue

            parts = line.split()
            png_idx = None
            for i, p in enumerate(parts):
                if p.lower().endswith(".png"):
                    png_idx = i
                    break

            # We expect at least: <filename...png> <delta> <iter>
            if png_idx is None or png_idx + 2 >= len(parts):
                print(f"[WARN] Could not parse log line: {line}")
                continue

            filename = " ".join(parts[:png_idx + 1])
            try:
                delta_time = float(parts[png_idx + 1])
                iteration = int(parts[png_idx + 2])
            except ValueError:
                print(f"[WARN] Could not parse delta/iteration in line: {line}")
                continue

            mapping[filename] = {
                "delta_time": delta_time,
                "iteration": iteration,
            }

    print(f"[INFO] Loaded {len(mapping)} log entries from {log_path}")
    return mapping


# --------------------------
# Scene analysis
# --------------------------

def analyze_scene(scene_name, scene_dir, log_map, csv_writer, output_dir):
    print(f"\n=== Scene: {scene_name} ===")

    techniques = find_techniques(scene_dir)
    if not techniques:
        print(f"  (No techniques in {scene_dir}, skipping)")
        return

    # For plotting:
    # metric_curves_iter[metric][tech] = (x_iter_list, y_list)
    # metric_curves_time[metric][tech] = (x_time_list, y_list_time_filtered)
    metric_curves_iter = {
        "mse": {},
        "rmse": {},
        "psnr_db": {},
        "ssim": {},
    }
    metric_curves_time = {
        "mse": {},
        "rmse": {},
        "psnr_db": {},
        "ssim": {},
    }

    for tech in techniques:
        tech_dir = os.path.join(scene_dir, tech)

        ref_path = os.path.join(tech_dir, "reference.png")
        if not os.path.isfile(ref_path):
            print(f"  [WARN] Technique '{tech}' has no reference.png, skipping.")
            continue

        ref_img = load_image(ref_path)
        print(f"  Technique {tech}: using reference {ref_path}")

        # Collect all pngs except reference.png
        img_files = sorted(
            f for f in glob.glob(os.path.join(tech_dir, "*.png"))
            if os.path.basename(f) != "reference.png"
        )
        if not img_files:
            print(f"  Technique {tech}: no screenshots found, skipping.")
            continue

        # Build entries with iteration and delta_time from log
        entries = []
        for img_path in img_files:
            base = os.path.basename(img_path)
            info = log_map.get(base)
            if info is None:
                # If not present in log, fall back to "unknown"
                print(f"    [WARN] No log entry for {base}, using index as iteration.")
                entry = {
                    "path": img_path,
                    "filename": base,
                    "iteration": None,
                    "delta_time": None,
                }
            else:
                entry = {
                    "path": img_path,
                    "filename": base,
                    "iteration": info["iteration"],
                    "delta_time": info["delta_time"],
                }
            entries.append(entry)

        # Sort by iteration if available, otherwise by filename
        def sort_key(e):
            has_iter = e["iteration"] is not None
            return (not has_iter, e["iteration"] if has_iter else 0, e["filename"])

        entries.sort(key=sort_key)

        # Compute cumulative time per technique
        cumulative_time = 0.0
        for e in entries:
            dt = e["delta_time"]
            if dt is not None:
                cumulative_time += dt
                e["time_cumulative"] = cumulative_time
            else:
                e["time_cumulative"] = None

        # Lists for curves vs iter
        xs_iter = []
        mse_iter = []
        rmse_iter = []
        psnr_iter = []
        ssim_iter = []

        # Lists for curves vs time (only entries with known cumulative time)
        xs_time = []
        mse_time = []
        rmse_time = []
        psnr_time = []
        ssim_time = []

        for idx, e in enumerate(entries, start=1):
            img_path = e["path"]
            img = load_image(img_path)

            if img.shape != ref_img.shape:
                raise RuntimeError(
                    f"Dimension mismatch between reference ({ref_img.shape}) "
                    f"and {img_path} ({img.shape})."
                )

            mse, rmse, psnr = compute_mse_rmse_psnr(img, ref_img)
            s = compute_ssim(img, ref_img)

            # X-axis for iter plots: use iteration if available, otherwise index
            x_iter_val = e["iteration"] if e["iteration"] is not None else idx

            xs_iter.append(x_iter_val)
            mse_iter.append(mse)
            rmse_iter.append(rmse)
            psnr_iter.append(psnr)
            ssim_iter.append(s)

            # X-axis for time plots: cumulative time if available
            if e["time_cumulative"] is not None:
                xs_time.append(e["time_cumulative"])
                mse_time.append(mse)
                rmse_time.append(rmse)
                psnr_time.append(psnr)
                ssim_time.append(s)

            csv_writer.writerow({
                "scene": scene_name,
                "technique": tech,
                "index": idx,
                "iteration": e["iteration"] if e["iteration"] is not None else "",
                "filename": os.path.relpath(img_path),
                "delta_time": e["delta_time"] if e["delta_time"] is not None else "",
                "time_cumulative": e["time_cumulative"] if e["time_cumulative"] is not None else "",
                "mse": mse,
                "rmse": rmse,
                "psnr_db": psnr,
                "ssim": s,
            })

        metric_curves_iter["mse"][tech] = (xs_iter, mse_iter)
        metric_curves_iter["rmse"][tech] = (xs_iter, rmse_iter)
        metric_curves_iter["psnr_db"][tech] = (xs_iter, psnr_iter)
        metric_curves_iter["ssim"][tech] = (xs_iter, ssim_iter)

        if xs_time:
            metric_curves_time["mse"][tech] = (xs_time, mse_time)
            metric_curves_time["rmse"][tech] = (xs_time, rmse_time)
            metric_curves_time["psnr_db"][tech] = (xs_time, psnr_time)
            metric_curves_time["ssim"][tech] = (xs_time, ssim_time)

        print(f"  Technique {tech}: processed {len(xs_iter)} screenshots")

    os.makedirs(output_dir, exist_ok=True)

    def plot_metric(curves, x_label, ylabel, filename, title_suffix, log_y=False):
        if not curves:
            return

        plt.figure()
        for tech, (xs, ys) in curves.items():
            xs_arr = np.array(xs)
            ys_arr = np.array(ys)
            plt.plot(xs_arr, ys_arr, linewidth=2, label=tech)

        plt.xlabel(x_label)
        plt.ylabel(ylabel)
        plt.title(f"{title_suffix} - {scene_name}")
        plt.legend()
        plt.grid(True, linestyle="--", alpha=0.5)
        if log_y:
            plt.yscale("log")
        out_path = os.path.join(output_dir, filename)
        plt.savefig(out_path, bbox_inches="tight")
        plt.close()
        print(f"  Plot saved: {out_path}")

    # ---- 4 métricas vs iteraciones ----
    # plot_metric(
    #     metric_curves_iter["mse"],
    #     x_label="Iterations",
    #     ylabel="MSE",
    #     filename=f"{scene_name}_mse_iter.png",
    #     title_suffix="MSE convergence vs iterations",
    #     log_y=True,
    # )
    # plot_metric(
    #     metric_curves_iter["rmse"],
    #     x_label="Iterations",
    #     ylabel="RMSE",
    #     filename=f"{scene_name}_rmse_iter.png",
    #     title_suffix="RMSE convergence vs iterations",
    #     log_y=False,
    # )
    # plot_metric(
    #     metric_curves_iter["psnr_db"],
    #     x_label="Iterations",
    #     ylabel="PSNR (dB)",
    #     filename=f"{scene_name}_psnr_iter.png",
    #     title_suffix="PSNR convergence vs iterations",
    #     log_y=False,
    # )
    # plot_metric(
    #     metric_curves_iter["ssim"],
    #     x_label="Iterations",
    #     ylabel="SSIM",
    #     filename=f"{scene_name}_ssim_iter.png",
    #     title_suffix="SSIM convergence vs iterations",
    #     log_y=False,
    # )

    # ---- 4 métricas vs tiempo acumulado ----
    plot_metric(
        metric_curves_time["mse"],
        x_label="Time (s)",
        ylabel="MSE",
        filename=f"{scene_name}_mse_time.png",
        title_suffix="MSE convergence vs time",
        log_y=True,
    )
    plot_metric(
        metric_curves_time["rmse"],
        x_label="Time (s)",
        ylabel="RMSE",
        filename=f"{scene_name}_rmse_time.png",
        title_suffix="RMSE convergence vs time",
        log_y=False,
    )
    plot_metric(
        metric_curves_time["psnr_db"],
        x_label="Time (s)",
        ylabel="PSNR (dB)",
        filename=f"{scene_name}_psnr_time.png",
        title_suffix="PSNR convergence vs time",
        log_y=False,
    )
    plot_metric(
        metric_curves_time["ssim"],
        x_label="Time (s)",
        ylabel="SSIM",
        filename=f"{scene_name}_ssim_time.png",
        title_suffix="SSIM convergence vs time",
        log_y=False,
    )


# --------------------------
# Main
# --------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Analyze convergence of render algorithms from screenshots and log.txt."
    )
    parser.add_argument(
        "--root",
        type=str,
        default="screenshots",
        help="Root directory where scenes are located (default: screenshots/).",
    )
    parser.add_argument(
        "--output",
        type=str,
        default="output",
        help="Directory where CSVs and plots will be saved (default: output/).",
    )
    parser.add_argument(
        "--log",
        type=str,
        default="log.txt",
        help="Path to log file mapping filename -> delta_time + iteration (default: log.txt).",
    )

    args = parser.parse_args()

    root = args.root
    output_dir = args.output
    log_path = args.log

    log_map = load_log_mapping(log_path)
    scenes = find_scenes(root)
    if not scenes:
        print(f"No scenes found under {root}.")
        return

    os.makedirs(output_dir, exist_ok=True)
    csv_path = os.path.join(output_dir, "convergence_metrics.csv")

    with open(csv_path, "w", newline="", encoding="utf-8") as csvfile:
        fieldnames = [
            "scene",
            "technique",
            "index",
            "iteration",
            "filename",
            "delta_time",
            "time_cumulative",
            "mse",
            "rmse",
            "psnr_db",
            "ssim",
        ]
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()

        for scene in scenes:
            scene_dir = os.path.join(root, scene)
            analyze_scene(scene, scene_dir, log_map, writer, output_dir)

    print(f"\n[INFO] Metrics written to: {csv_path}")


if __name__ == "__main__":
    main()
