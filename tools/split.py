#!/usr/bin/env python3
import os
import sys

def split_memory_file(file_path):
    # Read lines
    with open(file_path, 'r') as f:
        lines = [line.strip() for line in f if line.strip()]

    chunk_size = 18
    files_data = []

    # Split each line into chunks
    for line in lines:
        chunks = [line[i:i+chunk_size] for i in range(0, len(line), chunk_size)]
        # Extend files_data if needed
        while len(files_data) < len(chunks):
            files_data.append([])
        # Add each chunk to its respective "column"
        for idx, chunk in enumerate(chunks):
            files_data[idx].append(chunk)

    # Save each "column" to its own file
    base_name, ext = os.path.splitext(file_path)
    for idx, data in enumerate(files_data):
        out_file = f"{base_name}{idx}{ext}"
        with open(out_file, 'w') as f:
            f.write('\n'.join(data))
        print(f"Saved {out_file}")

def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <memory_file>")
        sys.exit(1)

    file_path = sys.argv[1]
    if not os.path.isfile(file_path):
        print(f"Error: File '{file_path}' does not exist.")
        sys.exit(1)

    split_memory_file(file_path)

if __name__ == "__main__":
    main()
