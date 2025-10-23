import random
from stl import mesh
import sys
import os
import numpy as np

def float_to_q16_16(value: float) -> int:
    return int(value * (1 << 16))

def random_color_12bit_high() -> int:
    r = random.randint(0x8, 0xF)
    g = random.randint(0x8, 0xF)
    b = random.randint(0x8, 0xF)
    return (r << 12) | (g << 8) | (b << 4)

def triangle_normal(v0, v1, v2):
    return np.cross(v1 - v0, v2 - v0)

def ensure_winding(vs, stl_normal):
    """Ensure the triangle vertices are ordered consistently with the STL normal."""
    n = triangle_normal(vs[0], vs[1], vs[2])
    if np.dot(n, stl_normal) < 0:
        # Flip v1 and v2 to match normal
        return np.array([vs[0], vs[2], vs[1]])
    return vs

def write_sv_mem_triangles(stl_path: str, output_path: str):
    model = mesh.Mesh.from_file(stl_path)
    vertices = model.vectors.copy()  # shape (n_triangles, 3, 3)
    normals = model.normals  # shape (n_triangles, 3)

    # min-max normalization to [-1, 1] across all vertices
    all_vertices = vertices.reshape(-1, 3)
    v_min = all_vertices.min(axis=0)
    v_max = all_vertices.max(axis=0)
    vertices = 2 * (vertices - v_min) / (v_max - v_min) - 1

    with open(output_path, "w") as f:
        for tri_idx in range(vertices.shape[0]):
            triangle_vertices = vertices[tri_idx]            
            stl_normal = normals[tri_idx]
            triangle_vertices = ensure_winding(triangle_vertices, stl_normal)
            color = random_color_12bit_high()

            output = ""
            for v in triangle_vertices:
                x, y, z = v
                qx, qy, qz = float_to_q16_16(x), float_to_q16_16(y), float_to_q16_16(z)
                output += f"{qx & 0xFFFFFFFF:08X}"
                output += f"{qy & 0xFFFFFFFF:08X}"
                output += f"{qz & 0xFFFFFFFF:08X}"
                output += f"{color:04X}"
            f.write(output + "\n")

    print(f"Wrote {vertices.shape[0]} triangles to {output_path}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python convert_stl_to_mem.py input.stl output.mem")
        sys.exit(1)

    stl_path = sys.argv[1]
    output_path = sys.argv[2]

    if not os.path.exists(stl_path):
        print(f"Error: {stl_path} not found")
        sys.exit(1)

    write_sv_mem_triangles(stl_path, output_path)
