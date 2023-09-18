# DO NOT USE THIS REPO - MIGRATED TO GITLAB

# dataworks-aws-ucfs-stub

## Stub for testing tarball ingestor

The repository contains deployment files for components that enable the testing of the tarball ingestor in lower environments.

The tarball ingestor requires a UCFS server where files will be dropped to be ingested. As we are not connected in DataWorks to UCFS lower environments, we need a stub to connect to.

This then enables manual runs of the tarball ingestor in those environments and gives us somewhere to drop files in to.

### Initial check-out

When checking out this repo, ensure you run `make bootstrap`.
