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
