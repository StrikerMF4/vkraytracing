"""
Convierte todas las imágenes .exr de una carpeta a .png,
replicando la estructura de subcarpetas en una carpeta de salida.

Uso:
    python convert_exr_to_png.py <carpeta_entrada> [carpeta_salida]

Si no se especifica carpeta_salida, se crea "<carpeta_entrada>-png" en el mismo directorio.

Requiere: opencv-python (cv2)  o  imageio + imageio-plugins[exr]
  pip install opencv-python
  o
  pip install imageio imageio[exr] numpy
"""

import sys
import os

# Debe setearse ANTES de importar cv2
os.environ["OPENCV_IO_ENABLE_OPENEXR"] = "1"

import argparse
from pathlib import Path

# ---------------------------------------------------------------------------
# Backends de lectura EXR
# ---------------------------------------------------------------------------

def read_exr_cv2(path: Path):
    """Lee un EXR con OpenCV y retorna un array float32 RGB en rango [0, inf)."""
    import cv2
    img = cv2.imread(str(path), cv2.IMREAD_ANYDEPTH | cv2.IMREAD_ANYCOLOR)
    if img is None:
        raise IOError(f"OpenCV no pudo leer: {path}")
    if len(img.shape) == 2:                  # grayscale → RGB
        img = cv2.cvtColor(img, cv2.COLOR_GRAY2BGR)
    img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    return img.astype("float32")


def read_exr_imageio(path: Path):
    """Lee un EXR con imageio y retorna un array float32 RGB."""
    import imageio.v3 as iio
    img = iio.imread(str(path), plugin="EXR-FI")   # requiere imageio-freeimage
    if img is None:
        raise IOError(f"imageio no pudo leer: {path}")
    if img.ndim == 2:
        import numpy as np
        img = np.stack([img, img, img], axis=-1)
    return img[:, :, :3].astype("float32")


def get_reader():
    """Devuelve la función de lectura disponible en el entorno."""
    try:
        import cv2
        # Verificar soporte EXR (requiere compilación con OpenEXR)
        # Un test rápido: si el flag existe, asumimos soporte
        _ = cv2.IMREAD_ANYDEPTH
        return "cv2", read_exr_cv2
    except ImportError:
        pass

    try:
        import imageio.v3  # noqa: F401
        return "imageio", read_exr_imageio
    except ImportError:
        pass

    raise RuntimeError(
        "No se encontró ningún backend compatible.\n"
        "Instala uno de los siguientes:\n"
        "  pip install opencv-python\n"
        "  pip install imageio imageio[exr] numpy"
    )


# ---------------------------------------------------------------------------
# Tone mapping: HDR → LDR
# ---------------------------------------------------------------------------

def tonemap_reinhard(img_hdr):
    """
    Reinhard global tone mapping: L_d = L / (1 + L).
    Aplica gamma 2.2 al final.
    """
    import numpy as np
    img = img_hdr / (1.0 + img_hdr)
    img = np.clip(img, 0.0, 1.0)
    img = img ** (1.0 / 2.2)          # gamma correction
    return (img * 255).astype("uint8")


def tonemap_cv2(img_hdr):
    """Tone mapping Reinhard usando el operador incorporado de OpenCV."""
    import cv2
    import numpy as np
    tonemap = cv2.createTonemapReinhard(gamma=2.2, intensity=0,
                                        light_adapt=0, color_adapt=0)
    ldr = tonemap.process(img_hdr)
    ldr = np.clip(ldr, 0.0, 1.0)
    return (ldr * 255).astype("uint8")


# ---------------------------------------------------------------------------
# Conversión y guardado
# ---------------------------------------------------------------------------

def save_png(img_rgb_uint8, out_path: Path):
    """Guarda array uint8 RGB como PNG."""
    try:
        import cv2
        import numpy as np
        bgr = cv2.cvtColor(img_rgb_uint8, cv2.COLOR_RGB2BGR)
        cv2.imwrite(str(out_path), bgr)
    except ImportError:
        import imageio.v3 as iio
        iio.imwrite(str(out_path), img_rgb_uint8)


def convert_file(exr_path: Path, out_path: Path, reader_fn, use_cv2_tonemap: bool):
    """Lee un EXR, aplica tone mapping y guarda como PNG."""
    img_hdr = reader_fn(exr_path)

    if use_cv2_tonemap:
        img_ldr = tonemap_cv2(img_hdr)
    else:
        img_ldr = tonemap_reinhard(img_hdr)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    save_png(img_ldr, out_path)


# ---------------------------------------------------------------------------
# Recorrido de carpetas
# ---------------------------------------------------------------------------

def convert_folder(input_dir: Path, output_dir: Path, reader_fn,
                   use_cv2_tonemap: bool, verbose: bool = True):
    exr_files = sorted(input_dir.rglob("*.exr"))

    if not exr_files:
        print(f"No se encontraron archivos .exr en: {input_dir}")
        return

    total = len(exr_files)
    errors = []

    for i, exr_path in enumerate(exr_files, 1):
        rel = exr_path.relative_to(input_dir)
        out_path = output_dir / rel.with_suffix(".png")

        if verbose:
            print(f"[{i:4d}/{total}] {rel}", end=" ... ", flush=True)

        try:
            convert_file(exr_path, out_path, reader_fn, use_cv2_tonemap)
            if verbose:
                print("OK")
        except Exception as e:
            if verbose:
                print(f"ERROR: {e}")
            errors.append((exr_path, str(e)))

    print(f"\nCompletado: {total - len(errors)}/{total} archivos convertidos.")
    if errors:
        print(f"\nErrores ({len(errors)}):")
        for p, msg in errors:
            print(f"  {p}: {msg}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Convierte .exr → .png replicando estructura de carpetas."
    )
    parser.add_argument("input", help="Carpeta raíz con las imágenes .exr")
    parser.add_argument(
        "output", nargs="?", default=None,
        help="Carpeta de salida (default: <input>-png)"
    )
    parser.add_argument(
        "--tonemap", choices=["reinhard", "cv2_reinhard"], default="reinhard",
        help="Operador de tone mapping (default: reinhard)"
    )
    parser.add_argument(
        "--quiet", action="store_true", help="Suprimir salida por archivo"
    )
    args = parser.parse_args()

    input_dir = Path(args.input).resolve()
    if not input_dir.is_dir():
        print(f"Error: la carpeta de entrada no existe: {input_dir}")
        sys.exit(1)

    if args.output:
        output_dir = Path(args.output).resolve()
    else:
        output_dir = input_dir.parent / (input_dir.name + "-png")

    backend_name, reader_fn = get_reader()
    use_cv2_tonemap = (args.tonemap == "cv2_reinhard") and (backend_name == "cv2")

    print(f"Backend   : {backend_name}")
    print(f"Tone map  : {'cv2 Reinhard' if use_cv2_tonemap else 'Reinhard global'}")
    print(f"Entrada   : {input_dir}")
    print(f"Salida    : {output_dir}")
    print()

    convert_folder(input_dir, output_dir, reader_fn,
                   use_cv2_tonemap, verbose=not args.quiet)


if __name__ == "__main__":
    main()
