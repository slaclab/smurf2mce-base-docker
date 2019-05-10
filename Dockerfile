FROM tidair/smurf-rogue:R1.0.0

# Install the SMURF PCIe card repository
WORKDIR /usr/local/src
RUN git clone https://github.com/slaclab/smurf-pcie.git
WORKDIR smurf-pcie
RUN sed -i -e 's|git@github.com:|https://github.com/|g' .gitmodules
RUN git submodule sync && git submodule update --init --recursive
ENV PYTHONPATH /usr/local/src/smurf-pcie/software/python:${PYTHONPATH}
ENV PYTHONPATH /usr/local/src/smurf-pcie/firmware/submodules/axi-pcie-core/python:${PYTHONPATH}

# Install zeromq
RUN mkdir -p /usr/local/src/zeromq
WORKDIR /usr/local/src/zeromq
RUN wget -c https://github.com/zeromq/libzmq/releases/download/v4.3.0/zeromq-4.3.0.tar.gz -O - | tar zx --strip 1
RUN mkdir build
WORKDIR build
RUN cmake .. && make -j4 install

# Install cppzmq
RUN mkdir -p /usr/local/src/cppzmq
WORKDIR /usr/local/src/cppzmq
RUN wget -c https://github.com/zeromq/cppzmq/archive/v4.3.0.tar.gz -O - | tar zx --strip 1
RUN mkdir build
WORKDIR build
RUN cmake .. && make -j4 install

# Install smurf2mce
WORKDIR /usr/local/src
RUN git clone https://github.com/slaclab/smurf2mce.git -b R2.3.0
WORKDIR smurf2mce/mcetransmit
RUN mkdir build
WORKDIR build
RUN cmake .. && make
ENV PYTHONPATH /usr/local/src/smurf2mce/mcetransmit/lib:${PYTHONPATH}

# Add utilities
RUN mkdir -p /usr/local/src/smurf2mce_utilities
ADD scripts/* /usr/local/src/smurf2mce_utilities
ENV PATH /usr/local/src/smurf2mce_utilities:${PATH}
