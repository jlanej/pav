#
# Stage: build
#

FROM python:3.11.0-bullseye AS build_deps
LABEL pav_stage=build_deps
# RUN apt-get update && apt-get -y upgrade && \
# 	apt-get install -y build-essential git && \
# 	apt-get clean && apt-get purge && \
# 	rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV PAV_BASE=/opt/pav

WORKDIR ${PAV_BASE}

# Binary dependencies (samtools, minimap2, LRA...)
RUN mkdir -p ${PAV_BASE}/files/docker
COPY files/docker/build_deps.sh ${PAV_BASE}/files/docker
RUN files/docker/build_deps.sh
RUN rm -rf files


#
# Stage: stage pav files
#

FROM python:3.11.0-bullseye AS stage_pav
LABEL pav_stage=stage_pav

ENV PAV_BASE=/opt/pav

WORKDIR ${PAV_BASE}


# Copy PAV files into the container
COPY files/ ${PAV_BASE}/files/
COPY scripts/ ${PAV_BASE}/scripts/
COPY dep/ ${PAV_BASE}/dep/
WORKDIR ${PAV_BASE}/dep/
RUN git clone --recursive https://github.com/EichlerLab/svpop.git
WORKDIR ${PAV_BASE}/dep/svpop/
RUN git checkout bbbfc9d
WORKDIR ${PAV_BASE}
COPY pavlib/ ${PAV_BASE}/pavlib/
COPY rules/ ${PAV_BASE}/rules/
COPY Snakefile Dockerfile *.md rundist runlocal ${PAV_BASE}/


#
# Stage: pav
#

FROM python:3.11.0-bullseye AS pav
LABEL pav_stage=pav

ENV PAV_VERSION="2.1.1"
ENV PAV_BASE=/opt/pav

LABEL org.jax.becklab.author="Peter Audano<peter.audano@jax.org>"
LABEL org.jax.becklab.name="PAV"
LABEL org.jax.becklab.version="${PAV_VERSION}"

WORKDIR ${PAV_BASE}

# Base python and snakemake
RUN pip3 install \
    biopython \
    intervaltree \
    matplotlib \
    matplotlib-venn \
    numpy \
    pandas \
    pysam \
    scipy \
    snakemake \
    drmaa

# Copy from build
COPY --from=build_deps ${PAV_BASE} ${PAV_BASE}
COPY --from=stage_pav ${PAV_BASE} ${PAV_BASE}

RUN files/docker/build_home.sh

# Runtime environment
ENV PATH="${PATH}:${PAV_BASE}/bin"

ENTRYPOINT ["/opt/pav/files/docker/run"]
