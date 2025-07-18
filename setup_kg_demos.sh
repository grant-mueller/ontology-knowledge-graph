#!/usr/bin/env bash
# setup_kg_demos.sh
# Bash script to scaffold and run four CMC‐focused knowledge‐graph demos
# Requires: bash, python3, python3-venv, curl

set -e

echo "🚀 Starting setup of CMC KG demos…"

# 1. Create root directory and enter
ROOT_DIR="${PWD}/cmc_kg_demos"
mkdir -p "$ROOT_DIR"
cd "$ROOT_DIR"
echo "Created project folder: $ROOT_DIR"

# 2. Create & activate Python virtual environment
python3 -m venv venv
source venv/bin/activate
echo "Activated venv at $ROOT_DIR/venv"

# 3. Install Python dependencies
pip install --upgrade pip
pip install requests pandas networkx matplotlib rdflib #owlready2
echo "Installed Python packages: requests, pandas, networkx, matplotlib, rdflib, #owlready2"

###############################################################################
# Demo 1: Public Reference & Regulatory Datasets
#   - Fetch FDA recall events, build RDF and plot graph
###############################################################################
mkdir -p 1_public_ref_datasets
cat > 1_public_ref_datasets/fetch_and_plot.py << 'EOF'
#!/usr/bin/env python3
import requests, pandas as pd
from rdflib import Graph, URIRef, Literal, Namespace
import networkx as nx
import matplotlib.pyplot as plt
import re

# Fetch latest 50 recall events from OpenFDA
resp = requests.get("https://api.fda.gov/drug/enforcement.json?limit=50").json()
records = resp.get("results", [])
df = pd.DataFrame(records)[["product_description","recalling_firm","report_date"]]
# Clean your datasets
control_char_re = re.compile(r"[\x00-\x1F\x7F]")
df = df.applymap(
    lambda v: control_char_re.sub(" ", v) if isinstance(v, str) else v
)
#df = df.to_datetime(df["report_date"], errors='coerce')
df.to_csv("recalls.csv", index=False)

# Build an RDF graph
g = Graph()
EX = Namespace("http://example.org/fda/")
for _, row in df.iterrows():
    subj = URIRef(EX[row["product_description"].replace(" ","_")])
    g.add((subj, EX.recallingFirm, Literal(row["recalling_firm"])))
    g.add((subj, EX.eventDate, Literal(row["report_date"])))
g.serialize("recalls.ttl", format="turtle")

# Convert RDF to NetworkX and plot
nxg = nx.DiGraph()
for s,p,o in g:
    nxg.add_edge(str(s), str(o), label=str(p))
plt.figure(figsize=(8,8))
pos = nx.spring_layout(nxg)
nx.draw(nxg, pos, with_labels=True, node_size=500, font_size=8)
plt.savefig("recalls_graph.png")
EOF
chmod +x 1_public_ref_datasets/fetch_and_plot.py

###############################################################################
# Demo 2: Chemical & Formulation Property Repositories
#   - Pull a sample ChEMBL compound & PubChem synonyms, build RDF and plot
###############################################################################
mkdir -p 2_chemical_property_repos
cat > 2_chemical_property_repos/fetch_and_plot.py << 'EOF'
#!/usr/bin/env python3
import requests
from rdflib import Graph, Namespace, Literal, URIRef
import networkx as nx
import matplotlib.pyplot as plt

# Retrieve ChEMBL compound CHEMBL25
# 1. Define the JSON‐specific URL
url = "https://www.ebi.ac.uk/chembl/api/data/molecule/CHEMBL25.json"

# 2. Fetch and validate
response = requests.get(url)
response.raise_for_status()               # → raises HTTPError on 4xx/5xx

# 3. Parse JSON
chembl = response.json()

# 4. Extract SMILES and properties
smiles = chembl["molecule_structures"]["canonical_smiles"]
props = chembl.get("molecule_properties", {})
properties = {
    "molecular_weight": props.get("full_molweight"),
    "alogp": props.get("alogp"),
}

# Fetch top-5 PubChem synonyms for that SMILES
syn_url = (f"https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/"
           f"smiles/{smiles}/synonyms/JSON")
syns = requests.get(syn_url).json()["InformationList"]["Information"][0]["Synonym"][:5]

# Build RDF
g = Graph()
EX = Namespace("http://example.org/chem/")
comp = URIRef(EX["CHEMBL25"])
for k,v in properties.items():
    g.add((comp, EX[k], Literal(v)))
for s in syns:
    g.add((comp, EX.hasSynonym, Literal(s)))
g.serialize("compound.ttl", format="turtle")

# Plot with NetworkX
nxg = nx.Graph()
for s,p,o in g:
    nxg.add_edge(str(s), str(o), label=str(p))
plt.figure(figsize=(6,6))
nx.draw(nxg, with_labels=True, node_size=300, font_size=6)
plt.savefig("compound_graph.png")
EOF
chmod +x 2_chemical_property_repos/fetch_and_plot.py

###############################################################################
# Demo 3: In-House & Synthetic Manufacturing Data
#   - Generate synthetic sensor & pH data, build RDF and plot
###############################################################################
mkdir -p 3_inhouse_synthetic_data
cat > 3_inhouse_synthetic_data/generate_synthetic.py << 'EOF'
#!/usr/bin/env python3
import pandas as pd, numpy as np
from rdflib import Graph, Namespace, Literal, URIRef
import networkx as nx, matplotlib.pyplot as plt

# Generate synthetic batch sensor data
times = pd.date_range("2025-01-01", periods=48, freq="H")
df = pd.DataFrame({
    "timestamp": times,
    "temperature": np.random.normal(37, 0.5, len(times)),
    "pH": np.random.normal(7, 0.1, len(times))
})
df.to_csv("sensor_data.csv", index=False)

# Build RDF graph
g = Graph()
EX = Namespace("http://example.org/sensor/")

for _, r in df.iterrows():
    # 1. Get ISO‐style timestamp (no space by default)
    ts_iso = r["timestamp"].isoformat()            # "2025-01-01T00:00:00"
    
    # 2. Swap colons for hyphens → "2025-01-01T00-00-00"
    clean_ts = ts_iso.replace(":", "-")

    # 3. Build a Turtle‐safe, human‐readable URI
    subj = URIRef(f"{EX}reading_{clean_ts}")

    # 4. Add triples
    g.add((subj, EX.timestamp, Literal(ts_iso)))
    g.add((subj, EX.temperature, Literal(r["temperature"])))
    g.add((subj, EX.pH, Literal(r["pH"])))

# Serialize out
g.serialize("sensor.ttl", format="turtle")

# Plot the graph
nxg = nx.DiGraph()
for s, p, o in g:
    nxg.add_edge(str(s), str(o), label=str(p))

plt.figure(figsize=(10, 10))
nx.draw(nxg, node_size=20, with_labels=False)
plt.savefig("sensor_graph.png")
EOF
chmod +x 3_inhouse_synthetic_data/generate_synthetic.py

###############################################################################
# Demo 4: Linking Across Datasets
#   - Merge Turtle graphs from demos 1–3, add a sample link, and plot
###############################################################################
mkdir -p 4_linking_datasets
cat > 4_linking_datasets/link_graphs.py << 'EOF'
#!/usr/bin/env python3
from rdflib import Graph, Namespace, URIRef
import networkx as nx, matplotlib.pyplot as plt

EX = Namespace("http://example.org/")

# Load the three TTL graphs
g1 = Graph().parse("../1_public_ref_datasets/recalls.ttl", format="turtle")
g2 = Graph().parse("../2_chemical_property_repos/compound.ttl", format="turtle")
g3 = Graph().parse("../3_inhouse_synthetic_data/sensor.ttl", format="turtle")

# Merge
g_all = Graph()
for g in [g1, g2, g3]:
    for t in g:
        g_all.add(t)

# Create a dummy link (example)
chem = URIRef(EX["CHEMBL25"])
for s,_,_ in g1.triples((None,None,None)):
    if "CHEMBL25" in str(s):
        g_all.add((chem, EX.relatedTo, s))

g_all.serialize("linked.ttl", format="turtle")

# Plot
nxg = nx.DiGraph()
for s,p,o in g_all:
    nxg.add_edge(str(s), str(o), label=str(p))
plt.figure(figsize=(12,12))
nx.draw(nxg, node_size=50, with_labels=False)
plt.savefig("linked_graph.png")
EOF
chmod +x 4_linking_datasets/link_graphs.py

###############################################################################
# 4. Execute all four demos
###############################################################################
echo "▶️ Running Demo 1…"
cd 1_public_ref_datasets && ./fetch_and_plot.py && cd ..

echo "▶️ Running Demo 2…"
cd 2_chemical_property_repos && ./fetch_and_plot.py && cd ..

echo "▶️ Running Demo 3…"
cd 3_inhouse_synthetic_data && ./generate_synthetic.py && cd ..

echo "▶️ Running Demo 4…"
cd 4_linking_datasets && ./link_graphs.py && cd ..

echo
echo "✅ All four demos built successfully!"
echo "  - Demo 1 outputs: 1_public_ref_datasets/{recalls.csv,recalls.ttl,recalls_graph.png}"
echo "  - Demo 2 outputs: 2_chemical_property_repos/{compound.ttl,compound_graph.png}"
echo "  - Demo 3 outputs: 3_inhouse_synthetic_data/{sensor_data.csv,sensor.ttl,sensor_graph.png}"
echo "  - Demo 4 outputs: 4_linking_datasets/{linked.ttl,linked_graph.png}"
echo
echo "You can now open the TTL files or graphs in each folder, or import them into Neo4j/GraphDB for further exploration."
