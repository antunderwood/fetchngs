FROM gitpod/workspace-full
RUN  curl -s https://get.nextflow.io | bash && ./nextflow && sudo mv nextflow /usr/local/bin/
