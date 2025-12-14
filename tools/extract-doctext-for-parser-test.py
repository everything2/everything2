#!/home/jaybonci/.venv/bin/python3
"""
Extract doctext from RDS snapshot export for parser testing

Filters out:
- System nodes (present in nodepack/)
- Code blocks ([% %] from legacy codehome)

Outputs JSON for React parser testing
"""

import json
import glob
import re
import sys
from pathlib import Path

try:
    import pyarrow.parquet as pq
except ImportError:
    print("Error: pyarrow not installed", file=sys.stderr)
    print("Install with: pip3 install pyarrow", file=sys.stderr)
    sys.exit(1)

EXPORT_DIR = "../e2-doctext/e2-writeup-export-20251214-141742/everything/everything.document/1"
NODEPACK_DIR = "nodepack"
OUTPUT_FILE = "../e2-doctext/doctext-samples.json"
MAX_SAMPLES = 100000  # Process more samples to find edge cases

def get_system_node_ids():
    """Load system node IDs from nodepack XML files"""
    print("Loading system node IDs from nodepack...")
    system_nodes = set()

    for xml_file in Path(NODEPACK_DIR).rglob("*.xml"):
        try:
            content = xml_file.read_text()
            matches = re.findall(r'<node_id>(\d+)</node_id>', content)
            for match in matches:
                system_nodes.add(int(match))
        except Exception as e:
            print(f"  Warning: Error reading {xml_file}: {e}", file=sys.stderr)
            continue

    print(f"  Found {len(system_nodes)} system nodes to exclude")
    return system_nodes

def contains_code_block(doctext):
    """Check if doctext contains [% %] Mason2/codehome blocks"""
    if not doctext:
        return False
    return '[%' in doctext and '%]' in doctext

def process_parquet_files(system_nodes):
    """Process all parquet files and extract valid doctext samples"""
    print(f"Processing parquet files from {EXPORT_DIR}...")

    samples = []
    total_processed = 0
    excluded_system = 0
    excluded_code = 0

    parquet_files = sorted(glob.glob(f"{EXPORT_DIR}/*.parquet"))

    if not parquet_files:
        print(f"Error: No parquet files found in {EXPORT_DIR}", file=sys.stderr)
        sys.exit(1)

    for parquet_file in parquet_files:
        if len(samples) >= MAX_SAMPLES:
            break

        print(f"  Reading {Path(parquet_file).name}...")

        try:
            # Read parquet file
            table = pq.read_table(parquet_file)

            # Get column indices
            schema = table.schema
            doc_id_idx = schema.get_field_index('document_id')
            doctext_idx = schema.get_field_index('doctext')

            # Process each row using pyarrow directly
            num_rows = table.num_rows

            for i in range(num_rows):
                if len(samples) >= MAX_SAMPLES:
                    break

                total_processed += 1

                # Get values using column access
                document_id = table.column(doc_id_idx)[i].as_py()
                doctext = table.column(doctext_idx)[i].as_py()

                # Skip if None or empty
                if document_id is None or not doctext:
                    continue

                # Skip system nodes (document_id == node_id for documents)
                if int(document_id) in system_nodes:
                    excluded_system += 1
                    continue

                # Skip if contains code blocks
                if contains_code_block(doctext):
                    excluded_code += 1
                    continue

                # Add to samples
                samples.append({
                    'document_id': int(document_id),
                    'doctext': doctext,
                    'length': len(doctext)
                })

                # Progress indicator
                if total_processed % 10000 == 0:
                    print(f"    Processed {total_processed} rows, collected {len(samples)} samples...")

        except Exception as e:
            print(f"  Error reading {parquet_file}: {e}", file=sys.stderr)
            continue

    print()
    print("Processing complete!")
    print(f"  Total rows processed: {total_processed}")
    print(f"  Excluded (system nodes): {excluded_system}")
    print(f"  Excluded (code blocks): {excluded_code}")
    print(f"  Samples collected: {len(samples)}")

    return samples

def write_output(samples):
    """Write samples to JSON file"""
    print()
    print(f"Writing output to {OUTPUT_FILE}...")

    # Sort by length to get diverse samples
    samples.sort(key=lambda s: s['length'])

    # Calculate stats
    lengths = [s['length'] for s in samples]

    output = {
        'metadata': {
            'generated_at': None,  # Will be filled by json.dumps
            'total_samples': len(samples),
            'length_stats': {
                'min': min(lengths),
                'max': max(lengths),
                'avg': round(sum(lengths) / len(lengths), 2)
            }
        },
        'samples': [
            {
                'id': s['document_id'],
                'text': s['doctext'],
                'length': s['length']
            }
            for s in samples
        ]
    }

    # Add timestamp
    from datetime import datetime, timezone
    output['metadata']['generated_at'] = datetime.now(timezone.utc).isoformat()

    with open(OUTPUT_FILE, 'w') as f:
        json.dump(output, f, indent=2, ensure_ascii=False)

    file_size_mb = Path(OUTPUT_FILE).stat().st_size / 1024 / 1024
    print(f"  Wrote {len(samples)} samples to {OUTPUT_FILE}")
    print(f"  File size: {file_size_mb:.2f} MB")

def main():
    print("E2 Doctext Extraction for Parser Testing")
    print("=" * 80)
    print()

    system_nodes = get_system_node_ids()
    samples = process_parquet_files(system_nodes)

    if not samples:
        print("Error: No samples collected!", file=sys.stderr)
        sys.exit(1)

    write_output(samples)

    print()
    print("Done! Use this file to test React-based HTML parser against server-side rendering.")
    print("Sample usage:")
    print("  node tools/test-react-parser.js ../e2-doctext/doctext-samples.json")

if __name__ == '__main__':
    main()
