import networkx as nx

# Read the DOT graph
G = nx.drawing.nx_pydot.read_dot("mina.dot")

# Check if the graph is acyclic
if nx.is_directed_acyclic_graph(G):
    topological_order = list(nx.topological_sort(G))
    print(topological_order)
else:
    print("Graph is not acyclic, topological sorting not possible")
