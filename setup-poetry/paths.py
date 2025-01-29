"""
Print some key paths in a form that Github Actions can consume.
"""
import sys
print(f"python={sys.executable}")
print(f"poetry={sys.prefix}")
