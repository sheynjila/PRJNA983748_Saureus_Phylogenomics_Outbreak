# Pipeline Orchestration: YAML-Driven Slurm Chain

Runs Scripts 1-9 as one unattended Slurm job chain via native
`--dependency=afterok:<jobid>` chaining.

```bash
cd pipeline_orchestration
bash check_environment.sh && bash run_pipeline_from_yaml.sh pipeline_config.yaml
```

Same no-duplication design as the sibling repos in this curriculum: every
path is read from `config/project.env`. Step 9 uses `mode: sbatch_wrap`
since it's documented to run locally with plain `bash`.

`check_environment.sh` also checks that `biopython` is importable
(`python3 -c "import Bio"`) — Script 8 needs it for real, tested midpoint
rerooting and will fail with a clear message on its own if it's missing,
but catching that before submitting the whole chain saves Steps 1-7's
real compute time.

```bash
squeue -u $(whoami)
sacct -u $(whoami) --format=JobID,JobName%20,State,ExitCode,Start,End
bash run_pipeline_from_yaml.sh pipeline_config.yaml --start-from 7
```
