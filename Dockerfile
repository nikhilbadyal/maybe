# syntax = docker/dockerfile:1

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version and Gemfile
ARG RUBY_VERSION=3.4.5
FROM registry.docker.com/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /rails

# Install base packages
RUN apt-get update -qq \
    && apt-get install --no-install-recommends -y curl libvips postgresql-client libyaml-0-2 \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Set production environment
ARG BUILD_COMMIT_SHA
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development test" \
    BUILD_COMMIT_SHA=${BUILD_COMMIT_SHA}

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install application gems
COPY .ruby-version Gemfile Gemfile.lock ./
ARG BUNDLE_JOBS=4
RUN apt-get update -qq \
    && apt-get install --no-install-recommends -y build-essential libpq-dev git pkg-config libyaml-dev \
    && bundle install --jobs ${BUNDLE_JOBS:-4} --retry 3 \
    && rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git \
    && bundle exec bootsnap precompile --gemfile -j 0 \
    && apt-get purge -y --auto-remove build-essential libpq-dev git pkg-config libyaml-dev \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile -j 0 app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# Final stage for app image
FROM base

ARG UID=1000
ARG GID=1000
# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid ${GID} rails && \
    useradd rails --uid ${UID} --gid ${GID} --create-home --shell /bin/bash

# Copy built artifacts: gems, application
COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

# Switch to non-root user after files are in place
USER ${UID}:${GID}

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start the server by default, this can be overwritten at runtime
EXPOSE 3000
CMD ["./bin/rails", "server"]
