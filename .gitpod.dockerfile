FROM gitpod/workspace-full
USER gitpod
RUN curl -s https://get.nextflow.io | JAVA_HOME=/home/gitpod/.sdkman/candidates/java/current bash && \
    sudo mv nextflow /usr/local/bin
