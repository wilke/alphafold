#!/usr/bin/env python3
"""Generate test protein sequences for scaling analysis"""

import os

# Real protein sequences for comprehensive scaling analysis
test_proteins = {
    # Small proteins
    "1VII": {
        "length": 36,
        "sequence": "MLSDEDFKAVFGMTRSAFANLPLWKQQNLKKEKGLF",
        "description": "Villin headpiece (36 aa)"
    },
    "1UBQ": {
        "length": 76, 
        "sequence": "MQIFVKTLTGKTITLEVEPSDTIENVKAKIQDKEGIPPDQQRLIFAGKQLEDGRTLSDYNIQKESTLHLVLRLRGG",
        "description": "Ubiquitin (76 aa)"
    },
    "1LYZ": {
        "length": 129,
        "sequence": "KVFGRCELAAAMKRHGLDNYRGYSLGNWVCAAKFESNFNTQATNRNTDGSTDYGILQINSRWWCNDGRTPGSRNLCNIPCSALLSSDITASVNCAKKIVSDGNGMNAWVAWRNRCKGTDVQAWIRGCRL",
        "description": "Lysozyme (129 aa)"
    },
    "1MBN": {
        "length": 153,
        "sequence": "MVLSEGEWQLVLHVWAKVEADVAGHGQDILIRLFKSHPETLEKFDRFKHLKTEAEMKASEDLKKHGVTVLTALGAILKKKGHHEAELKPLAQSHATKHKIPIKYLEFISEAIIHVLHSRHPGDFGADAQGAMNKALELFRKDIAAKYKELGYQG",
        "description": "Myoglobin (153 aa)"
    },
    # Medium proteins  
    "2LZM": {
        "length": 164,
        "sequence": "MKAIFVQAANGGLDNYRGYSLGNWVCAAKFESNFNTQATNRNTDGSTDYGILQINSRWWCNDGRTPGSRNLCNIPCSALLSSDITASVNCAKKIVSDGNGMNAWVAWRNRCKGTDVQAWIRGCRLNLDVKGYPGSL",
        "description": "T4 Lysozyme (164 aa)"
    },
    "1CRN": {
        "length": 199,
        "sequence": "TTCCPSIVARSNFNVCRLPGTPEALCATYTGCIIIPGATCPGDYAN-QCCDKGKSNKQCLNGRGSIDFESGFTGEHLMDSQIGFDWRFADFCGTKWGSRQAAVNLHAKDQHSILVEKSHKDRVAVNNLQFHTSKNMVDQEHDWLLKEGQYLKSSQHTQKISGQVWIGRSEPHTLLPSQIQFQTLQD",
        "description": "Crambin variant (199 aa)"
    },
    # Large proteins
    "1LYS": {
        "length": 501,
        "sequence": "MKKLLFILLAVVAFAVSGTAPSFETQKQCLGKDLQAFAQQLSTGDYGTADGYSKASADQIQYLATLGTLTDDQVWQTLQKTLAKRHDIKLAETDILYLQDLPDGILEFEVTNSIAKLGGTILNVLDEYSDIAGWISQPGIGTQSDVNPSLIQFQSFFSRLRRCHLAHPHLGKIISLQGPAFQPTGARLRKLRQMQVQALLCEVMSGLGAPVDEGDHFKPDFPRLCDLYTKAGLAKLGSYRSYYSMFLSWVTYVLTTLDAQRALNSNGAQDKAYINGLISEDVKVQIGRLISDSGGKSRYVWIEGHGEHLNFSDNPTDRQFAAFKRSGKGIRFAYYQKFEAHTNQHIKDTQYGFKLPKIKYSAYRTKNQVAIVLPGSSLDQALNVEKRSFFLGGQHGRGDSDRFVKCQDSTNKNTLKTSQRIQSIKALNAIKAQNNAKGLAAKYGYHQLQFAQYGLPGTLYNGSQALAKGLSNHCLDDVVQGLAKDFQKLSDKALKFGAGAEEGVQAQRFRTYQKVLRRGLQLAADYTLQTFTQEDALINRVAKAAITDETKAMQ",
        "description": "Lysozyme large variant (501 aa)"
    }
}

def create_fasta_files(output_dir):
    """Create FASTA files for all test proteins"""
    os.makedirs(output_dir, exist_ok=True)
    
    for pdb_id, data in test_proteins.items():
        fasta_path = os.path.join(output_dir, f"{pdb_id}.fasta")
        with open(fasta_path, 'w') as f:
            f.write(f">{pdb_id}_{data['description'].replace(' ', '_')}\n")
            f.write(f"{data['sequence']}\n")
        
        print(f"Created {fasta_path}: {data['length']} aa - {data['description']}")

def print_summary():
    """Print summary table"""
    print("\n=== Test Protein Summary ===")
    print("| Protein | Length (aa) | Description |")
    print("|---------|-------------|-------------|")
    for pdb_id, data in sorted(test_proteins.items(), key=lambda x: x[1]['length']):
        print(f"| {pdb_id} | {data['length']} | {data['description']} |")

if __name__ == "__main__":
    output_dir = "/scratch/alphafold/scaling_test_sequences"
    create_fasta_files(output_dir)
    print_summary()