FROM mynewt/newt

RUN apt-get update && \
        apt-get install -y gdb-multiarch curl docker.io make sudo telnet openocd sudo llvm-dev libclang-dev clang

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID
# Create the user
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME -s /bin/bash \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME
USER $USERNAME

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- --default-toolchain nightly -y
ENV PATH=/home/$USERNAME/.cargo/bin:$PATH

# https://rust-lang.github.io/rustup-components-history/index.html
RUN rustup toolchain add nightly-2020-04-23 && \
    rustup component add rls rust-analysis rust-src --toolchain=nightly-2020-04-23 && \
    rustup default nightly-2020-04-23
# RUN rustup component add rls rust-analysis rust-src

RUN rustup target add thumbv7m-none-eabi --toolchain nightly-2020-04-23
