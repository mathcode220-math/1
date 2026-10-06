# deprecated: hyperbolic SVD+Möbius

Status: **refuted** (test 1)

Evidence: `results/hyperbolic_verdict.json`

Pocket-LLM `HyperbolicCoralCompiler.project_euclidean_to_poincare` runs SVD then a Möbius-like scale and **changes matrix shape** (N×N → N×k). The result is not a linear operator `W` for `x @ W` on OCCP systolic RTL.

Plain SVD (method B) reconstructs `W` and can be measured. Möbius (method C) cannot meet a GEMV error target at any k because it does not reconstruct `W`.

INT8 (method D) keeps shape and beats SVD on the Linear task for the tested sizes.

Do not merge hyperbolic projection into the unified hardware path.
